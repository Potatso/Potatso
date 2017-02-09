//
//  CloudKitRecord.swift
//  Potatso
//
//  Created by LEI on 8/3/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import Foundation
import PotatsoModel
import CloudKit
import Realm
import RealmSwift

let potatsoZoneId = CKRecordZoneID(zoneName: "PotatsoCloud", ownerName: CKOwnerDefaultName)
let potatsoDB = CKContainer.default().privateCloudDatabase
let potatsoSubscriptionId = "allSubscription"

public protocol CloudKitRecord {
    static var recordType: String { get }
    static var keys: [String] { get }
    var recordId: CKRecordID { get }
    func toCloudKitRecord() -> CKRecord
    static func fromCloudKitRecord(_ record: CKRecord) -> Self
}

extension BaseModel {

    public static var basekeys: [String] {
        return ["uuid", "createAt", "updatedAt", "deleted"]
    }

}

extension Proxy: CloudKitRecord {

    public static var recordType: String {
        return "Proxy"
    }

    public static var keys: [String] {
        return basekeys + ["typeRaw", "name", "host", "port", "authscheme", "user", "password", "ota", "ssrProtocol", "ssrObfs", "ssrObfsParam"]
    }

    public var recordId: CKRecordID {
        return CKRecordID(recordName: uuid, zoneID: potatsoZoneId)
    }

    public func toCloudKitRecord() -> CKRecord {
        let record = CKRecord(recordType: Proxy.recordType, recordID: recordId)
        for key in Proxy.keys {
            record.setValue(self.value(forKey: key), forKey: key)
        }
        return record
    }

    public static func fromCloudKitRecord(_ record: CKRecord) -> Self {
        let proxy = self.init()
        for key in Proxy.keys {
            if let v = record.value(forKey: key) {
                proxy.setValue(v, forKey: key)
            }
        }
        return proxy
    }
}

extension RuleSet: CloudKitRecord {

    public static var recordType: String {
        return "RuleSet"
    }

    public static var keys: [String] {
        return basekeys + ["editable", "name", "remoteUpdatedAt", "desc", "ruleCount", "isSubscribe", "isOfficial", "rulesJSON"]
    }

    public var recordId: CKRecordID {
        return CKRecordID(recordName: uuid, zoneID: potatsoZoneId)
    }

    public func toCloudKitRecord() -> CKRecord {
        let record = CKRecord(recordType: RuleSet.recordType, recordID: recordId)
        for key in RuleSet.keys {
            record.setValue(self.value(forKey: key), forKey: key)
        }
        return record
    }

    public static func fromCloudKitRecord(_ record: CKRecord) -> Self {
        let ruleset = self.init()
        for key in RuleSet.keys {
            if let v = record.value(forKey: key) {
                ruleset.setValue(v, forKey: key)
            }
        }
        return ruleset
    }
}

extension ConfigurationGroup: CloudKitRecord {

    public static var recordType: String {
        return "ConfigurationGroup"
    }

    public static var keys: [String] {
        return basekeys + ["editable", "name", "defaultToProxy"]
    }

    public var recordId: CKRecordID {
        return CKRecordID(recordName: uuid, zoneID: potatsoZoneId)
    }

    public func toCloudKitRecord() -> CKRecord {
        let record = CKRecord(recordType: ConfigurationGroup.recordType, recordID: recordId)
        for key in ConfigurationGroup.keys {
            record.setValue(self.value(forKey: key), forKey: key)
        }
        record["proxies"] = proxies.map({ $0.uuid }).joined(separator: ",") as CKRecordValue?
        record["ruleSets"] = ruleSets.map({ $0.uuid }).joined(separator: ",") as CKRecordValue?
        return record
    }

    public static func fromCloudKitRecord(_ record: CKRecord) -> Self {
        let group = self.init()
        for key in ConfigurationGroup.keys {
            if let v = record.value(forKey: key) {
                group.setValue(v, forKey: key)
            }
        }
        let realm = try! Realm()
        if let rulesUUIDs = record["proxies"] as? String {
            let uuids = rulesUUIDs.components(separatedBy: ",")
            let rules = uuids.flatMap({ realm.objects(Proxy.self).filter("uuid = '\($0)'").first })
            
            for r in rules {
                group.proxies.append(r)
            }
        }
        if let rulesUUIDs = record["ruleSets"] as? String {
            let uuids = rulesUUIDs.components(separatedBy: ",")
            let rules = uuids.flatMap({ realm.objects(RuleSet.self).filter("uuid = '\($0)'").first })
            
            for r in rules {
                group.ruleSets.append(r)
            }
        }
        return group
    }
}

extension CKRecord {

    var realmClassType: BaseModel.Type? {
        let type: BaseModel.Type?
        switch recordType {
        case "Proxy":
            type = Proxy.self
        case "RuleSet":
            type = RuleSet.self
        case "ConfigurationGroup":
            type = ConfigurationGroup.self
        default:
            return nil
        }
        return type
    }

}

func changeLocalRecord(_ record: CKRecord) throws {
    let realmObject: BaseModel
    guard let type = record.realmClassType else {
        return
    }
    let id = record.recordID.recordName
    let local: BaseModel? = DBUtils.get(id, type: type)
    switch record.recordType {
    case "Proxy":
        realmObject = Proxy.fromCloudKitRecord(record)
    case "RuleSet":
        realmObject = RuleSet.fromCloudKitRecord(record)
    case "ConfigurationGroup":
        realmObject = ConfigurationGroup.fromCloudKitRecord(record)
    default:
        return
    }
    realmObject.synced = true
    if let local = local, let type = record.realmClassType {
        if local.updatedAt > realmObject.updatedAt {
            try DBUtils.mark(local.uuid, type: type, synced: false)
            return
        } else if local.updatedAt == realmObject.updatedAt {
            try DBUtils.mark(local.uuid, type: type, synced: true)
            return
        }
    }
    try DBUtils.add(realmObject, setModified: false)
}

func deleteLocalRecord(_ recordID: CKRecordID) throws {
    let id = recordID.recordName
    try DBUtils.hardDelete(id, type: Proxy.self)
    try DBUtils.hardDelete(id, type: RuleSet.self)
    try DBUtils.hardDelete(id, type: ConfigurationGroup.self)
}

