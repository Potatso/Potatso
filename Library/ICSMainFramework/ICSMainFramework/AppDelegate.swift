//
//  AppDelegate.swift
//  ICDSMainFramework
//
//  Created by LEI on 2/26/15.
//  Copyright (c) 2015 TouchingApp. All rights reserved.
//

import UIKit

public class AppDelegate: UIResponder, UIApplicationDelegate {
    
    public var bootstrapViewController: UIViewController {
        return UIViewController()
    }
    public var window: UIWindow?
    
    public func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        // Override point for customization after application launch.
        window = UIWindow(frame: UIScreen.mainScreen().bounds)
        window?.backgroundColor = UIColor.whiteColor()
        window?.makeKeyAndVisible()
        appConfig.loadConfig("config.plist")
        if let lifeCycleItems = appConfig.lifeCycleConfig[LifeCycleKey.didFinishLaunchingWithOptions] {
            for item in lifeCycleItems{
                item.object?.application?(application, didFinishLaunchingWithOptions: launchOptions)
            }
        }
        return true
    }

    public func applicationWillResignActive(application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }
    
    public func applicationDidEnterBackground(application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        if let lifeCycleItems = appConfig.lifeCycleConfig[LifeCycleKey.didEnterBackground] {
            for item in lifeCycleItems{
                item.object?.applicationDidEnterBackground?(application)
            }
        }
    }
    
    public func applicationWillEnterForeground(application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
        if let lifeCycleItems = appConfig.lifeCycleConfig[LifeCycleKey.willEnterForeground] {
            for item in lifeCycleItems{
                item.object?.applicationWillEnterForeground?(application)
            }
        }
    }
    
    public func applicationDidBecomeActive(application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        if let lifeCycleItems = appConfig.lifeCycleConfig[LifeCycleKey.didBecomeActive] {
            for item in lifeCycleItems{
                item.object?.applicationDidBecomeActive?(application)
            }
        }
    }
    
    public func applicationWillTerminate(application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        if let lifeCycleItems = appConfig.lifeCycleConfig[LifeCycleKey.willTerminate] {
            for item in lifeCycleItems{
                item.object?.applicationWillTerminate?(application)
            }
        }
    }
    
    public func application(application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: NSData) {
        if let lifeCycleItems = appConfig.lifeCycleConfig[LifeCycleKey.remoteNotification] {
            for item in lifeCycleItems{
                item.object?.application?(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
            }
        }
    }

    public func application(application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: NSError) {
        if let lifeCycleItems = appConfig.lifeCycleConfig[LifeCycleKey.remoteNotification] {
            for item in lifeCycleItems{
                item.object?.application?(application, didFailToRegisterForRemoteNotificationsWithError: error)
            }
        }
    }
    
    public func application(application: UIApplication, didReceiveRemoteNotification userInfo: [NSObject : AnyObject], fetchCompletionHandler completionHandler: (UIBackgroundFetchResult) -> Void) {
        if let lifeCycleItems = appConfig.lifeCycleConfig[LifeCycleKey.remoteNotification] {
            for item in lifeCycleItems{
                item.object?.application?(application, didReceiveRemoteNotification: userInfo, fetchCompletionHandler: completionHandler)
            }
        }
    }

    public func application(app: UIApplication, openURL url: NSURL, options: [String : AnyObject]) -> Bool {
        var handled = false
        if let lifeCycleItems = appConfig.lifeCycleConfig[LifeCycleKey.openURL] {
            for item in lifeCycleItems{
                if #available(iOSApplicationExtension 9.0, *) {
                    if let res = item.object?.application?(app, openURL: url, options: options) where res{
                        handled = res
                    }
                } else {
                    // Fallback on earlier versions
                }
            }
        }
        return handled
    }
    
}

