import CoreGraphics
import Foundation

let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
let info = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] ?? []

for window in info {
    guard let owner = window[kCGWindowOwnerName as String] as? String,
          let name = window[kCGWindowName as String] as? String,
          let number = window[kCGWindowNumber as String] as? Int,
          let bounds = window[kCGWindowBounds as String] as? [String: CGFloat] else {
        continue
    }
    let x = bounds["X"] ?? 0
    let y = bounds["Y"] ?? 0
    let width = bounds["Width"] ?? 0
    let height = bounds["Height"] ?? 0
    print("\(number)\t\(owner)\t\(name)\t\(x)\t\(y)\t\(width)\t\(height)")
}
