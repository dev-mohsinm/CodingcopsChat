import Expo
import React
import ReactAppDependencyProvider
import Firebase
import Bugsnag
import MMKV
import WatchConnectivity
import UserNotifications

@UIApplicationMain
public class AppDelegate: ExpoAppDelegate, UNUserNotificationCenterDelegate {
  var window: UIWindow?

  var reactNativeDelegate: ReactNativeDelegate?
  var reactNativeFactory: RCTReactNativeFactory?
  var watchConnection: WatchConnection?

  public override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    FirebaseApp.configure()
    Bugsnag.start()
    
    // Initialize MMKV with app group (with logging)
    if let appGroup = Bundle.main.object(forInfoDictionaryKey: "AppGroup") as? String {
      if let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) {
        let groupDir = groupURL.path
        print("🗂️ MMKV App Group resolved:", appGroup)
        print("📁 MMKV Group Directory:", groupDir)
        MMKV.initialize(rootDir: nil, groupDir: groupDir, logLevel: .debug)
        print("✅ MMKV.initialize() called successfully")
      } else {
        print("⚠️ MMKV: Failed to resolve container URL for App Group:", appGroup)
      }
    } else {
      print("⚠️ MMKV: 'AppGroup' key missing in Info.plist")
    }
    
    // Initialize notifications
    RNNotifications.startMonitorNotifications()
    // Set UNUserNotificationCenter delegate for foreground presentation
    let center = UNUserNotificationCenter.current()
    center.delegate = self
    center.getNotificationSettings { settings in
      print("🔧 UNUserNotificationCenter settings:", settings)
    }
    ReplyNotification.configure()
      
    let delegate = ReactNativeDelegate()
    let factory = RCTReactNativeFactory(delegate: delegate)
    delegate.dependencyProvider = RCTAppDependencyProvider()

    reactNativeDelegate = delegate
    reactNativeFactory = factory
    bindReactNativeFactory(factory)

#if os(iOS) || os(tvOS)
    window = UIWindow(frame: UIScreen.main.bounds)
    factory.startReactNative(
      withModuleName: "RocketChatRN",
      in: window,
      launchOptions: launchOptions)
#endif

    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    print("🚀 Application finished launching. Registered for notifications?", UIApplication.shared.isRegisteredForRemoteNotifications)

    // Initialize boot splash
    if let rootViewController = window?.rootViewController {
      RNBootSplash.initWithStoryboard("LaunchScreen", rootView: rootViewController.view)
    }

    // Initialize SSL Pinning
     SSLPinning().migrate()

    // Initialize Watch Connection
    watchConnection = WatchConnection(session: WCSession.default)

    return result
  }

    // Remote Notification handling
    public override func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        RNNotifications.didRegisterForRemoteNotifications(withDeviceToken: deviceToken)
        
        let tokenString = deviceToken.map {
            String(format: "%02.2hhx", $0)
        }.joined()
        
        print("📱 APNs Device Token:")
        print(tokenString)
        #if DEBUG
        print("🌱 Using APNs sandbox environment (debug build)")
        #else
        print("🏭 Using APNs production environment (release build)")
        #endif
    }
  
  public override func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
    RNNotifications.didFailToRegisterForRemoteNotificationsWithError(error)
  }
  
  public override func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
    print("🔔 didReceiveRemoteNotification (background):", userInfo)
    RNNotifications.didReceiveBackgroundNotification(userInfo, withCompletionHandler: completionHandler)
  }

  // Linking API
  public override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    return super.application(app, open: url, options: options) || RCTLinkingManager.application(app, open: url, options: options)
  }

  // Universal Links
  public override func application(
    _ application: UIApplication,
    continue userActivity: NSUserActivity,
    restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
  ) -> Bool {
    let result = RCTLinkingManager.application(application, continue: userActivity, restorationHandler: restorationHandler)
    return super.application(application, continue: userActivity, restorationHandler: restorationHandler) || result
  }

  // MARK: - UNUserNotificationCenterDelegate
  public func userNotificationCenter(_ center: UNUserNotificationCenter,
                                     willPresent notification: UNNotification,
                                     withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    let userInfo = notification.request.content.userInfo
    print("🔔 willPresent notification:", userInfo)
    // Present alert, sound, and badge while app is in foreground for debugging
    completionHandler([.banner, .list, .sound, .badge])
  }

  public func userNotificationCenter(_ center: UNUserNotificationCenter,
                                     didReceive response: UNNotificationResponse,
                                     withCompletionHandler completionHandler: @escaping () -> Void) {
    let userInfo = response.notification.request.content.userInfo
    print("📬 didReceive notification response:", userInfo)
    completionHandler()
  }
}

class ReactNativeDelegate: RCTDefaultReactNativeFactoryDelegate {
  override func sourceURL(for bridge: RCTBridge) -> URL? {
    self.bundleURL()
  }

  override func bundleURL() -> URL? {
#if DEBUG
    RCTBundleURLProvider.sharedSettings().jsBundleURL(forBundleRoot: "index")
#else
    Bundle.main.url(forResource: "main", withExtension: "jsbundle")
#endif
  }
}

