//
//  Config.swift
//  Potatso
//
//  Created by LEI on 4/6/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import RealmSwift
import PotatsoModel
import YAML

public enum ConfigError: Error {
    case downloadFail
    case syntaxError
}

extension ConfigError: CustomStringConvertible {
    
    public var description: String {
        switch self {
        case .downloadFail:
            return "Download fail"
        case .syntaxError:
            return "Syntax error"
        }
    }
    
}

open class Config {
    
    open var groups: [ConfigurationGroup] = []
    open var proxies: [Proxy] = []
    open var ruleSets: [RuleSet] = []
    
    let realm: Realm
    var configDict: [String: AnyObject] = [:]
    
    public init() {
        realm = try! Realm()
    }
    
    open func setup(string configString: String) throws {
        guard configString.characters.count > 0, let object = try? YAMLSerialization.object(withYAMLString: configString, options: kYAMLReadOptionStringScalars), let yaml = object as? [String: AnyObject] else {
            throw ConfigError.syntaxError
        }
        self.configDict = yaml
        try setupModels()
    }
    
    open func setup(url: URL) throws {
        guard let string = try? String(contentsOf: url) else {
            throw ConfigError.downloadFail
        }
        try setup(string: string)
    }
    
    open func save() throws {
        do {
            try realm.commitWrite()
        }catch {
            throw error
        }
    }
    
    func setupModels() throws {
        realm.beginWrite()
        do {
            try setupProxies()
            try setupRuleSets()
            try setupConfigGroups()
        }catch {
            realm.cancelWrite()
            throw error
        }
    }
    
    func setupProxies() throws {
        if let proxiesConfig = configDict["proxies"] as? [[String: AnyObject]] {
            proxies = try proxiesConfig.map({ (config) -> Proxy? in
                return try Proxy(dictionary: config, inRealm: realm)
            }).filter { $0 != nil }.map { $0! }
            try proxies.forEach {
                try $0.validate(inRealm: realm)
                realm.add($0)
            }
        }
    }
    
    func setupRuleSets() throws{
        if let proxiesConfig = configDict["ruleSets"] as? [[String: AnyObject]] {
            ruleSets = try proxiesConfig.map({ (config) -> RuleSet? in
                return try RuleSet(dictionary: config, inRealm: realm)
            }).filter { $0 != nil }.map { $0! }
            try ruleSets.forEach {
                try $0.validate(inRealm: realm)
                realm.add($0)
            }
        }
    }
    
    func setupConfigGroups() throws{
        if let proxiesConfig = configDict["configGroups"] as? [[String: AnyObject]] {
            groups = try proxiesConfig.map({ (config) -> ConfigurationGroup? in
                return try ConfigurationGroup(dictionary: config, inRealm: realm)
            }).filter { $0 != nil }.map { $0! }
            try groups.forEach {
                try $0.validate(inRealm: realm)
                realm.add($0)
            }
        }
    }

}
