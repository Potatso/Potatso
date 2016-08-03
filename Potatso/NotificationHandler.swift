//
//  NotificationHandler.swift
//  Potatso
//
//  Created by LEI on 7/23/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import Foundation
import ICSMainFramework

class NotificationHandler: NSObject, AppLifeCycleProtocol {

    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject : AnyObject]?) -> Bool {
        configPush()
        if let launchOptions = launchOptions, userInfo = launchOptions[UIApplicationLaunchOptionsRemoteNotificationKey] as? [NSObject: AnyObject], origin = userInfo["origin"] as? String {
            if origin == "helpshift" {
                if let rootVC = application.keyWindow?.rootViewController {
                    HelpshiftCore.handleRemoteNotification(userInfo, withController: rootVC)
                }
            }
        }
        return true
    }

    func configPush() {
        let settings: UIUserNotificationSettings = UIUserNotificationSettings(forTypes: [.Badge, .Alert, .Sound], categories: nil)
        UIApplication.sharedApplication().registerUserNotificationSettings(settings)
        UIApplication.sharedApplication().registerForRemoteNotifications()
    }

    func applicationDidBecomeActive(application: UIApplication) {
        UIApplication.sharedApplication().applicationIconBadgeNumber = 0
    }

    func application(application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: NSData) {
        print("didRegisterForRemoteNotificationsWithDeviceToken: \(deviceToken.hexString())")
        HelpshiftCore.registerDeviceToken(deviceToken)
    }

    func application(application: UIApplication, didReceiveRemoteNotification userInfo: [NSObject : AnyObject], fetchCompletionHandler completionHandler: (UIBackgroundFetchResult) -> Void) {
        if let origin = userInfo["origin"] as? String {
            if origin == "helpshift" {
                if let rootVC = application.keyWindow?.rootViewController {
                    HelpshiftCore.handleRemoteNotification(userInfo, withController: rootVC)
                }
                completionHandler(.NewData)
                return
            }
        }
        completionHandler(.NoData)
    }

}

extension NSData {
    func hexString() -> String {
        // "Array" of all bytes:
        let bytes = UnsafeBufferPointer<UInt8>(start: UnsafePointer(self.bytes), count:self.length)
        // Array of hex strings, one for each byte:
        let hexBytes = bytes.map { String(format: "%02hhx", $0) }
        // Concatenate all hex strings:
        return hexBytes.joinWithSeparator("")
    }
}