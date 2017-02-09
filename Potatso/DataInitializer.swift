//
//  DBInitializer.swift
//  Potatso
//
//  Created by LEI on 3/8/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import UIKit
import ICSMainFramework
import NetworkExtension
import CloudKit
import Async
import RealmSwift
import Realm

class DataInitializer: NSObject, AppLifeCycleProtocol {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        Manager.sharedManager.setup()
        CloudSetManager.shared.update()
        sync()
        return true
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        _ = try? Manager.sharedManager.regenerateConfigFiles()
    }

    func applicationWillTerminate(_ application: UIApplication) {
        _ = try? Manager.sharedManager.regenerateConfigFiles()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        Receipt.shared.validate()
        sync()
    }

    func sync() {
        SyncManager.shared.sync()
    }

}
