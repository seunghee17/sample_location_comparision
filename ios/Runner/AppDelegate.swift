import UIKit
import Flutter
import CoreLocation

enum ChannelName {
    static let app = "app/Location_comparision"
}

@main
@objc class AppDelegate: FlutterAppDelegate, CLLocationManagerDelegate {
    var appMethodChannel: FlutterMethodChannel?
    private var flutterViewController: FlutterViewController?
    
    var locationManager: CLLocationManager = CLLocationManager()
    var locationResult: FlutterResult?
    
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
      guard let controller = window?.rootViewController as? FlutterViewController else {
          fatalError("rootViewController is not type FlutterViewController")
      }
      
      self.flutterViewController = controller
      appMethodChannel = FlutterMethodChannel(name: ChannelName.app, binaryMessenger: controller.binaryMessenger)
      locationManager.delegate = self
      
      appMethodChannel?.setMethodCallHandler {
          (call: FlutterMethodCall, result: @escaping FlutterResult) in
          if call.method == "measureLocation" {
              self.locationResult = result
              self.locationManager.startUpdatingLocation()
          }
      }
      
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else {return}
        let lat = location.coordinate.latitude
        let lng = location.coordinate.longitude
        locationResult?("위도 \(lat) 경도 \(lng)")
    }

}
