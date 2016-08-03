//
//  Proxy.swift
//  Potatso
//
//  Created by LEI on 4/6/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import RealmSwift

public enum ProxyType: String {
    case Shadowsocks = "SS"
    case ShadowsocksR = "SSR"
    case Https = "HTTPS"
    case Socks5 = "SOCKS5"
    case None = "NONE"
}

extension ProxyType: CustomStringConvertible {
    
    public var description: String {
        return rawValue
    }

    public var isShadowsocks: Bool {
        return self == .Shadowsocks || self == .ShadowsocksR
    }
    
}

public enum ProxyError: ErrorType {
    case InvalidType
    case InvalidName
    case InvalidHost
    case InvalidPort
    case InvalidAuthScheme
    case NameAlreadyExists
    case InvalidUri
    case InvalidPassword
}

extension ProxyError: CustomStringConvertible {
    
    public var description: String {
        switch self {
        case .InvalidType:
            return "Invalid type"
        case .InvalidName:
            return "Invalid name"
        case .InvalidHost:
            return "Invalid host"
        case .InvalidAuthScheme:
            return "Invalid encryption"
        case .InvalidUri:
            return "Invalid uri"
        case .NameAlreadyExists:
            return "Name already exists"
        case .InvalidPassword:
            return "Invalid password"
        case .InvalidPort:
            return "Invalid port"
        }
    }
    
}

public class Proxy: BaseModel {
    public dynamic var typeRaw = ProxyType.Shadowsocks.rawValue
    public dynamic var name = ""
    public dynamic var host = ""
    public dynamic var port = 0
    public dynamic var authscheme: String?  // method in SS
    public dynamic var user: String?
    public dynamic var password: String?
    public dynamic var ota: Bool = false
    public dynamic var ssrProtocol: String?
    public dynamic var ssrObfs: String?
    public dynamic var ssrObfsParam: String?

    public static let ssUriPrefix = "ss://"
    public static let ssrUriPrefix = "ssr://"

    public static let ssrSupportedProtocol = [
        "origin",
        "verify_simple",
        "auth_simple",
        "auth_sha1",
        "auth_sha1_v2"
    ]

    public static let ssrSupportedObfs = [
        "plain",
        "http_simple",
        "tls1.0_session_auth",
        "tls1.2_ticket_auth"
    ]

    public static let ssSupportedEncryption = [
        "table",
        "rc4",
        "rc4-md5",
        "aes-128-cfb",
        "aes-192-cfb",
        "aes-256-cfb",
        "bf-cfb",
        "camellia-128-cfb",
        "camellia-192-cfb",
        "camellia-256-cfb",
        "cast5-cfb",
        "des-cfb",
        "idea-cfb",
        "rc2-cfb",
        "seed-cfb",
        "salsa20",
        "chacha20",
        "chacha20-ietf"
    ]

    public func validate(inRealm realm: Realm) throws {
        guard let _ = ProxyType(rawValue: typeRaw)else {
            throw ProxyError.InvalidType
        }
        guard name.characters.count > 0 else{
            throw ProxyError.InvalidName
        }
        guard realm.objects(Proxy).filter("name = '\(name)'").first == nil else {
            throw ProxyError.NameAlreadyExists
        }
        guard host.characters.count > 0 else {
            throw ProxyError.InvalidHost
        }
        guard port > 0 && port <= Int(UINT16_MAX) else {
            throw ProxyError.InvalidPort
        }
        switch type {
        case .Shadowsocks, .ShadowsocksR:
            guard let _ = authscheme else {
                throw ProxyError.InvalidAuthScheme
            }
        default:
            break
        }
    }

}

extension Proxy {
    
    public var type: ProxyType {
        get {
            return ProxyType(rawValue: typeRaw) ?? .Shadowsocks
        }
        set(v) {
            typeRaw = v.rawValue
        }
    }
    
    public override static func indexedProperties() -> [String] {
        return ["name"]
    }
    
}

extension Proxy {
    
