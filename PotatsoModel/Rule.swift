//
//  Rule.swift
//  Potatso
//
//  Created by LEI on 4/6/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import RealmSwift
import PotatsoBase

private let ruleValueKey = "value";
private let ruleActionKey = "action";

public enum RuleType: String {
    case URLMatch = "URL-MATCH"
    case URL = "URL"
    case Domain = "DOMAIN"
    case DomainMatch = "DOMAIN-MATCH"
    case DomainSuffix = "DOMAIN-SUFFIX"
    case GeoIP = "GEOIP"
    case IPCIDR = "IP-CIDR"
}

extension RuleType {
    
    public static func fromInt(_ intValue: Int) -> RuleType? {
        switch intValue {
        case 1:
            return .Domain
        case 2:
            return .DomainSuffix
        case 3:
            return .DomainMatch
        case 4:
            return .URL
        case 5:
            return .URLMatch
        case 6:
            return .GeoIP
        case 7:
            return .IPCIDR
        default:
            return nil
        }
    }
    
}

extension RuleType: CustomStringConvertible {
    
    public var description: String {
        return rawValue
    }
    
}

public enum RuleAction: String {
    case Direct = "DIRECT"
    case Reject = "REJECT"
    case Proxy = "PROXY"
}

extension RuleAction {
    
    public static func fromInt(_ intValue: Int) -> RuleAction? {
        switch intValue {
        case 1:
            return .Direct
        case 2:
            return .Reject
        case 3:
            return .Proxy
        default:
            return nil
        }
    }
    
}

extension RuleAction: CustomStringConvertible {
    
    public var description: String {
        return rawValue
    }
    
}

public enum RuleError: Error {
    case invalidRule(String)
}

//extension RuleError: CustomStringConvertible {
//    
//    public var description: String {
//        switch self {
//        case .InvalidRule(let rule):
//            return "Invalid rule - \(rule)"
//        }
//    }
//    
//}
//
//public final class Rule: BaseModel {
//    
//    public dynamic var typeRaw = ""
//    public dynamic var content = ""
//    public dynamic var order = 0
//    public let rulesets = LinkingObjects(fromType: RuleSet.self, property: "rules")
//
//}
//
//extension Rule {
//    
//    public var type : RuleType {
//        get {
//            return RuleType(rawValue: typeRaw) ?? .DomainSuffix
//        }
//        set(v) {
//            typeRaw = v.rawValue
//        }
//    }
//    
//    public var action : RuleAction {
//        let json = content.jsonDictionary()
//        if let raw = json?[ruleActionKey] as? String {
//            return RuleAction(rawValue: raw) ?? .Proxy
//        }
//        return .Proxy
//    }
//    
//    public var value : String {
//        let json = content.jsonDictionary()
//        return json?[ruleValueKey] as? String ?? ""
//    }
//
//}
//
public final class Rule {

    public var type: RuleType
    public var value: String
    public var action: RuleAction
    
    public convenience init(str: String) throws {
        var ruleStr = str.replacingOccurrences(of: "\t", with: "")
        ruleStr = ruleStr.replacingOccurrences(of: " ", with: "")
        let parts = ruleStr.components(separatedBy: ",")
        guard parts.count >= 3 else {
            throw RuleError.invalidRule(str)
        }
        let actionStr = parts[2].uppercased()
        let typeStr = parts[0].uppercased()
        let value = parts[1]
        guard let type = RuleType(rawValue: typeStr), let action = RuleAction(rawValue: actionStr), value.characters.count > 0 else {
            throw RuleError.invalidRule(str)
        }
        self.init(type: type, action: action, value: value)
    }
    
    public init(type: RuleType, action: RuleAction, value: String) {
        self.type = type
        self.value = value
        self.action = action
    }

    public convenience init?(json: [String: AnyObject]) {
        guard let typeRaw = json["type"] as? String, let type = RuleType(rawValue: typeRaw) else {
            return nil
        }
        guard let actionRaw = json["action"] as? String, let action = RuleAction(rawValue: actionRaw) else {
            return nil
        }
        guard let value = json["value"] as? String else {
            return nil
        }
        self.init(type: type, action: action, value: value)
    }

    public var description: String {
        return "\(type), \(value), \(action)"
    }

    public var json: [String: AnyObject] {
        return ["type": type.rawValue as AnyObject, "value": value as AnyObject, "action": action.rawValue as AnyObject]
    }
}
//
//
//public func ==(lhs: Rule, rhs: Rule) -> Bool {
//    return lhs.uuid == rhs.uuid
//}
