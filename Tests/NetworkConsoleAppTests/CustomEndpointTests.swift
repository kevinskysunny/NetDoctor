import XCTest
@testable import NetworkConsoleApp
@testable import NetworkCore

@MainActor
final class CustomEndpointTests: XCTestCase {
    func testAddCustomHttpsEndpoint() {
        let model = AppModel()
        let initialCount = model.settings.endpoints.count
        
        let success = model.addEndpoint(
            name: "Cloudflare DNS",
            host: "https://1.1.1.1/dns-query",
            port: 443,
            path: "/dns-query",
            kind: .https
        )
        
        XCTAssertTrue(success)
        XCTAssertEqual(model.settings.endpoints.count, initialCount + 1)
        
        guard let added = model.settings.endpoints.last else {
            XCTFail("Endpoint should have been added")
            return
        }
        
        XCTAssertEqual(added.displayName, "Cloudflare DNS")
        XCTAssertEqual(added.host, "1.1.1.1") // Host stripped scheme correctly
        XCTAssertEqual(added.port, 443)
        XCTAssertEqual(added.path, "/dns-query")
        XCTAssertEqual(added.kind, .https)
    }

    func testAddCustomTcpEndpoint() {
        let model = AppModel()
        let initialCount = model.settings.endpoints.count
        
        let success = model.addEndpoint(
            name: "Internal Gateway",
            host: "192.168.1.1",
            port: 8080,
            path: "/",
            kind: .tcp
        )
        
        XCTAssertTrue(success)
        XCTAssertEqual(model.settings.endpoints.count, initialCount + 1)
        
        guard let added = model.settings.endpoints.last else {
            XCTFail("Endpoint should have been added")
            return
        }
        
        XCTAssertEqual(added.displayName, "Internal Gateway")
        XCTAssertEqual(added.host, "192.168.1.1")
        XCTAssertEqual(added.port, 8080)
        XCTAssertEqual(added.kind, .tcp)
    }

    func testDeleteEndpoint() {
        let model = AppModel()
        model.resetEndpoints()
        XCTAssertEqual(model.settings.endpoints.count, 3)
        
        let firstId = model.settings.endpoints[0].id
        model.deleteEndpoint(id: firstId)
        
        XCTAssertEqual(model.settings.endpoints.count, 2)
        XCTAssertFalse(model.settings.endpoints.contains(where: { $0.id == firstId }))
    }

    func testCannotDeleteLastRemainingEndpoint() {
        let model = AppModel()
        model.resetEndpoints()
        
        // Delete down to 1
        model.deleteEndpoint(id: model.settings.endpoints[0].id)
        model.deleteEndpoint(id: model.settings.endpoints[0].id)
        XCTAssertEqual(model.settings.endpoints.count, 1)
        
        // Attempt to delete last remaining
        let lastId = model.settings.endpoints[0].id
        model.deleteEndpoint(id: lastId)
        
        // Must still have 1 endpoint
        XCTAssertEqual(model.settings.endpoints.count, 1)
        XCTAssertEqual(model.settings.endpoints[0].id, lastId)
    }

    func testResetEndpointsRestoresDefaults() {
        let model = AppModel()
        model.resetEndpoints()
        
        // Add custom
        model.addEndpoint(name: "Test", host: "example.com")
        XCTAssertEqual(model.settings.endpoints.count, 4)
        
        // Reset
        model.resetEndpoints()
        XCTAssertEqual(model.settings.endpoints.count, ReachabilityEndpoint.defaultPublicEndpoints.count)
        XCTAssertEqual(model.settings.endpoints.map(\.displayName), ReachabilityEndpoint.defaultPublicEndpoints.map(\.displayName))
    }
}
