import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {

  var _methodChannel: FlutterMethodChannel?

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  // ===== URL SCHEME LISTENER =====
  // Handles oko://activate?token=JWT_LICENSE deep links from Stripe callback
  override func applicationDidFinishLaunching(_ notification: Notification) {
    let controller = NSApplication.shared.windows.first?.contentViewController as? FlutterViewController
    if let controller = controller {
      _methodChannel = FlutterMethodChannel(
        name: "com.ono.app/deeplink",
        binaryMessenger: controller.engine.binaryMessenger
      )
    }

    // Register for Apple Events (URL scheme handling on macOS)
    NSAppleEventManager.shared().setEventHandler(
      self,
      andSelector: #selector(handleURLEvent(_:withReplyEvent:)),
      forEventClass: AEEventClass(kInternetEventClass),
      andEventID: AEEventID(kAEGetURL)
    )
  }

  @objc private func handleURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
    guard let urlStr = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
          let url = URL(string: urlStr) else {
      return
    }

    // Only handle oko:// scheme
    guard url.scheme == "oko" else { return }

    let host = url.host ?? ""
    let path = url.path
    var params: [String: String] = [:]

    // Parse query parameters
    if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
       let queryItems = components.queryItems {
      for item in queryItems {
        params[item.name] = item.value ?? ""
      }
    }

    // Route: oko://activate?token=ENCRYPTED_JWT_LICENSE
    if host == "activate" || path == "/activate" {
      if let token = params["token"] {
        // Bring app to front
        NSApplication.shared.activate(ignoringOtherApps: true)

        // Forward token to Flutter via MethodChannel
        _methodChannel?.invokeMethod("onDeepLinkToken", arguments: [
          "action": "activate",
          "token": token
        ])
      }
    }
  }
}
