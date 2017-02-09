//
//  DBUtils.swift
//  Potatso
//
//  Created by LEI on 8/3/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import Foundation
import Realm
import RealmSwift

open class DBUtils {

    fileprivate static func currentRealm(_ realm: Realm?) -> Realm {
        var mRealm = realm
        if mRealm == nil {
            mRealm = try! Realm()
        }
        return mRealm!
    }

    open static func add(_ object: BaseModel, update: Bool = true, setModified: Bool = true, inRealm realm: Realm? = nil) throws {
        let mRealm = currentRealm(realm)
        mRealm.beginWrite()
        if setModified {
            object.setModified()
        }
        mRealm.add(object, update: update)
        try mRealm.commitWrite()
    }

    open static func add<S: Sequence>(_ objects: S, update: Bool = true, setModified: Bool = true, inRealm realm: Realm? = nil) throws where S.Iterator.Element: BaseModel {
        let mRealm = currentRealm(realm)
        mRealm.beginWrite()
        objects.forEach({
            if setModified {
                $0.setModified()
            }
        })
        mRealm.add(objects, update: update)
        try mRealm.commitWrite()
    }

    open static func softDelete<T: BaseModel>(_ id: String, type: T.Type, inRealm realm: Realm? = nil) throws {
        let mRealm = currentRealm(realm)
        guard let object: T = DBUtils.get(id, type: type, inRealm: mRealm) else {
            return
        }
        mRealm.beginWrite()
        object.deleted = true
        object.setModified()
        try mRealm.commitWrite()
    }

    open static func softDelete<T: BaseModel>(_ ids: [String], type: T.Type, inRealm realm: Realm? = nil) throws {
        for id in ids {
            try softDelete(id, type: type, inRealm: realm)
        }
    }

    open static func hardDelete<T: BaseModel>(_ id: String, type: T.Type, inRealm realm: Realm? = nil) throws {
        let mRealm = currentRealm(realm)
        guard let object: T = DBUtils.get(id, type: type, inRealm: mRealm) else {
            return
        }
        mRealm.beginWrite()
        mRealm.delete(object)
        try mRealm.commitWrite()
    }

    open static func hardDelete<T: BaseModel>(_ ids: [String], type: T.Type, inRealm realm: Realm? = nil) throws {
        for id in ids {
            try hardDelete(id, type: type, inRealm: realm)
        }
    }

    open static func mark<T: BaseModel>(_ id: String, type: T.Type, synced: Bool, inRealm realm: Realm? = nil) throws {
        let mRealm = currentRealm(realm)
        guard let object: T = DBUtils.get(id, type: type, inRealm: mRealm) else {
            return
        }
        mRealm.beginWrite()
        object.synced = synced
        try mRealm.commitWrite()
    }

    open static func markAll(syncd: Bool) throws {
        let mRealm = try! Realm()
        mRealm.beginWrite()
        for proxy in mRealm.objects(Proxy.self) {
            proxy.synced = false
        }
        for ruleset in mRealm.objects(RuleSet.self) {
            ruleset.synced = false
        }
        for group in mRealm.objects(ConfigurationGroup.self) {
            group.synced = false
        }
        try mRealm.commitWrite()
    }
}


// Query
extension DBUtils {

    public static func allNotDeleted<T: BaseModel>(_ type: T.Type, filter: String? = nil, sorted: String? = nil, inRealm realm: Realm? = nil) -> Results<T> {
        let deleteFilter = "deleted = false"
        var mFilter = deleteFilter
        if let filter = filter {
            mFilter += " && " + filter
        }
        return all(type, filter: mFilter, sorted: sorted, inRealm: realm)
    }

    public static func all<T: BaseModel>(_ type: T.Type, filter: String? = nil, sorted: String? = nil, inRealm realm: Realm? = nil) -> Results<T> {
        let mRealm = currentRealm(realm)
        var res = mRealm.objects(type)
        if let filter = filter {
            res = res.filter(filter)
        }
        if let sorted = sorted {
            res = res.sorted(byProperty: sorted)
        }
        return res
    }

    public static func get<T: BaseModel>(_ uuid: String, type: T.Type, filter: String? = nil, sorted: String? = nil, inRealm realm: Realm? = nil) -> T? {
        let mRealm = currentRealm(realm)
        var mFilter = "uuid = '\(uuid)'"
        if let filter = filter {
            mFilter += " && " + filter
        }
        var res = mRealm.objects(type).filter(mFilter)
        if let sorted = sorted {
            res = res.sorted(byProperty: sorted)
        }
        return res.first
    }

