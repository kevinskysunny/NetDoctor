import Foundation
import Network

public final class URLSessionReachabilityProber: ReachabilityProbing {
    private let session: URLSession

    public init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
            configuration.urlCache = nil
            configuration.waitsForConnectivity = false
            configuration.timeoutIntervalForRequest = 3
            configuration.timeoutIntervalForResource = 6
            self.session = URLSession(configuration: configuration)
        }
    }

    public func probe(
        endpoints: [ReachabilityEndpoint],
        attemptsPerEndpoint: Int,
        timeout: TimeInterval
    ) async -> [ReachabilityProbe] {
        let attempts = max(1, attemptsPerEndpoint)
        let requestTimeout = max(0.5, timeout)

        let results: [ReachabilityProbe] = await withTaskGroup(of: ReachabilityProbe.self, returning: [ReachabilityProbe].self) { group in
            for endpoint in endpoints {
                for attempt in 0..<attempts {
                    group.addTask {
                        await self.probe(endpoint: endpoint, attempt: attempt, timeout: requestTimeout)
                    }
                }
            }

            var collected: [ReachabilityProbe] = []
            for await result in group {
                collected.append(result)
            }
            return collected
        }

        return results.sorted {
            if $0.endpointName != $1.endpointName {
                return $0.endpointName < $1.endpointName
            }
            return $0.startedAt < $1.startedAt
        }
    }

    private func probe(endpoint: ReachabilityEndpoint, attempt: Int, timeout: TimeInterval) async -> ReachabilityProbe {
        let start = Date()
        switch endpoint.kind {
        case .https:
            return await probeHTTPS(endpoint: endpoint, attempt: attempt, start: start, timeout: timeout)
        case .tcp:
            return await probeTCP(endpoint: endpoint, attempt: attempt, start: start, timeout: timeout)
        }
    }

    private func probeHTTPS(
        endpoint: ReachabilityEndpoint,
        attempt: Int,
        start: Date,
        timeout: TimeInterval
    ) async -> ReachabilityProbe {
        guard let url = endpoint.url else {
            return ReachabilityProbe(
                endpointID: endpoint.id,
                endpointName: endpoint.displayName,
                target: targetString(endpoint),
                kind: endpoint.kind,
                startedAt: start,
                durationMilliseconds: nil,
                status: .failed,
                httpStatusCode: nil,
                errorDescription: "无效 URL"
            )
        }

        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: timeout)
        request.httpMethod = "GET"
        request.setValue("NetworkConsoleLite/1.0", forHTTPHeaderField: "User-Agent")

        do {
            let (_, response) = try await session.data(for: request)
            let elapsed = Self.elapsedMilliseconds(from: start)
            let status = (response as? HTTPURLResponse)?.statusCode
            let success = status.map { (200..<400).contains($0) } ?? false
            return ReachabilityProbe(
                endpointID: endpoint.id,
                endpointName: endpoint.displayName,
                target: targetString(endpoint),
                kind: endpoint.kind,
                startedAt: start,
                durationMilliseconds: elapsed,
                status: success ? .success : .failed,
                httpStatusCode: status,
                errorDescription: success ? nil : "HTTP \(status.map(String.init) ?? "unknown")"
            )
        } catch is CancellationError {
            return ReachabilityProbe(
                endpointID: endpoint.id,
                endpointName: endpoint.displayName,
                target: targetString(endpoint),
                kind: endpoint.kind,
                startedAt: start,
                durationMilliseconds: Self.elapsedMilliseconds(from: start),
                status: .cancelled,
                httpStatusCode: nil,
                errorDescription: nil
            )
        } catch let urlError as URLError where urlError.code == .timedOut {
            return ReachabilityProbe(
                endpointID: endpoint.id,
                endpointName: endpoint.displayName,
                target: targetString(endpoint),
                kind: endpoint.kind,
                startedAt: start,
                durationMilliseconds: Self.elapsedMilliseconds(from: start),
                status: .timeout,
                httpStatusCode: nil,
                errorDescription: urlError.localizedDescription
            )
        } catch {
            return ReachabilityProbe(
                endpointID: endpoint.id,
                endpointName: endpoint.displayName,
                target: targetString(endpoint),
                kind: endpoint.kind,
                startedAt: start,
                durationMilliseconds: Self.elapsedMilliseconds(from: start),
                status: .failed,
                httpStatusCode: nil,
                errorDescription: error.localizedDescription
            )
        }
    }

    private func probeTCP(
        endpoint: ReachabilityEndpoint,
        attempt: Int,
        start: Date,
        timeout: TimeInterval
    ) async -> ReachabilityProbe {
        guard let port = NWEndpoint.Port(rawValue: endpoint.port) else {
            return ReachabilityProbe(
                endpointID: endpoint.id,
                endpointName: endpoint.displayName,
                target: targetString(endpoint),
                kind: endpoint.kind,
                startedAt: start,
                durationMilliseconds: nil,
                status: .failed,
                httpStatusCode: nil,
                errorDescription: "无效端口"
            )
        }

        let host = NWEndpoint.Host(endpoint.host)
        let connection = NWConnection(host: host, port: port, using: .tcp)
        connection.stateUpdateHandler = { _ in }
        connection.start(queue: DispatchQueue.global(qos: .userInitiated))
        defer { connection.cancel() }

        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    try await self.waitUntilReady(connection)
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                    throw CancellationError()
                }
                try await group.next()
                group.cancelAll()
            }
            return ReachabilityProbe(
                endpointID: endpoint.id,
                endpointName: endpoint.displayName,
                target: targetString(endpoint),
                kind: endpoint.kind,
                startedAt: start,
                durationMilliseconds: Self.elapsedMilliseconds(from: start),
                status: .success,
                httpStatusCode: nil,
                errorDescription: nil
            )
        } catch {
            let timedOut = Self.elapsedMilliseconds(from: start) >= timeout * 1_000
            return ReachabilityProbe(
                endpointID: endpoint.id,
                endpointName: endpoint.displayName,
                target: targetString(endpoint),
                kind: endpoint.kind,
                startedAt: start,
                durationMilliseconds: Self.elapsedMilliseconds(from: start),
                status: timedOut ? .timeout : .failed,
                httpStatusCode: nil,
                errorDescription: timedOut ? nil : error.localizedDescription
            )
        }
    }

    private func waitUntilReady(_ connection: NWConnection) async throws {
        let box = ConnectionReadyBox()
        try await withCheckedThrowingContinuation { continuation in
            box.setContinuation(continuation)
            connection.stateUpdateHandler = { state in
                box.handle(state)
            }
        }
    }

    private func targetString(_ endpoint: ReachabilityEndpoint) -> String {
        "\(endpoint.host):\(endpoint.port)"
    }

    private static func elapsedMilliseconds(from start: Date) -> Double {
        Date().timeIntervalSince(start) * 1_000
    }
}

private final class ConnectionReadyBox: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Error>?
    private var resumed = false

    func setContinuation(_ continuation: CheckedContinuation<Void, Error>) {
        lock.lock()
        self.continuation = continuation
        lock.unlock()
    }

    func handle(_ state: NWConnection.State) {
        switch state {
        case .ready:
            resume(throwing: nil)
        case .failed, .cancelled:
            resume(throwing: URLError(.cannotConnectToHost))
        case .setup, .preparing, .waiting:
            break
        @unknown default:
            break
        }
    }

    private func resume(throwing error: Error?) {
        lock.lock()
        defer { lock.unlock() }
        guard !resumed, let continuation else { return }
        resumed = true
        self.continuation = nil
        if let error {
            continuation.resume(throwing: error)
        } else {
            continuation.resume()
        }
    }
}
