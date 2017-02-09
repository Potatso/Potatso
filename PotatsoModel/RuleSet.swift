//
//  RuleSet.swift
//  Potatso
//
//  Created by LEI on 4/6/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import RealmSwift

public enum RuleSetError: Error {
    case invalidRuleSet
    case emptyName
    case nameAlreadyExists
}

extension RuleSetError: CustomStringConvertible {
    
    public var description: String {
        switch self {
        case .invalidRuleSet:
            return "Invalid rule set"
        case .emptyName:
            return "Empty name"
        case .nameAlreadyExists:
            return "Name already exists"
        }
    }
    
}

public final class RuleSet: BaseModel {
    public dynamic var editable = true
    public dynamic var name = ""
    public dynamic var remoteUpdatedAt: TimeInterval = Date().timeIntervalSince1970
    public dynamic var desc = ""
    public dynamic var ruleCount = 0
    public dynamic var rulesJSON = ""
    public dynamic var isSubscribe = false
    public dynamic var isOfficial = false

    fileprivate var cachedRules: [Rule]? = nil

    public var rules: [Rule] {
        get {
            if let cachedRules = cachedRules {
                return cachedRules
            }
            updateCahcedRules()
            return cachedRules!
        }
        set {
            let json = (newValue.map({ $0.json }) as NSArray).jsonString() ?? ""
            rulesJSON = json
            updateCahcedRules()
            ruleCount = newValue.count
        }
    }

    public override func validate(inRealm realm: Realm) throws {
        guard name.characters.count > 0 else {
            throw RuleSetError.emptyName
        }
    }

    fileprivate func updateCahcedRules() {
        guard let jsonArray = rulesJSON.jsonArray() as? [[String: AnyObject]] else {
            cachedRules = []
            return
        }
        cachedRules = jsonArray.flatMap({ Rule(json: $0) })
    }

    public func addRule(_ rule: Rule) {
        var newRules = rules
        newRules.append(rule)
        rules = newRules
    }

    public func insertRule(_ rule: Rule, atIndex index: Int) {
        var newRules = rules
        newRules.insert(rule, at: index)
        rules = newRules
    }

    public func removeRule(atIndex index: Int) {
        var newRules = rules
        newRules.remove(at: index)
        rules = newRules
    }

    public func move(_ fromIndex: Int, toIndex: Int) {
        var newRules = rules
        let rule = newRules[fromIndex]
        newRules.remove(at: fromIndex)
        insertRule(rule, atIndex: toIndex)
        rules = newRules
    }
}

extension RuleSet {
    
    public override static func indexedProperties() -> [String] {
        return ["name"]
    }
    
}

extension RuleSet {
    
    public convenience init(dictionary: [String: AnyObject], inRealm realm: Realm) throws {
        self.init()
        guard let name = dictionary["name"] as? String else {
            throw RuleSetError.invalidRuleSet
        }
        self.name = name
        if realm.objects(RuleSet).filter("name = '\(name)'").first != nil {
            self.name = "\(name) \(RuleSet.dateFormatter.string(from: Date()))"
        }
        guard let rulesStr = dictionary["rules"] as? [String] else {
            throw RuleSetError.invalidRuleSet
        }
        rules = try rulesStr.map({ try Rule(str: $0) })
    }
    
}

public func ==(lhs: RuleSet, rhs: RuleSet) -> Bool {
    return lhs.uuid == rhs.uuid
}
