import UIKit
import Flutter
import GoogleMaps // 1. Add this import

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // 2. Add your API Key here BEFORE the Registrar
    GMSServices.provideAPIKey("AIzaSyDvPH4yPvUWO0Av6KDOBoblYPpxZQD7KNA")
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}