    public static func modify<T: BaseModel>(_ type: T.Type, id: String, inRealm realm: Realm? = nil, modifyBlock: ((Realm, T) -> Error?)) throws {
        let mRealm = currentRealm(realm)
        guard let object: T = DBUtils.get(id, type: type, inRealm: mRealm) as! T? else {
            return
        }
        mRealm.beginWrite()
        if let error = modifyBlock(mRealm, object) {
            throw error
        }
        do {
            try object.validate(inRealm: mRealm)
        }catch {
            mRealm.cancelWrite()
            throw error
        }
        object.setModified()
        try mRealm.commitWrite()
    }

}

// Sync
extension DBUtils {

    public static func allObjectsToSyncModified() -> [BaseModel] {
        let mRealm = currentRealm(nil)
        let filter = "synced == false && deleted == false"
        let proxies = mRealm.objects(Proxy.self).filter(filter).map({ $0 })
        let rulesets = mRealm.objects(RuleSet.self).filter(filter).map({ $0 })
        let groups = mRealm.objects(ConfigurationGroup.self).filter(filter).map({ $0 })
        var objects: [BaseModel] = []
        
        var iterator1: LazyMapIterator<RLMIterator<Proxy>, Proxy>? = nil
        iterator1 = proxies.makeIterator()
        iterator1?.forEach({ (tObj) in
            objects.append(tObj as BaseModel)
        })
        
        var iterator2: LazyMapIterator<RLMIterator<RuleSet>, RuleSet>? = nil
        iterator2 = rulesets.makeIterator()
        iterator2?.forEach({ (tObj) in
            objects.append(tObj as BaseModel)
        })
        
        var iterator3: LazyMapIterator<RLMIterator<ConfigurationGroup>, ConfigurationGroup>? = nil
        iterator3 = groups.makeIterator()
        iterator3?.forEach({ (tObj) in
            objects.append(tObj as BaseModel)
        })
        return objects
    }

    public static func allObjectsToSyncDeleted() -> [BaseModel] {
        let mRealm = currentRealm(nil)
        let filter = "synced == false && deleted == true"
        let proxies = mRealm.objects(Proxy.self).filter(filter).map({ $0 })
        let rulesets = mRealm.objects(RuleSet.self).filter(filter).map({ $0 })
        let groups = mRealm.objects(ConfigurationGroup.self).filter(filter).map({ $0 })
        var objects: [BaseModel] = []
        
        var iterator1: LazyMapIterator<RLMIterator<Proxy>, Proxy>? = nil
        iterator1 = proxies.makeIterator()
        iterator1?.forEach({ (tObj) in
            objects.append(tObj as BaseModel)
        })
    
        var iterator2: LazyMapIterator<RLMIterator<RuleSet>, RuleSet>? = nil
        iterator2 = rulesets.makeIterator()
        iterator2?.forEach({ (tObj) in
            objects.append(tObj as BaseModel)
        })
        
        var iterator3: LazyMapIterator<RLMIterator<ConfigurationGroup>, ConfigurationGroup>? = nil
        iterator3 = groups.makeIterator()
        iterator3?.forEach({ (tObj) in
            objects.append(tObj as BaseModel)
        })
        return objects
    }
}

// BaseModel API
extension BaseModel {

    func setModified() {
        updatedAt = Date().timeIntervalSince1970
        synced = false
    }

}


// Config Group API
extension ConfigurationGroup {

    public static func changeProxy(forGroupId groupId: String, proxyId: String?) throws {
        try DBUtils.modify(ConfigurationGroup.self, id: groupId) { (realm, group) -> Error? in
            group.proxies.removeAll()
            if let proxyId = proxyId, let proxy = DBUtils.get(proxyId, type: Proxy.self, inRealm: realm){
                group.proxies.append(proxy)
            }
            return nil
        }
    }

    public static func appendRuleSet(forGroupId groupId: String, rulesetId: String) throws {
        try DBUtils.modify(ConfigurationGroup.self, id: groupId) { (realm, group) -> Error? in
            if let ruleset = DBUtils.get(rulesetId, type: RuleSet.self, inRealm: realm) {
                group.ruleSets.append(ruleset)
            }
            return nil
        }
    }

    public static func changeDNS(forGroupId groupId: String, dns: String?) throws {
        try DBUtils.modify(ConfigurationGroup.self, id: groupId) { (realm, group) -> Error? in
            group.dns = dns ?? ""
            return nil
        }
    }

    public static func changeName(forGroupId groupId: String, name: String) throws {
        try DBUtils.modify(ConfigurationGroup.self, id: groupId) { (realm, group) -> Error? in
            group.name = name
            return nil
        }
    }

}

