//
//  RuleSet.swift
//  Potatso
//
//  Created by LEI on 4/6/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import RealmSwift

public enum RuleSetError: ErrorType {
    case InvalidRuleSet
    case EmptyName
    case NameAlreadyExists
}

extension RuleSetError: CustomStringConvertible {
    
    public var description: String {
        switch self {
        case .InvalidRuleSet:
            return "Invalid rule set"
        case .EmptyName:
            return "Empty name"
        case .NameAlreadyExists:
            return "Name already exists"
        }
    }
    
}

public final class RuleSet: BaseModel {
    public dynamic var editable = true
    public dynamic var name = ""
    public dynamic var remoteUpdatedAt: NSTimeInterval = NSDate().timeIntervalSince1970
    public dynamic var desc = ""
    public dynamic var ruleCount = 0
    public dynamic var rulesJSON = ""
    public dynamic var isSubscribe = false
    public dynamic var isOfficial = false

    private var cachedRules: [Rule]? = nil

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
            throw RuleSetError.EmptyName
        }
    }

    private func updateCahcedRules() {
        guard let jsonArray = rulesJSON.jsonArray() as? [[String: AnyObject]] else {
            cachedRules = []
            return
        }
        cachedRules = jsonArray.flatMap({ Rule(json: $0) })
    }

    public func addRule(rule: Rule) {
        var newRules = rules
        newRules.append(rule)
        rules = newRules
    }

    public func insertRule(rule: Rule, atIndex index: Int) {
        var newRules = rules
        newRules.insert(rule, atIndex: index)
        rules = newRules
    }

    public func removeRule(atIndex index: Int) {
        var newRules = rules
        newRules.removeAtIndex(index)
        rules = newRules
    }

    public func move(fromIndex: Int, toIndex: Int) {
        var newRules = rules
        let rule = newRules[fromIndex]
        newRules.removeAtIndex(fromIndex)
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
            throw RuleSetError.InvalidRuleSet
        }
        self.name = name
        if realm.objects(RuleSet).filter("name = '\(name)'").first != nil {
            self.name = "\(name) \(RuleSet.dateFormatter.stringFromDate(NSDate()))"
        }
        guard let rulesStr = dictionary["rules"] as? [String] else {
            throw RuleSetError.InvalidRuleSet
        }
        rules = try rulesStr.map({ try Rule(str: $0) })
    }
    
}

public func ==(lhs: RuleSet, rhs: RuleSet) -> Bool {
    return lhs.uuid == rhs.uuid
}