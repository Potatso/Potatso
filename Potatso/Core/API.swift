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
import class ISO8601DateFormatter.ISO8601DateFormatter
typealias waDateFormatter = ISO8601DateFormatter

struct API {

//    static let URL = "http://192.168.2.217:8000/api/"
    static let URL = "https://api.potatso.com/"

    enum Path {
        case ruleSets
        case ruleSet(String)
        case ruleSetListDetail()

        var url: String {
            let path: String
            switch self {
            case .ruleSets:
                path = "rulesets"
            case .ruleSet(let uuid):
                path = "ruleset/\(uuid)"
            case .ruleSetListDetail():
                path = "rulesets/detail"
            }
            return API.URL + path
        }
    }

    static func getRuleSets(_ page: Int = 1, count: Int = 20, callback: @escaping (Alamofire.DataResponse<[RuleSet]>) -> Void) {
        DDLogVerbose("API.getRuleSets ===> page: \(page), count: \(count)")
        _ = Alamofire.request(Path.ruleSets.url, method: .get, parameters: ["page": page, "count": count], encoding: URLEncoding.default).responseArray(completionHandler: callback)
    }

    static func getRuleSetDetail(_ uuid: String, callback: @escaping (Alamofire.DataResponse<RuleSet>) -> Void) {
        DDLogVerbose("API.getRuleSetDetail ===> uuid: \(uuid)")
        _ = Alamofire.request(Path.ruleSet(uuid).url, method: .get, parameters: nil, encoding: URLEncoding.default).responseObject(completionHandler: callback)
    }

    static func updateRuleSetListDetail(_ uuids: [String], callback: @escaping  (Alamofire.DataResponse<[RuleSet]>) -> Void) {
        DDLogVerbose("API.updateRuleSetListDetail ===> uuids: \(uuids)")
        _ = Alamofire.request(Path.ruleSetListDetail().url, method: .post, parameters: ["uuids": uuids], encoding: JSONEncoding.default).responseArray(completionHandler: callback)
    }

}

extension RuleSet: Mappable {

