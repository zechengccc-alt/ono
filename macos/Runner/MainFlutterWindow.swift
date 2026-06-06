import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  var backendProcess: Process?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // Auto-start Ono backend
    startBackend()

    super.awakeFromNib()
  }

  func startBackend() {
    let process = Process()
    let bundlePath = Bundle.main.bundlePath
    let backendPath = bundlePath + "/Contents/MacOS/ono_backend"

    // Check if backend executable exists
    if FileManager.default.fileExists(atPath: backendPath) {
      process.executableURL = URL(fileURLWithPath: backendPath)
      process.arguments = []
      try? process.run()
      backendProcess = process
      print("🚀 Ono backend started from: \(backendPath)")
    } else {
      print("⚠️ Backend not found at: \(backendPath)")
    }
  }

  override func close() {
    backendProcess?.terminate()
    super.close()
  }
}
