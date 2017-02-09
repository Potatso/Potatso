//
//  RequestModel.swift
//  Potatso
//
//  Created by LEI on 4/20/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import Foundation
import PotatsoModel
import RealmSwift
import PotatsoLibrary
import PotatsoBase

enum HTTPMethod: String {
    case GET = "GET"
    case HEAD = "HEAD"
    case CONDITIONAL_GET = "CONDITIONAL"
    case CONNECT = "CONNECT"
    case POST = "POST"
    case PUT = "PUT"
    case OPTIONS = "OPTIONS"
    case DELETE = "DELETE"
}

extension HTTPMethod: CustomStringConvertible {
    
    var description: String {
        switch self {
        case .CONNECT:
            return "HTTPS"
        default:
            return rawValue
        }
    }
}

enum HTTPResponseCode: Int {
    case code_200 = 200
    case code_201 = 201
    case code_202 = 202
    case code_203 = 203
    case code_204 = 204
    case code_205 = 205
    case code_206 = 206
    case code_301 = 301
    case code_302 = 302
    case code_303 = 303
    case code_304 = 304
    case code_305 = 305
    case code_306 = 306
    case code_307 = 307
    case code_400 = 400
    case code_401 = 401
    case code_402 = 402
    case code_403 = 403
    case code_404 = 404
    case code_405 = 405
    case code_406 = 406
    case code_407 = 407
    case code_408 = 408
    case code_409 = 409
    case code_410 = 410
    case code_411 = 411
    case code_412 = 412
    case code_413 = 413
    case code_414 = 414
    case code_415 = 415
    case code_416 = 416
    case code_417 = 417
    case code_500 = 500
    case code_501 = 501
    case code_502 = 502
    case code_503 = 503
    case code_504 = 504
    case code_505 = 505

}

extension HTTPResponseCode: CustomStringConvertible {
    
    var color: UIColor {
        switch self.rawValue {
        case 200..<300:
            return "1ABC9C".color
        case 300..<400:
            return "9B59B6".color
        case 400..<500:
            return "E74C3C".color
        case 500..<600:
            return "000000".color
        default:
            return UIColor.init(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        }
    }
    
    var description: String {
        return "\(rawValue)"
    }
}

enum RequestEventType: Int {
    case Init = 0
    case dns
    case remote
    case open
    case closed
}

enum RequestRouting: Int {
    case none = 0
    case direct 
    case proxy
    case reject
}

enum RequestTimeStage: Int {
    case INIT = 0
    case closed
    case url_RULE_MATCH_START
    case url_RULE_MATCH_END
    case ip_RULE_MATCH_START
    case ip_RULE_MATCH_END
    case dns_IP_RULE_MATCH_START
    case dns_IP_RULE_MATCH_END
    case dns_START
    case dns_FAIL
    case dns_END
    case remote_START
    case remote_CONNECTED
    case global_MODE
    case non_GLOBAL_MODE
    case proxy_DNS_START
    case proxy_DNS_FAIL
    case proxy_DNS_END
    case proxy_START
    case proxy_CONNECTED
    case count
}

extension RequestTimeStage: CustomStringConvertible {

    var description: String {
        switch self {
        case .INIT:
            return "Request".localized()
        case .closed:
            return "Request".localized()
        case .url_RULE_MATCH_START:
            return "URL Rules Match".localized()
        case .url_RULE_MATCH_END:
            return "URL Rules Match".localized()
        case .ip_RULE_MATCH_START:
            return "IP Rules Match".localized()
        case .ip_RULE_MATCH_END:
            return "IP Rules Match".localized()
        case .dns_IP_RULE_MATCH_START:
            return "Check DNS Pollution".localized()
        case .dns_IP_RULE_MATCH_END:
            return "Check DNS Pollution".localized()
        case .dns_START:
            return "DNS Query".localized()
        case .dns_FAIL:
            return "DNS Query".localized()
        case .dns_END:
            return "DNS Query".localized()
        case .remote_START:
            return "Remote Connection".localized()
        case .remote_CONNECTED:
            return "Remote Connection".localized()
        case .global_MODE:
            return "Default Route Match".localized()
        case .non_GLOBAL_MODE:
            return "Default Route Match".localized()
        case .proxy_DNS_START:
            return "Proxy DNS Query".localized()
        case .proxy_DNS_FAIL:
            return "Proxy DNS Query".localized()
        case .proxy_DNS_END:
            return "Proxy DNS Query".localized()
        case .proxy_START:
            return "Proxy Connection".localized()
        case .proxy_CONNECTED:
            return "Proxy Connection".localized()
        default:
            return ""
        }
    }

}

enum ForwardStage: Int {
    case none = 0
    case url
    case ip
    case dns_POLLUTION
    case dns_FAILURE
}

struct RequestEvent {
    let request: Request
    let stage: RequestTimeStage
    let timestamp: TimeInterval
    var duration: TimeInterval = -1
    
