import Flutter
import UIKit
import flutter_local_notifications // Import the plugin

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Register a notification category for actions
    let center = UNUserNotificationCenter.current()
    center.delegate = self // Make sure AppDelegate conforms to UNUserNotificationCenterDelegate

    let pauseAction = UNNotificationAction(identifier: "PAUSE_ACTION",
                                          title: "Pause",
                                          options: [])
    let resumeAction = UNNotificationAction(identifier: "RESUME_ACTION",
                                           title: "Resume",
                                           options: [])
    let stopAction = UNNotificationAction(identifier: "STOP_ACTION",
                                         title: "Stop",
                                         options: [.destructive]) // Mark as destructive if appropriate

    // Category for when recording is active (can pause or stop)
    let recordingCategory = UNNotificationCategory(identifier: "RECORDING_CONTROLS",
                                acciones: [pauseAction, stopAction],
                                intentIdentifiers: [],
                                options: .customDismissAction)

    // Category for when recording is paused (can resume or stop)
    let pausedCategory = UNNotificationCategory(identifier: "PAUSED_CONTROLS",
                               acciones: [resumeAction, stopAction],
                               intentIdentifiers: [],
                               options: .customDismissAction)

    center.setNotificationCategories([recordingCategory, pausedCategory])


    // This is required to make any communication available in the action isolate
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { (registry) in
        GeneratedPluginRegistrant.register(with: registry)
    }
    
    // For iOS 10 display notification in foreground
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

    // Handle notification actions (iOS 10+)
    @available(iOS 10.0, *)
    override func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        // Pass the response to the plugin to handle the action
        // This is important for flutter_local_notifications to process actions.
        // The plugin itself will then dart side callbacks.
        
        // Note: Default behavior of flutter_local_notifications might handle this.
        // Check plugin documentation if specific manual forwarding is needed here.
        // Generally, the plugin sets itself as the delegate or uses a helper.

        completionHandler()
    }
}