    public convenience init?(map: Map) {
        self.init()
        guard let rulesJSON = map.JSON["rules"] as? [AnyObject] else {
            return
        }
        var rules: [Rule] = []
        if let parsedObject = Mapper<Rule>().mapArray(JSONArray: rulesJSON as! [[String : Any]]){
            rules.append(contentsOf: parsedObject)
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

    static func addRemoteObject(_ ruleset: RuleSet, update: Bool = true) throws {
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

    static func addRemoteArray(_ rulesets: [RuleSet], update: Bool = true) throws {
        for ruleset in rulesets {
            try addRemoteObject(ruleset, update: update)
        }
    }

}

extension Rule: Mappable {

    public convenience init?(map: Map) {
        guard let pattern = map.JSON["pattern"] as? String else {
            return nil
        }
        guard let actionStr = map.JSON["action"] as? String, let action = RuleAction(rawValue: actionStr) else {
            return nil
        }
        guard let typeStr = map.JSON["type"] as? String, let type = RuleType(rawValue: typeStr) else {
            return nil
        }
        self.init(type: type, action: action, value: pattern)
    }

    // Mappable
    public func mapping(map: Map) {
    }
}



struct DateTransform: TransformType {

    func transformFromJSON(_ value: Any?) -> Double? {
        guard let dateStr = value as? String else {
            return Date().timeIntervalSince1970
        }
        return waDateFormatter().date(from: dateStr)?.timeIntervalSince1970
    }

    func transformToJSON(_ value: Double?) -> AnyObject? {
        guard let v = value else {
            return nil
        }
        let date = Date(timeIntervalSince1970: v)
        return waDateFormatter().string(from: date) as AnyObject?
    }

}

extension Alamofire.DataRequest {

    public static func ObjectMapperSerializer<T: Mappable>(_ keyPath: String?, mapToObject object: T? = nil) -> DataResponseSerializer<T> {
        return DataResponseSerializer { request, response, data, error in
            DDLogVerbose("Alamofire response ===> request: \(request.debugDescription), response: \(response.debugDescription)")
            guard error == nil else {
                logError(error! as NSError, request: request, response: response)
                return .failure(error!)
            }

            guard let _ = data else {
                let failureReason = "Data could not be serialized. Input data was nil."
                //let error = Alamofire.Error.errorWithCode(.dataSerializationFailed, failureReason: failureReason)
                let userInfo = [NSLocalizedFailureReasonErrorKey: failureReason]
                let error = NSError(domain: Bundle.main.bundleIdentifier!, code: 9999, userInfo: userInfo)
                logError(error, request: request, response: response)
                return .failure(error)
            }

            let result = Alamofire.Request.serializeResponseJSON(options: .allowFragments, response: response, data: data, error: error)

            if let errorMessage = (result.value as AnyObject).value(forKeyPath: "error_message") as? String {
                //let error = Alamofire.Error.errorWithCode(.statusCodeValidationFailed, failureReason: errorMessage)
                let userInfo = [NSLocalizedFailureReasonErrorKey: errorMessage]
                let error = NSError(domain: Bundle.main.bundleIdentifier!, code: 9999, userInfo: userInfo)
                logError(error, request: request, response: response)
                return .failure(error)
            }

            var JSONToMap: AnyObject?
            if let keyPath = keyPath, keyPath.isEmpty == false {
                //JSONToMap = (result.value? as AnyObject).value(forKeyPath: keyPath)
                JSONToMap = nil
            } else {
                JSONToMap = result.value as AnyObject?
            }

            if let object = object {
                _ = Mapper<T>().map(JSON: JSONToMap as! [String : Any], toObject: object)
                return .success(object)
            } else if let parsedObject = Mapper<T>().map(JSON: JSONToMap as! [String : Any]){
                return .success(parsedObject)
            }

            let failureReason = "ObjectMapper failed to serialize response"
            //let error = Alamofire.Error.errorWithCode(.dataSerializationFailed, failureReason: failureReason)
            let userInfo = [NSLocalizedFailureReasonErrorKey: failureReason]
            let error = NSError(domain: Bundle.main.bundleIdentifier!, code: 9999, userInfo: userInfo)
            logError(error, request: request, response: response)
            return .failure(error)
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

    public func responseObject<T: Mappable>(_ queue: DispatchQueue? = nil, keyPath: String? = nil, mapToObject object: T? = nil, completionHandler: @escaping (DataResponse<T>) -> Void) -> Self {
        return response(queue: queue, responseSerializer: Alamofire.DataRequest.ObjectMapperSerializer(keyPath, mapToObject: object), completionHandler: completionHandler)
    }

    public static func ObjectMapperArraySerializer<T: Mappable>(_ keyPath: String?) -> DataResponseSerializer<[T]> {
        return DataResponseSerializer { request, response, data, error in
            DDLogVerbose("Alamofire response ===> request: \(request.debugDescription), response: \(response.debugDescription)")
            guard error == nil else {
                logError(error! as NSError, request: request, response: response)
                return .failure(error!)
            }

            guard let _ = data else {
                let failureReason = "Data could not be serialized. Input data was nil."
                //let error = Alamofire.Error.errorWithCode(.dataSerializationFailed, failureReason: failureReason)
                let userInfo = [NSLocalizedFailureReasonErrorKey: failureReason]
                let error = NSError(domain: Bundle.main.bundleIdentifier!, code: 9999, userInfo: userInfo)
                logError(error, request: request, response: response)
                return .failure(error)
            }

            let JSONResponseSerializer = Alamofire.DataRequest.jsonResponseSerializer(options: .allowFragments)
            let result = JSONResponseSerializer.serializeResponse(request, response, data, error)

            if let errorMessage = (result.value as AnyObject).value(forKeyPath: "error_message") as? String {
                //let error = Alamofire.Error.errorWithCode(.statusCodeValidationFailed, failureReason: errorMessage)
                let userInfo = [NSLocalizedFailureReasonErrorKey: errorMessage]
                let error = NSError(domain: Bundle.main.bundleIdentifier!, code: 9999, userInfo: userInfo)
                logError(error, request: request, response: response)
                return .failure(error)
            }

            let JSONToMap: AnyObject?
            if let keyPath = keyPath, keyPath.isEmpty == false {
                //JSONToMap = (result.value? as AnyObject).value(forKeyPath: keyPath)
                JSONToMap = nil
            } else {
                JSONToMap = result.value as AnyObject?
            }

            if let parsedObject = Mapper<T>().mapArray(JSONArray: JSONToMap as! [[String : Any]]){
                return .success(parsedObject)
            }

            let failureReason = "ObjectMapper failed to serialize response."
            //let error = Alamofire.Error.errorWithCode(.dataSerializationFailed, failureReason: failureReason)
            let userInfo = [NSLocalizedFailureReasonErrorKey: failureReason]
            let error = NSError(domain: Bundle.main.bundleIdentifier!, code: 9999, userInfo: userInfo)
            logError(error, request: request, response: response)
            return .failure(error)
        }
    }

    /**
     Adds a handler to be called once the request has finished.

     - parameter queue: The queue on which the completion handler is dispatched.
     - parameter keyPath: The key path where object mapping should be performed
     - parameter completionHandler: A closure to be executed once the request has finished and the data has been mapped by ObjectMapper.

     - returns: The request.
     */
    public func responseArray<T: Mappable>(_ queue: DispatchQueue? = nil, keyPath: String? = nil, completionHandler: @escaping (DataResponse<[T]>) -> Void) -> Self {
        return response(queue: queue, responseSerializer: Alamofire.DataRequest.ObjectMapperArraySerializer(keyPath), completionHandler: completionHandler)
    }

    fileprivate static func logError(_ error: NSError, request: URLRequest?, response: URLResponse?) {
        DDLogError("ObjectMapperSerializer failure: \(error), request: \(request?.debugDescription), response: \(response.debugDescription)")
    }
}
