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
    case CODE_200 = 200
    case CODE_201 = 201
    case CODE_202 = 202
    case CODE_203 = 203
    case CODE_204 = 204
    case CODE_205 = 205
    case CODE_206 = 206
    case CODE_301 = 301
    case CODE_302 = 302
    case CODE_303 = 303
    case CODE_304 = 304
    case CODE_305 = 305
    case CODE_306 = 306
    case CODE_307 = 307
    case CODE_400 = 400
    case CODE_401 = 401
    case CODE_402 = 402
    case CODE_403 = 403
    case CODE_404 = 404
    case CODE_405 = 405
    case CODE_406 = 406
    case CODE_407 = 407
    case CODE_408 = 408
    case CODE_409 = 409
    case CODE_410 = 410
    case CODE_411 = 411
    case CODE_412 = 412
    case CODE_413 = 413
    case CODE_414 = 414
    case CODE_415 = 415
    case CODE_416 = 416
    case CODE_417 = 417
    case CODE_500 = 500
    case CODE_501 = 501
    case CODE_502 = 502
    case CODE_503 = 503
    case CODE_504 = 504
    case CODE_505 = 505

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
            return UIColor.blackColor()
        }
    }
    
    var description: String {
        return "\(rawValue)"
    }
}

enum RequestEventType: Int {
    case Init = 0
    case DNS
    case Remote
    case Open
    case Closed
}

enum RequestRouting: Int {
    case None = 0
    case Direct 
    case Proxy
    case Reject
}

enum RequestTimeStage: Int {
    case INIT = 0
    case CLOSED
    case URL_RULE_MATCH_START
    case URL_RULE_MATCH_END
    case IP_RULE_MATCH_START
    case IP_RULE_MATCH_END
    case DNS_IP_RULE_MATCH_START
    case DNS_IP_RULE_MATCH_END
    case DNS_START
    case DNS_FAIL
    case DNS_END
    case REMOTE_START
    case REMOTE_CONNECTED
    case GLOBAL_MODE
    case NON_GLOBAL_MODE
    case PROXY_DNS_START
    case PROXY_DNS_FAIL
    case PROXY_DNS_END
    case PROXY_START
    case PROXY_CONNECTED
    case Count
}

extension RequestTimeStage: CustomStringConvertible {

    var description: String {
        switch self {
        case .INIT:
            return "Request".localized()
        case .CLOSED:
            return "Request".localized()
        case .URL_RULE_MATCH_START:
            return "URL Rules Match".localized()
        case .URL_RULE_MATCH_END:
            return "URL Rules Match".localized()
        case .IP_RULE_MATCH_START:
            return "IP Rules Match".localized()
        case .IP_RULE_MATCH_END:
            return "IP Rules Match".localized()
        case .DNS_IP_RULE_MATCH_START:
            return "Check DNS Pollution".localized()
        case .DNS_IP_RULE_MATCH_END:
            return "Check DNS Pollution".localized()
        case .DNS_START:
            return "DNS Query".localized()
        case .DNS_FAIL:
            return "DNS Query".localized()
        case .DNS_END:
            return "DNS Query".localized()
        case .REMOTE_START:
            return "Remote Connection".localized()
        case .REMOTE_CONNECTED:
            return "Remote Connection".localized()
        case .GLOBAL_MODE:
            return "Default Route Match".localized()
        case .NON_GLOBAL_MODE:
            return "Default Route Match".localized()
        case .PROXY_DNS_START:
            return "Proxy DNS Query".localized()
        case .PROXY_DNS_FAIL:
            return "Proxy DNS Query".localized()
        case .PROXY_DNS_END:
            return "Proxy DNS Query".localized()
        case .PROXY_START:
            return "Proxy Connection".localized()
        case .PROXY_CONNECTED:
            return "Proxy Connection".localized()
        default:
            return ""
        }
    }

}

enum ForwardStage: Int {
    case NONE = 0
    case URL
    case IP
    case DNS_POLLUTION
    case DNS_FAILURE
}

