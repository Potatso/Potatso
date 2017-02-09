//
//  NotificationHandler.swift
//  Potatso
//
//  Created by LEI on 7/23/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import Foundation
import ICSMainFramework
import CloudKit

class NotificationHandler: NSObject, AppLifeCycleProtocol {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        configPush()
        if let launchOptions = launchOptions, let userInfo = launchOptions[UIApplicationLaunchOptionsKey.remoteNotification] as? [AnyHashable: Any], let origin = userInfo["origin"] as? String {
            if origin == "helpshift" {
                if let rootVC = application.keyWindow?.rootViewController {
                    HelpshiftCore.handleRemoteNotification(userInfo, with: rootVC)
                }
            }
        }
        return true
    }

    func configPush() {
        let settings: UIUserNotificationSettings = UIUserNotificationSettings(types: [.badge, .alert, .sound], categories: nil)
        UIApplication.shared.registerUserNotificationSettings(settings)
        UIApplication.shared.registerForRemoteNotifications()
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        UIApplication.shared.applicationIconBadgeNumber = 0
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        DDLogInfo("didRegisterForRemoteNotificationsWithDeviceToken: \(deviceToken.hexString())")
        HelpshiftCore.registerDeviceToken(deviceToken)
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        if let origin = userInfo["origin"] as? String {
            if origin == "helpshift" {
                DDLogInfo("received a helpshift notification")
                if let rootVC = application.keyWindow?.rootViewController {
                    HelpshiftCore.handleRemoteNotification(userInfo, with: rootVC)
                }
                completionHandler(.newData)
                return
            }
        }
        if let dict = userInfo as? [String: NSObject] {
            let ckNotification = CKNotification(fromRemoteNotificationDictionary: dict)
            if ckNotification.subscriptionID == potatsoSubscriptionId {
                DDLogInfo("received a CKNotification")
                SyncManager.shared.sync()
            }
        }
        completionHandler(.noData)
    }

}

extension Data {
    func hexString() -> String {
        // "Array" of all bytes:
        let bytes = UnsafeBufferPointer<UInt8>(start: (self as NSData).bytes.bindMemory(to: UInt8.self, capacity: self.count), count:self.count)
        // Array of hex strings, one for each byte:
        let hexBytes = bytes.map { String(format: "%02hhx", $0) }
        // Concatenate all hex strings:
        return hexBytes.joined(separator: "")
    }
}
