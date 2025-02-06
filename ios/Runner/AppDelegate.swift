import UIKit
import Flutter
import GoogleMaps  // Add this for Google Maps
import FirebaseCore // Add this for Firebase

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    
    // Initialize Google Maps with your API Key
    GMSServices.provideAPIKey("AIzaSyBsVw09Zl_Xby65X7ed8Xs2ov8aAhaWiFk")
    
    // Initialize Firebase
    FirebaseApp.configure()
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
