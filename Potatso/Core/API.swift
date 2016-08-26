//
//  API.swift
//  Potatso
//
//  Created by LEI on 6/4/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import Foundation
import PotatsoModel
import Alamofire
import ObjectMapper
import ISO8601DateFormatter

struct API {

//    static let URL = "http://192.168.2.217:8000/api/"
    static let URL = "https://api.potatso.com/"

    enum Path {
        case RuleSets
        case RuleSet(String)
        case RuleSetListDetail()

        var url: String {
            let path: String
            switch self {
            case .RuleSets:
                path = "rulesets"
            case .RuleSet(let uuid):
                path = "ruleset/\(uuid)"
            case .RuleSetListDetail():
                path = "rulesets/detail"
            }
            return API.URL + path
        }
    }

    static func getRuleSets(page: Int = 1, count: Int = 20, callback: Alamofire.Response<[RuleSet], NSError> -> Void) {
        DDLogVerbose("API.getRuleSets ===> page: \(page), count: \(count)")
        Alamofire.request(.GET, Path.RuleSets.url, parameters: ["page": page, "count": count]).responseArray(completionHandler: callback)
    }

    static func getRuleSetDetail(uuid: String, callback: Alamofire.Response<RuleSet, NSError> -> Void) {
        DDLogVerbose("API.getRuleSetDetail ===> uuid: \(uuid)")
        Alamofire.request(.GET, Path.RuleSet(uuid).url).responseObject(completionHandler: callback)
    }

    static func updateRuleSetListDetail(uuids: [String], callback: Alamofire.Response<[RuleSet], NSError> -> Void) {
        DDLogVerbose("API.updateRuleSetListDetail ===> uuids: \(uuids)")
        Alamofire.request(.POST, Path.RuleSetListDetail().url, parameters: ["uuids": uuids], encoding: .JSON).responseArray(completionHandler: callback)
    }

}

extension RuleSet: Mappable {

    public convenience init?(_ map: Map) {
        self.init()
        guard let rulesJSON = map.JSONDictionary["rules"] as? [AnyObject] else {
            return
        }
        var rules: [Rule] = []
        if let parsedObject = Mapper<Rule>().mapArray(rulesJSON){
            rules.appendContentsOf(parsedObject)
        }
        self.rules = rules
    }

    // Mappable
    public func mapping(map: Map) {
        uuid      <- map["id"]
        name      <- map["name"]
        createAt  <- (map["created_at"], DateTransform())
        remoteUpdatedAt  <- (map["updated_at"], DateTransform())
        desc      <- map["description"]
        ruleCount <- map["rule_count"]
        isOfficial <- map["is_official"]
    }
}

extension RuleSet {

    static func addRemoteObject(ruleset: RuleSet, update: Bool = true) throws {
        ruleset.isSubscribe = true
        ruleset.deleted = false
        ruleset.editable = false
        let id = ruleset.uuid
        guard let local = DBUtils.get(id, type: RuleSet.self) else {
            try DBUtils.add(ruleset)
            return
        }
        if local.remoteUpdatedAt == ruleset.remoteUpdatedAt && local.deleted == ruleset.deleted {
            return
        }
        try DBUtils.add(ruleset)
    }

    static func addRemoteArray(rulesets: [RuleSet], update: Bool = true) throws {
        for ruleset in rulesets {
            try addRemoteObject(ruleset, update: update)
        }
    }

}

extension Rule: Mappable {

    public convenience init?(_ map: Map) {
        guard let pattern = map.JSONDictionary["pattern"] as? String else {
            return nil
        }
        guard let actionStr = map.JSONDictionary["action"] as? String, action = RuleAction(rawValue: actionStr) else {
            return nil
        }
        guard let typeStr = map.JSONDictionary["type"] as? String, type = RuleType(rawValue: typeStr) else {
            return nil
        }
        self.init(type: type, action: action, value: pattern)
    }

    // Mappable
    public func mapping(map: Map) {
    }
}



struct DateTransform: TransformType {

    func transformFromJSON(value: AnyObject?) -> Double? {
        guard let dateStr = value as? String else {
            return NSDate().timeIntervalSince1970
        }
        return ISO8601DateFormatter().dateFromString(dateStr)?.timeIntervalSince1970
    }

    func transformToJSON(value: Double?) -> AnyObject? {
        guard let v = value else {
            return nil
        }
        let date = NSDate(timeIntervalSince1970: v)
        return ISO8601DateFormatter().stringFromDate(date)
    }

}

extension Alamofire.Request {

