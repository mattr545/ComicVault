//
//  AppDelegate+Push.swift
//  ComicVault
//
//  File created on 10/27/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: AppDelegate extension to handle push notifications (e.g., CloudKit, alerts).
//

import Foundation
import UIKit
import CloudKit
#if USE_CLOUDSYNC
// …existing file contents, unchanged…
#endif


final class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        // Background Modes → Remote notifications must be enabled in target capabilities.
        application.registerForRemoteNotifications()
        return true
    }

    // MARK: - Remote Notification Registration

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        #if DEBUG
        print("[Push] Remote notifications registered.")
        #endif
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        #if DEBUG
        print("[Push] Failed to register for remote notifications:", error.localizedDescription)
        #endif
    }

    // MARK: - Receive CloudKit Notification (silent)

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable : Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        // Only react to CloudKit pushes
        if CKNotification(fromRemoteNotificationDictionary: userInfo) != nil {
            NotificationCenter.default.post(name: .ckRemoteChange, object: nil)
            completionHandler(.newData)
        } else {
            completionHandler(.noData)
        }
    }
}
#if USE_CLOUDSYNC
// …existing file contents, unchanged…
#endif
