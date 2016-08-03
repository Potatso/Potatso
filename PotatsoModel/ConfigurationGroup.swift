//
//  ConfigurationGroup.swift
//  Potatso
//
//  Created by LEI on 4/6/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import RealmSwift

public enum ConfigurationGroupError: ErrorType {
    case InvalidConfigurationGroup
    case EmptyName
    case NameAlreadyExists
}

extension ConfigurationGroupError: CustomStringConvertible {
    
    public var description: String {
        switch self {
        case .InvalidConfigurationGroup:
            return "Invalid config group"
        case .EmptyName:
            return "Empty name"
        case .NameAlreadyExists:
            return "Name already exists"
        }
    }
    
}


public class ConfigurationGroup: BaseModel {
    public dynamic var editable = true
    public dynamic var name = ""
    public dynamic var defaultToProxy = true
    public dynamic var dns = ""
    public let proxies = List<Proxy>()
    public let ruleSets = List<RuleSet>()
    
    public override static func indexedProperties() -> [String] {
        return ["name"]
    }
    
    public func validate(inRealm realm: Realm, includeSelf: Bool = false) throws {
        guard name.characters.count > 0 else {
            throw ConfigurationGroupError.EmptyName
        }
        guard realm.objects(ConfigurationGroup).filter("name = '\(name)'").count <= (includeSelf ? 1 : 0) else {
            throw ConfigurationGroupError.NameAlreadyExists
        }
    }

    public override var description: String {
        return name
    }
}

extension ConfigurationGroup {
    
    public convenience init(dictionary: [String: AnyObject], inRealm realm: Realm) throws {
        self.init()
        guard let name = dictionary["name"] as? String else {
            throw ConfigurationGroupError.InvalidConfigurationGroup
        }
        self.name = name
        if realm.objects(RuleSet).filter("name = '\(name)'").first != nil {
            self.name = "\(name) \(ConfigurationGroup.dateFormatter.stringFromDate(NSDate()))"
        }
        if let proxyName = dictionary["proxy"] as? String, proxy = realm.objects(Proxy).filter("name = '\(proxyName)'").first {
            self.proxies.removeAll()
            self.proxies.append(proxy)
        }
        if let ruleSetsName = dictionary["ruleSets"] as? [String] {
            for ruleSetName in ruleSetsName {
                if let ruleSet = realm.objects(RuleSet).filter("name = '\(ruleSetName)'").first {
                    self.ruleSets.append(ruleSet)
                }
            }
        }
        if let defaultToProxy = dictionary["defaultToProxy"] as? NSString {
            self.defaultToProxy = defaultToProxy.boolValue
        }
        if let dns = dictionary["dns"] as? String {
            self.dns = dns
        }
        if let dns = dictionary["dns"] as? [String] {
            self.dns = dns.joinWithSeparator(",")
        }
    }

    
}

// API
extension ConfigurationGroup {

    public func changeName(name: String) throws {
        defaultRealm.beginWrite()
        self.name = name
        do {
            try validate(inRealm: defaultRealm, includeSelf: true)
        }catch {
            defaultRealm.cancelWrite()
            throw error
        }
        try defaultRealm.commitWrite()
    }

}

public func ==(lhs: ConfigurationGroup, rhs: ConfigurationGroup) -> Bool {
    return lhs.uuid == rhs.uuid
}