    public convenience init(dictionary: [String: AnyObject], inRealm realm: Realm) throws {
        self.init()
        if let uriString = dictionary["uri"] as? String {
            guard let name = dictionary["name"] as? String else{
                throw ProxyError.InvalidName
            }
            self.name = name
            if uriString.lowercaseString.hasPrefix(Proxy.ssUriPrefix) {
                // Shadowsocks
                let undecodedString = uriString.substringFromIndex(uriString.startIndex.advancedBy(Proxy.ssUriPrefix.characters.count))
                guard let proxyString = base64DecodeIfNeeded(undecodedString), _ = proxyString.rangeOfString(":")?.startIndex else {
                    throw ProxyError.InvalidUri
                }
                guard let pc1 = proxyString.rangeOfString(":")?.startIndex, pc2 = proxyString.rangeOfString(":", options: .BackwardsSearch)?.startIndex, pcm = proxyString.rangeOfString("@", options: .BackwardsSearch)?.startIndex else {
                    throw ProxyError.InvalidUri
                }
                if !(pc1 < pcm && pcm < pc2) {
                    throw ProxyError.InvalidUri
                }
                let fullAuthscheme = proxyString.lowercaseString.substringWithRange(proxyString.startIndex..<pc1)
                if let pOTA = fullAuthscheme.rangeOfString("-auth", options: .BackwardsSearch)?.startIndex {
                    self.authscheme = fullAuthscheme.substringToIndex(pOTA)
                    self.ota = true
                }else {
                    self.authscheme = fullAuthscheme
                }
                self.password = proxyString.substringWithRange(pc1.successor()..<pcm)
                self.host = proxyString.substringWithRange(pcm.successor()..<pc2)
                guard let p = Int(proxyString.substringWithRange(pc2.successor()..<proxyString.endIndex)) else {
                    throw ProxyError.InvalidPort
                }
                self.port = p
                self.type = .Shadowsocks
            }else if uriString.lowercaseString.hasPrefix(Proxy.ssrUriPrefix) {
                let undecodedString = uriString.substringFromIndex(uriString.startIndex.advancedBy(Proxy.ssrUriPrefix.characters.count))
                guard let proxyString = base64DecodeIfNeeded(undecodedString), _ = proxyString.rangeOfString(":")?.startIndex else {
                    throw ProxyError.InvalidUri
                }
                var hostString: String = proxyString
                var queryString: String = ""
                if let queryMarkIndex = proxyString.rangeOfString("?", options: .BackwardsSearch)?.startIndex {
                    hostString = proxyString.substringToIndex(queryMarkIndex)
                    queryString = proxyString.substringFromIndex(queryMarkIndex.successor())
                }
                if let hostSlashIndex = hostString.rangeOfString("/", options: .BackwardsSearch)?.startIndex {
                    hostString = hostString.substringToIndex(hostSlashIndex)
                }
                let hostComps = hostString.componentsSeparatedByString(":")
                guard hostComps.count == 6 else {
                    throw ProxyError.InvalidUri
                }
                self.host = hostComps[0]
                guard let p = Int(hostComps[1]) else {
                    throw ProxyError.InvalidPort
                }
                self.port = p
                self.ssrProtocol = hostComps[2]
                self.authscheme = hostComps[3]
                self.ssrObfs = hostComps[4]
                self.password = base64DecodeIfNeeded(hostComps[5])
                for queryComp in queryString.componentsSeparatedByString("&") {
                    let comps = queryComp.componentsSeparatedByString("=")
                    guard comps.count == 2 else {
                        continue
                    }
                    switch comps[0] {
                    case "obfsparam":
                        self.ssrObfsParam = comps[1]
                    case "remarks":
                        self.name = comps[1]
                    default:
                        continue
                    }
                }
                self.type = .ShadowsocksR
            }else {
                // Not supported yet
                throw ProxyError.InvalidUri
            }
        }else {
            guard let name = dictionary["name"] as? String else{
                throw ProxyError.InvalidName
            }
            guard let host = dictionary["host"] as? String else{
                throw ProxyError.InvalidHost
            }
            guard let typeRaw = (dictionary["type"] as? String)?.uppercaseString, type = ProxyType(rawValue: typeRaw) else{
                throw ProxyError.InvalidType
            }
            guard let portStr = (dictionary["port"] as? String), port = Int(portStr) else{
                throw ProxyError.InvalidPort
            }
            guard let encryption = dictionary["encryption"] as? String else{
                throw ProxyError.InvalidAuthScheme
            }
            guard let password = dictionary["password"] as? String else{
                throw ProxyError.InvalidPassword
            }
            self.host = host
            self.port = port
            self.password = password
            self.authscheme = encryption
            self.name = name
            self.type = type
        }
        if realm.objects(Proxy).filter("name = '\(name)'").first != nil {
            self.name = "\(name) \(Proxy.dateFormatter.stringFromDate(NSDate()))"
        }
        try validate(inRealm: realm)
    }

    private func base64DecodeIfNeeded(proxyString: String) -> String? {
        if let _ = proxyString.rangeOfString(":")?.startIndex {
            return proxyString
        }
        let base64String = proxyString.stringByReplacingOccurrencesOfString("-", withString: "+").stringByReplacingOccurrencesOfString("_", withString: "/")
        let padding = base64String.characters.count + (base64String.characters.count % 4 != 0 ? (4 - base64String.characters.count % 4) : 0)
        if let decodedData = NSData(base64EncodedString: base64String.stringByPaddingToLength(padding, withString: "=", startingAtIndex: 0), options: NSDataBase64DecodingOptions(rawValue: 0)), decodedString = NSString(data: decodedData, encoding: NSUTF8StringEncoding) {
            return decodedString as String
        }
        return nil
    }

    public class func uriIsShadowsocks(uri: String) -> Bool {
        return uri.lowercaseString.hasPrefix(Proxy.ssUriPrefix) || uri.lowercaseString.hasPrefix(Proxy.ssrUriPrefix)
    }



}

extension Proxy {

    public var uri: String {
        switch type {
        case .Shadowsocks:
            if let authscheme = authscheme, password = password {
                return "ss://\(authscheme):\(password)@\(host):\(port)"
            }
        default:
            break
        }
        return ""
    }
    public override var description: String {
        return name
    }
}

public func ==(lhs: Proxy, rhs: Proxy) -> Bool {
    return lhs.uuid == rhs.uuid
}