struct RequestEvent {
    let request: Request
    let stage: RequestTimeStage
    let timestamp: NSTimeInterval
    var duration: NSTimeInterval = -1
    
    init(request: Request, stage: RequestTimeStage, timestamp: NSTimeInterval) {
        self.request = request
        self.stage = stage
        self.timestamp = timestamp
    }

    var contentDescription: String? {
        switch stage {
        case .INIT:
            return "\(request.method.description) \(request.url)"
        case .CLOSED:
            return "Request Finished".localized()
        case .URL_RULE_MATCH_START:
            return "Start URL Rule Match".localized()
        case .URL_RULE_MATCH_END:
            return request.forwardStage == .URL ? request.rule : "No Match".localized()
        case .IP_RULE_MATCH_START:
            return "Start IP Rules Match".localized()
        case .IP_RULE_MATCH_END:
            return request.forwardStage == .IP ? request.rule : "No Match".localized()
        case .DNS_IP_RULE_MATCH_START:
            return "DNS Pollution".localized()
        case .DNS_IP_RULE_MATCH_END:
            return request.forwardStage == .DNS_POLLUTION ? request.rule : "No Match".localized()
        case .DNS_START:
            return "Start DNS Query".localized()
        case .DNS_FAIL:
            return request.forwardStage == .DNS_FAILURE ? "Fail. (Try Proxy DNS Resolution)".localized() : "Fail".localized()
        case .DNS_END:
            return request.ip
        case .REMOTE_START:
            return "Start Remote Connection".localized()
        case .REMOTE_CONNECTED:
            return "Remote Connection Established".localized()
        case .GLOBAL_MODE:
            return "Fallback To PROXY".localized()
        case .NON_GLOBAL_MODE:
            return "Fallback To DIRECT".localized()
        case .PROXY_DNS_START:
            return "Start Proxy DNS Query".localized()
        case .PROXY_DNS_FAIL:
            return "Fail".localized()
        case .PROXY_DNS_END:
            return request.ip
        case .PROXY_START:
            return "Start Proxy Connection".localized()
        case .PROXY_CONNECTED:
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

    static let excluededStage: [RequestTimeStage] = [.PROXY_DNS_START, .PROXY_DNS_FAIL, .PROXY_DNS_END, .IP_RULE_MATCH_START, .URL_RULE_MATCH_START, .DNS_IP_RULE_MATCH_START]
    
    var events: [RequestEvent] = []
    var url: String
    var method: HTTPMethod = .GET
    var ip: String?
    var rule: String?
    var version: String?
    var responseCode: HTTPResponseCode?
    var headers: String?
    var globalMode: Bool = false
    var routing: RequestRouting = .Direct
    var forwardStage: ForwardStage = .NONE
    
    init?(dict: [String: AnyObject]) {
        guard let url = dict["url"] as? String, m = dict["method"] as? String, method = HTTPMethod(rawValue: m) else {
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
        if let c = dict["responseCode"] as? Int, code = HTTPResponseCode(rawValue: c) {
            self.responseCode = code
        }
        self.globalMode = dict["global"] as? Bool ?? false
        if let c = dict["routing"] as? Int, r = RequestRouting(rawValue: c) {
            self.routing = r
        }
        if let c = dict["forward_stage"] as? Int, r = ForwardStage(rawValue: c) {
            self.forwardStage = r
        }

        // Events
        var unnormalizedEvents: [RequestEvent] = []
        for i in 0..<RequestTimeStage.Count.rawValue {
            if let ts = dict["time\(i)"] as? Double, stage = RequestTimeStage(rawValue: i) {
                guard ts > 0 else {
                    continue
                }
                if let _ = Request.excluededStage.indexOf(stage) {
                    continue
                }
                let event = RequestEvent(request: self, stage: stage, timestamp: ts)
                unnormalizedEvents.append(event)
            }
        }
        unnormalizedEvents.sortInPlace { (event1, event2) -> Bool in
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
