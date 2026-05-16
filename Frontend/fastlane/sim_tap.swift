import CoreGraphics
import Foundation
import AppKit

// Usage: sim_tap <device_x> <device_y>
// Maps device points (393x852) to Simulator window screen coords

guard CommandLine.arguments.count >= 3,
      let deviceX = Double(CommandLine.arguments[1]),
      let deviceY = Double(CommandLine.arguments[2]) else {
    print("Usage: sim_tap <device_x> <device_y>")
    exit(1)
}

// Get Simulator window bounds via AppleScript
let script = """
tell application "System Events"
    tell process "Simulator"
        set w to window 1
        set p to position of w
        set s to size of w
        return (item 1 of p as text) & "," & (item 2 of p as text) & "," & (item 1 of s as text) & "," & (item 2 of s as text)
    end tell
end tell
"""

var error: NSDictionary?
let appleScript = NSAppleScript(source: script)
let result = appleScript?.executeAndReturnError(&error)
guard let output = result?.stringValue else {
    print("Cannot get Simulator window bounds")
    exit(1)
}

let parts = output.split(separator: ",").compactMap { Double($0) }
guard parts.count == 4 else { exit(1) }

let winX = parts[0], winY = parts[1]
let winW = parts[2], winH = parts[3]

// Calibrated values for iPhone 16e Simulator with device frame:
// Known: email field (device y=300) → screen y=588, password (device y=380) → screen y=650
// scale = (650-588)/(380-300) = 62/80 = 0.775
// yOffset = 588 - winY - 300*scale = 588 - 65 - 232.5 = 290.5
// xOffset calibrated to center: (winW - 393*scale) / 2 = (452 - 304.6) / 2 = 73.7
let scale: Double = 0.775
let yOffset: Double = 290.5
let xOffset = (winW - 393.0 * scale) / 2.0

let screenX = winX + xOffset + deviceX * scale
let screenY = winY + yOffset + deviceY * scale

// Activate Simulator
let apps = NSWorkspace.shared.runningApplications
if let simApp = apps.first(where: { $0.bundleIdentifier == "com.apple.iphonesimulator" }) {
    simApp.activate(options: [])
    Thread.sleep(forTimeInterval: 0.5)
}

// Send touch
let point = CGPoint(x: screenX, y: screenY)
let down = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left)
down?.post(tap: .cghidEventTap)
Thread.sleep(forTimeInterval: 0.12)
let up = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)
up?.post(tap: .cghidEventTap)

print("Tapped device(\(deviceX),\(deviceY)) -> screen(\(Int(screenX)),\(Int(screenY)))")
