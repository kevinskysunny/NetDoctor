import AppKit
import Vision

guard CommandLine.arguments.count > 1,
      let image = NSImage(contentsOfFile: CommandLine.arguments[1]),
      let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    exit(1)
}

let request = VNRecognizeTextRequest()
request.recognitionLevel = .accurate
request.usesLanguageCorrection = false
request.recognitionLanguages = ["en-US", "zh-Hans"]

let handler = VNImageRequestHandler(cgImage: cgImage)
try handler.perform([request])

for observation in request.results ?? [] {
    guard let candidate = observation.topCandidates(1).first else { continue }
    let box = observation.boundingBox
    print("\(candidate.string)\t\(box.origin.x)\t\(box.origin.y)\t\(box.size.width)\t\(box.size.height)")
}
