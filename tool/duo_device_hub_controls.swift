// Background-only controls for a Duo window that is already open in Device Hub.
import AppKit
import ApplicationServices
import Foundation

let arguments = Array(CommandLine.arguments.dropFirst())
guard [2, 3].contains(arguments.count), let pid = Int32(arguments[0]),
      arguments.count == 2 || arguments[2] == "--recover-window",
      NSRunningApplication(processIdentifier: pid)?.bundleIdentifier == "com.apple.dt.Devices",
      ["list", "Closed", "Book", "Open", "Rotate Right"].contains(arguments[1]) else {
    fputs("Usage: swift duo_device_hub_controls.swift <Device-Hub-pid> <list|Closed|Book|Open|Rotate Right> [--recover-window]\n", stderr)
    exit(1)
}
let target = arguments[1]
let recover = arguments.count == 3 && arguments[2] == "--recover-window"
let previousApp = NSWorkspace.shared.frontmostApplication
let frontBefore = NSWorkspace.shared.frontmostApplication?.processIdentifier ?? -1
// Device Hub beta can omit its AX windows while inactive. This explicit recovery
// is opt-in; ordinary posture controls never activate the app.
if recover {
    NSRunningApplication(processIdentifier: pid)?.activate(options: [.activateAllWindows])
    RunLoop.current.run(until: Date().addingTimeInterval(1.0))
}
func restoreFocus() {
    if recover {
        previousApp?.activate(options: [])
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
    }
}
let app = AXUIElementCreateApplication(pid)
func value(_ node: AXUIElement, _ key: String) -> CFTypeRef? {
    var result: CFTypeRef?
    AXUIElementCopyAttributeValue(node, key as CFString, &result)
    return result
}
func find(_ node: AXUIElement, action: String = target, depth: Int = 0) -> AXUIElement? {
    guard depth <= 18 else { return nil }
    let role = value(node, kAXRoleAttribute) as? String ?? ""
    let description = value(node, kAXDescriptionAttribute) as? String ?? ""
    if role == "AXButton" && description == action { return node }
    if action == "list" && role == "AXButton" { print(description) }
    for child in value(node, kAXChildrenAttribute) as? [AXUIElement] ?? [] {
        if let result = find(child, action: action, depth: depth + 1) { return result }
    }
    return nil
}
let windows = value(app, kAXWindowsAttribute) as? [AXUIElement] ?? []
let duoWindows = windows.filter {
    find($0, action: "Book") != nil && find($0, action: "Closed") != nil && find($0, action: "Open") != nil
}
guard duoWindows.count == 1 else {
    restoreFocus()
    fputs("Open exactly one iPhone Duo window in Device Hub (found \(duoWindows.count) Duo windows among \(windows.count) accessible windows).\n", stderr)
    exit(2)
}
let node = find(duoWindows[0])
if target == "list" { restoreFocus(); exit(0) }
guard let node else { restoreFocus(); fputs("Requested Duo control is unavailable.\n", stderr); exit(3) }
let result = AXUIElementPerformAction(node, kAXPressAction as CFString)
restoreFocus()
let record: [String: Any] = [
    "action": target, "axResult": result.rawValue,
    "frontBefore": frontBefore,
    "frontAfter": NSWorkspace.shared.frontmostApplication?.processIdentifier ?? -1,
]
print(String(data: try JSONSerialization.data(withJSONObject: record), encoding: .utf8)!)
guard result == .success else { exit(4) }
guard record["frontAfter"] as? Int32 == frontBefore else { exit(5) }