    init(request: Request, stage: RequestTimeStage, timestamp: TimeInterval) {
        self.request = request
        self.stage = stage
        self.timestamp = timestamp
    }

    var contentDescription: String? {
        switch stage {
        case .INIT:
            return "\(request.method.description) \(request.url)"
        case .closed:
            return "Request Finished".localized()
        case .url_RULE_MATCH_START:
            return "Start URL Rule Match".localized()
        case .url_RULE_MATCH_END:
            return request.forwardStage == .url ? request.rule : "No Match".localized()
        case .ip_RULE_MATCH_START:
            return "Start IP Rules Match".localized()
        case .ip_RULE_MATCH_END:
            return request.forwardStage == .ip ? request.rule : "No Match".localized()
        case .dns_IP_RULE_MATCH_START:
            return "DNS Pollution".localized()
        case .dns_IP_RULE_MATCH_END:
            return request.forwardStage == .dns_POLLUTION ? request.rule : "No Match".localized()
        case .dns_START:
            return "Start DNS Query".localized()
        case .dns_FAIL:
            return request.forwardStage == .dns_FAILURE ? "Fail. (Try Proxy DNS Resolution)".localized() : "Fail".localized()
        case .dns_END:
            return request.ip
        case .remote_START:
            return "Start Remote Connection".localized()
        case .remote_CONNECTED:
            return "Remote Connection Established".localized()
        case .global_MODE:
            return "Fallback To PROXY".localized()
        case .non_GLOBAL_MODE:
            return "Fallback To DIRECT".localized()
        case .proxy_DNS_START:
            return "Start Proxy DNS Query".localized()
        case .proxy_DNS_FAIL:
            return "Fail".localized()
        case .proxy_DNS_END:
            return request.ip
        case .proxy_START:
            return "Start Proxy Connection".localized()
        case .proxy_CONNECTED:
            return "Proxy Connection Established".localized()
        default:
            return ""
        }
    }

}

extension RequestEvent: Equatable {}

func ==(lhs: RequestEvent, rhs: RequestEvent) -> Bool {
    return lhs.stage == rhs.stage
}

class Request {
    
    static let statusCount = 7

    static let excluededStage: [RequestTimeStage] = [.proxy_DNS_START, .proxy_DNS_FAIL, .proxy_DNS_END, .ip_RULE_MATCH_START, .url_RULE_MATCH_START, .dns_IP_RULE_MATCH_START]
    
    var events: [RequestEvent] = []
    var url: String
    var method: HTTPMethod = .GET
    var ip: String?
    var rule: String?
    var version: String?
    var responseCode: HTTPResponseCode?
    var headers: String?
    var globalMode: Bool = false
    var routing: RequestRouting = .direct
    var forwardStage: ForwardStage = .none
    
    init?(dict: [String: AnyObject]) {
        guard let url = dict["url"] as? String, let m = dict["method"] as? String, let method = HTTPMethod(rawValue: m) else {
            return nil
        }

        self.url = url
        self.method = method
        if let v = dict["version"] as? String {
            self.version = v
        }
        self.headers = dict["headers"] as? String
        if let rule = dict["rule"] as? String {
            self.rule = rule
        }
        if let ip = dict["ip"] as? String {
            self.ip = ip
        }
        if let c = dict["responseCode"] as? Int, let code = HTTPResponseCode(rawValue: c) {
            self.responseCode = code
        }
        self.globalMode = dict["global"] as? Bool ?? false
        if let c = dict["routing"] as? Int, let r = RequestRouting(rawValue: c) {
            self.routing = r
        }
        if let c = dict["forward_stage"] as? Int, let r = ForwardStage(rawValue: c) {
            self.forwardStage = r
        }

        // Events
        var unnormalizedEvents: [RequestEvent] = []
        for i in 0..<RequestTimeStage.count.rawValue {
            if let ts = dict["time\(i)"] as? Double, let stage = RequestTimeStage(rawValue: i) {
                guard ts > 0 else {
                    continue
                }
                if let _ = Request.excluededStage.index(of: stage) {
                    continue
                }
                let event = RequestEvent(request: self, stage: stage, timestamp: ts)
                unnormalizedEvents.append(event)
            }
        }
        unnormalizedEvents.sort { (event1, event2) -> Bool in
            return event1.timestamp < event2.timestamp
        }
        var lastEvent: RequestEvent?
        for event in unnormalizedEvents {
            if let e = lastEvent {
                lastEvent?.duration = event.timestamp - e.timestamp
                events.append(lastEvent!)
            }
            lastEvent = event
        }
        if let e = lastEvent {
            events.append(e)
        }
    }
}
