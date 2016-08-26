//
//  BaseModel.swift
//  Potatso
//
//  Created by LEI on 4/6/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import RealmSwift
import PotatsoBase
import CloudKit

private let version: UInt64 = 18
public var defaultRealm: Realm!

public func setupDefaultReaml() {
    var config = Realm.Configuration()
    let sharedURL = Potatso.sharedDatabaseUrl()
    if let originPath = config.fileURL?.path {
        if NSFileManager.defaultManager().fileExistsAtPath(originPath) {
            _ = try? NSFileManager.defaultManager().moveItemAtPath(originPath, toPath: sharedURL.path!)
        }
    }
    config.fileURL = sharedURL
    config.schemaVersion = version
    config.migrationBlock = { migration, oldSchemaVersion in
        if oldSchemaVersion < 18 {
            // Migrating old rules list to json
            migrateRulesList(migration, oldSchemaVersion: oldSchemaVersion)
        }
    }
    Realm.Configuration.defaultConfiguration = config
    defaultRealm = try! Realm()
}


public class BaseModel: Object {
    public dynamic var uuid = NSUUID().UUIDString
    public dynamic var createAt = NSDate().timeIntervalSince1970
    public dynamic var updatedAt = NSDate().timeIntervalSince1970
    public dynamic var deleted = false
    public dynamic var synced = false

    override public static func primaryKey() -> String? {
        return "uuid"
    }
    
    static var dateFormatter: NSDateFormatter {
        let f = NSDateFormatter()
        f.dateFormat = "MM-dd HH:mm:ss"
        return f
    }

    public func validate(inRealm realm: Realm) throws {
        //
    }

}

// MARK: - Migration
func migrateRulesList(migration: Migration, oldSchemaVersion: UInt64) {
    migration.enumerate(RuleSet.className(), { (oldObject, newObject) in
        if oldSchemaVersion > 11 {
            guard let deleted = oldObject!["deleted"] as? Bool where !deleted else {
                return
            }
        }
        guard let rules = oldObject!["rules"] as? List<DynamicObject> else {
            return
        }
        var rulesJSONArray: [[NSObject: AnyObject]] = []
        for rule in rules {
            if oldSchemaVersion > 11 {
                guard let deleted = rule["deleted"] as? Bool where !deleted else {
                    return
                }
            }
            guard let typeRaw = rule["typeRaw"]as? String, contentJSONString = rule["content"] as? String, contentJSON = contentJSONString.jsonDictionary() else {
                return
            }
            var ruleJSON = contentJSON
            ruleJSON["type"] = typeRaw
            rulesJSONArray.append(ruleJSON)
        }
        if let newJSON = (rulesJSONArray as NSArray).jsonString() {
            newObject!["rulesJSON"] = newJSON
            newObject!["ruleCount"] = rulesJSONArray.count
        }
        newObject!["synced"] = false
    })
}
