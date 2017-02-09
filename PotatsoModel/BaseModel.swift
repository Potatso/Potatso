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
        if FileManager.default.fileExists(atPath: originPath) {
            _ = try? FileManager.default.moveItem(atPath: originPath, toPath: sharedURL.path)
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


open class BaseModel: Object {
    open dynamic var uuid = UUID().uuidString
    open dynamic var createAt = Date().timeIntervalSince1970
    open dynamic var updatedAt = Date().timeIntervalSince1970
    open dynamic var deleted = false
    open dynamic var synced = false

    override open static func primaryKey() -> String? {
        return "uuid"
    }
    
    static var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "MM-dd HH:mm:ss"
        return f
    }

    open func validate(inRealm realm: Realm) throws {
        //
    }

}

// MARK: - Migration
func migrateRulesList(_ migration: Migration, oldSchemaVersion: UInt64) {
    migration.enumerateObjects(ofType: RuleSet.className(), { (oldObject, newObject) in
        if oldSchemaVersion > 11 {
            guard let deleted = oldObject!["deleted"] as? Bool, !deleted else {
                return
            }
        }
        guard let rules = oldObject!["rules"] as? List<DynamicObject> else {
            return
        }
        var rulesJSONArray: [[AnyHashable: Any]] = []
        for rule in rules {
            if oldSchemaVersion > 11 {
                guard let deleted = rule["deleted"] as? Bool, !deleted else {
                    return
                }
            }
            guard let typeRaw = rule["typeRaw"]as? String, let contentJSONString = rule["content"] as? String, let contentJSON = contentJSONString.jsonDictionary() else {
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
