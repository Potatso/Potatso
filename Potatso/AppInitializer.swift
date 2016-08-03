//
//  AppInitilizer.swift
//  Potatso
//
//  Created by LEI on 12/27/15.
//  Copyright © 2015 TouchingApp. All rights reserved.
//

import Foundation
import ICSMainFramework
import Appirater
import Fabric

let appID = "1070901416"

class AppInitializer: NSObject, AppLifeCycleProtocol {
    
    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject : AnyObject]?) -> Bool {
        configLogging()
        configAppirater()
        #if !DEBUG
            Fabric.with([Answers.self, Crashlytics.self])
        #endif
        configHelpShift()
        return true
    }

    func configAppirater() {
        Appirater.setAppId(appID)
    }

    func configLogging() {
        DDLog.addLogger(DDTTYLogger.sharedInstance()) // TTY = Xcode console
        DDLog.addLogger(DDASLLogger.sharedInstance()) // ASL = Apple System Logs

        let fileLogger: DDFileLogger = DDFileLogger() // File Logger
        fileLogger.rollingFrequency = 60*60*24*3  // 24 hours
        fileLogger.logFileManager.maximumNumberOfLogFiles = 7
        DDLog.addLogger(fileLogger)
        #if DEBUG
            DDLog.setLevel(DDLogLevel.All, forClass: DDTTYLogger.self)
            DDLog.setLevel(DDLogLevel.All, forClass: DDASLLogger.self)
        #else

        #endif
    }

    func configHelpShift() {
        HelpshiftCore.initializeWithProvider(HelpshiftAll.sharedInstance())
        HelpshiftCore.installForApiKey(HELPSHIFT_KEY, domainName: HELPSHIFT_DOMAIN, appID: HELPSHIFT_ID)
    }
    
}