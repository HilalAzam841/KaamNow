import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    provideGoogleMapsKey()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// Hands the Google Maps key from Info.plist (GMSApiKey, set at build time) to the Maps SDK.
  /// Looked up by name so the app also builds and runs without Google Maps set up.
  private func provideGoogleMapsKey() {
    guard let key = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String,
          !key.isEmpty, !key.hasPrefix("$("),
          let services: AnyClass = NSClassFromString("GMSServices") else { return }
    _ = (services as AnyObject).perform(NSSelectorFromString("provideAPIKey:"), with: key)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
