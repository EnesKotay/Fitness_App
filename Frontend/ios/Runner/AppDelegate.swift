import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Uygulama açıldığında badge sayısını sıfırla (kırmızı bildirim badge'ini kaldır)
    print("🔔 PusulaFit: Clearing badge on launch, current badge: \(UIApplication.shared.applicationIconBadgeNumber)")
    UIApplication.shared.applicationIconBadgeNumber = 0

    // Tüm delivered notifications'ı temizle
    UNUserNotificationCenter.current().removeAllDeliveredNotifications()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    // Uygulama ön plana geldiğinde de badge'i sıfırla
    print("🔔 PusulaFit: Clearing badge on become active, current badge: \(UIApplication.shared.applicationIconBadgeNumber)")
    UIApplication.shared.applicationIconBadgeNumber = 0

    // Delivered notifications'ı temizle
    UNUserNotificationCenter.current().removeAllDeliveredNotifications()

    super.applicationDidBecomeActive(application)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
