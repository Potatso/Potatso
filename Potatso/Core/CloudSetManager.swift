//
//  CloudSetManager.swift
//  Potatso
//
//  Created by LEI on 8/13/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import Foundation
import Async
import RealmSwift

class CloudSetManager {

    static let shared = CloudSetManager()

    private init() {

    }

    func update() {
        Async.background(after: 1.5) {
            let realm = try! Realm()
            let uuids = realm.objects(RuleSet).filter("isSubscribe = true").map({$0.uuid})
            API.updateRuleSetListDetail(uuids) { (response) in
                if let sets = response.result.value {
                    do {
                        try RuleSet.addRemoteArray(sets)
                    }catch {
                        error.log("Unable to save updated rulesets")
                        return
                    }
                }else {
                    response.result.error?.log("Fail to update ruleset details")
                }
            }
        }
    }
}