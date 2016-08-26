//
//  FeedbackManager.swift
//  Potatso
//
//  Created by LEI on 8/4/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import Foundation
import ICSMainFramework
import LogglyLogger_CocoaLumberjack

class FeedbackManager {
    static let shared = FeedbackManager()

    func showFeedback(inVC vc: UIViewController? = nil) {
        guard let currentVC = vc ?? UIApplication.sharedApplication().keyWindow?.rootViewController else {
            return
        }
        let options = [
            "gotoConversationAfterContactUs": "YES"
        ]
        let rulesets = Manager.sharedManager.defaultConfigGroup.ruleSets.map({ $0.name }).joinWithSeparator(", ")
        let defaultToProxy = Manager.sharedManager.defaultConfigGroup.defaultToProxy
        var tags: [String] = []
        if AppEnv.isTestFlight {
            tags.append("testflight")
        } else if AppEnv.isAppStore {
            tags.append("store")
        }
        NSNotificationCenter.defaultCenter().postNotificationName(LogglyLoggerForceUploadNotification, object: nil)
        HelpshiftSupport.setUserIdentifier(User.currentUser.id)
        HelpshiftSupport.setMetadataBlock { () -> [NSObject : AnyObject]! in
            return [
                "Full Version": AppEnv.fullVersion,
                "Default To Proxy": defaultToProxy ? "true": "false",
                "Rulesets": rulesets,
                HelpshiftSupportTagsKey: tags
            ]
        }
        HelpshiftSupport.showConversation(currentVC, withOptions: options)
    }
}