import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller = window?.rootViewController as? FlutterViewController
    if let messenger = controller?.binaryMessenger {
      let deviceChannel = FlutterMethodChannel(name: "com.laju/device", binaryMessenger: messenger)
      deviceChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
        if call.method == "openUrl" {
          guard let args = call.arguments as? [String: Any],
                let urlString = args["url"] as? String,
                let url = URL(string: urlString) else {
            result(false)
            return
          }
          if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:]) { success in
              result(success)
            }
          } else {
            result(false)
          }
        } else if call.method == "getAppVersion" {
          let vName = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
          let vCodeStr = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
          let vCode = Int(vCodeStr) ?? 1
          result([
            "versionName": vName,
            "versionCode": vCode
          ])
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
