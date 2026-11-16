import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    let controller = window?.rootViewController as! FlutterViewController
    let shareChannel = FlutterMethodChannel(
      name: "com.hassanobeid.atheer_radio/share",
      binaryMessenger: controller.binaryMessenger
    )

    shareChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
      guard let args = call.arguments as? [String: Any] else {
        result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
        return
      }

      var itemsToShare: [Any] = []

      if call.method == "shareText" {
        if let text = args["text"] as? String {
          itemsToShare.append(text)
        }
      } else if call.method == "shareFile" {
        if let path = args["path"] as? String {
          let fileUrl = URL(fileURLWithPath: path)
          itemsToShare.append(fileUrl)
        }
      } else {
        result(FlutterMethodNotImplemented)
        return
      }

      if !itemsToShare.isEmpty {
        let activityVC = UIActivityViewController(activityItems: itemsToShare, applicationActivities: nil)
        if let popoverController = activityVC.popoverPresentationController {
          popoverController.sourceView = controller.view
          popoverController.sourceRect = CGRect(x: controller.view.bounds.midX, y: controller.view.bounds.midY, width: 0, height: 0)
          popoverController.permittedArrowDirections = []
        }
        controller.present(activityVC, animated: true) {
          result(true)
        }
      } else {
        result(false)
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