    public static func ObjectMapperSerializer<T: Mappable>(keyPath: String?, mapToObject object: T? = nil) -> ResponseSerializer<T, NSError> {
        return ResponseSerializer { request, response, data, error in
            DDLogVerbose("Alamofire response ===> request: \(request.debugDescription), response: \(response.debugDescription)")
            guard error == nil else {
                logError(error!, request: request, response: response)
                return .Failure(error!)
            }

            guard let _ = data else {
                let failureReason = "Data could not be serialized. Input data was nil."
                let error = Error.errorWithCode(.DataSerializationFailed, failureReason: failureReason)
                logError(error, request: request, response: response)
                return .Failure(error)
            }

            let JSONResponseSerializer = Alamofire.Request.JSONResponseSerializer(options: .AllowFragments)
            let result = JSONResponseSerializer.serializeResponse(request, response, data, error)

            if let errorMessage = result.value?.valueForKeyPath("error_message") as? String {
                let error = Error.errorWithCode(.StatusCodeValidationFailed, failureReason: errorMessage)
                logError(error, request: request, response: response)
                return .Failure(error)
            }

            var JSONToMap: AnyObject?
            if let keyPath = keyPath where keyPath.isEmpty == false {
                JSONToMap = result.value?.valueForKeyPath(keyPath)
            } else {
                JSONToMap = result.value
            }

            if let object = object {
                Mapper<T>().map(JSONToMap, toObject: object)
                return .Success(object)
            } else if let parsedObject = Mapper<T>().map(JSONToMap){
                return .Success(parsedObject)
            }

            let failureReason = "ObjectMapper failed to serialize response"
            let error = Error.errorWithCode(.DataSerializationFailed, failureReason: failureReason)
            logError(error, request: request, response: response)
            return .Failure(error)
        }
    }

    /**
     Adds a handler to be called once the request has finished.

     - parameter queue:             The queue on which the completion handler is dispatched.
     - parameter keyPath:           The key path where object mapping should be performed
     - parameter object:            An object to perform the mapping on to
     - parameter completionHandler: A closure to be executed once the request has finished and the data has been mapped by ObjectMapper.

     - returns: The request.
     */

    public func responseObject<T: Mappable>(queue queue: dispatch_queue_t? = nil, keyPath: String? = nil, mapToObject object: T? = nil, completionHandler: Response<T, NSError> -> Void) -> Self {
        return response(queue: queue, responseSerializer: Alamofire.Request.ObjectMapperSerializer(keyPath, mapToObject: object), completionHandler: completionHandler)
    }

    public static func ObjectMapperArraySerializer<T: Mappable>(keyPath: String?) -> ResponseSerializer<[T], NSError> {
        return ResponseSerializer { request, response, data, error in
            DDLogVerbose("Alamofire response ===> request: \(request.debugDescription), response: \(response.debugDescription)")
            guard error == nil else {
                logError(error!, request: request, response: response)
                return .Failure(error!)
            }

            guard let _ = data else {
                let failureReason = "Data could not be serialized. Input data was nil."
                let error = Error.errorWithCode(.DataSerializationFailed, failureReason: failureReason)
                logError(error, request: request, response: response)
                return .Failure(error)
            }

            let JSONResponseSerializer = Alamofire.Request.JSONResponseSerializer(options: .AllowFragments)
            let result = JSONResponseSerializer.serializeResponse(request, response, data, error)

            if let errorMessage = result.value?.valueForKeyPath("error_message") as? String {
                let error = Error.errorWithCode(.StatusCodeValidationFailed, failureReason: errorMessage)
                logError(error, request: request, response: response)
                return .Failure(error)
            }

            let JSONToMap: AnyObject?
            if let keyPath = keyPath where keyPath.isEmpty == false {
                JSONToMap = result.value?.valueForKeyPath(keyPath)
            } else {
                JSONToMap = result.value
            }

            if let parsedObject = Mapper<T>().mapArray(JSONToMap){
                return .Success(parsedObject)
            }

            let failureReason = "ObjectMapper failed to serialize response."
            let error = Error.errorWithCode(.DataSerializationFailed, failureReason: failureReason)
            logError(error, request: request, response: response)
            return .Failure(error)
        }
    }

    /**
     Adds a handler to be called once the request has finished.

     - parameter queue: The queue on which the completion handler is dispatched.
     - parameter keyPath: The key path where object mapping should be performed
     - parameter completionHandler: A closure to be executed once the request has finished and the data has been mapped by ObjectMapper.

     - returns: The request.
     */
    public func responseArray<T: Mappable>(queue queue: dispatch_queue_t? = nil, keyPath: String? = nil, completionHandler: Response<[T], NSError> -> Void) -> Self {
        return response(queue: queue, responseSerializer: Alamofire.Request.ObjectMapperArraySerializer(keyPath), completionHandler: completionHandler)
    }

    private static func logError(error: NSError, request: NSURLRequest?, response: NSURLResponse?) {
        DDLogError("ObjectMapperSerializer failure: \(error), request: \(request?.debugDescription), response: \(response.debugDescription)")
    }
}
