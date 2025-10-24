import UIKit
import Flutter
import CoreLocation
import CoreMotion

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
      requestMotionPermission()
      
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
    
    private func requestMotionPermission() {
        let motionActivityManager = CMMotionActivityManager()

        // 모션 액세스 가능 여부 확인
        guard CMMotionActivityManager.isActivityAvailable() else {
            print("이 기기에서는 모션 데이터를 사용할 수 없습니다.")
            return
        }

        // 모션 데이터 요청
        motionActivityManager.queryActivityStarting(
            from: Date().addingTimeInterval(-60), // 1분 전부터
            to: Date(),
            to: OperationQueue.main
        ) { activities, error in
            if let error = error {
                print("모션 데이터 접근 오류:", error.localizedDescription)
            } else if let activities = activities, !activities.isEmpty {
                for activity in activities {
                    if activity.walking {
                        print("사용자가 걷는 중입니다.")
                    } else if activity.running {
                        print("사용자가 뛰는 중입니다.")
                    } else if activity.stationary {
                        print("사용자가 정지 상태입니다.")
                    } else {
                        print("알 수 없는 상태입니다.")
                    }
                }
            } else {
                print("모션 데이터가 없습니다.")
            }
        }
    }

}
