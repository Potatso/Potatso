//
//  Manager.swift
//  Potatso
//
//  Created by LEI on 4/7/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import PotatsoBase
import PotatsoModel
import RealmSwift
import KissXML
import NetworkExtension
import ICSMainFramework
import MMWormhole

public enum ManagerError: ErrorType {
    case InvalidProvider
    case VPNStartFail
}

public enum VPNStatus {
    case Off
    case Connecting
    case On
    case Disconnecting
}


public let kDefaultGroupIdentifier = "defaultGroup"
public let kDefaultGroupName = "defaultGroupName"
private let statusIdentifier = "status"
public let kProxyServiceVPNStatusNotification = "kProxyServiceVPNStatusNotification"

public class Manager {
    
    public static let sharedManager = Manager()
    
    public private(set) var vpnStatus = VPNStatus.Off {
        didSet {
            NSNotificationCenter.defaultCenter().postNotificationName(kProxyServiceVPNStatusNotification, object: nil)
        }
    }
    
    public let wormhole = MMWormhole(applicationGroupIdentifier: sharedGroupIdentifier, optionalDirectory: "wormhole")

    var observerAdded: Bool = false
    
    public var defaultConfigGroup: ConfigurationGroup {
        return getDefaultConfigGroup()
    }

    private init() {
        loadProviderManager { (manager) -> Void in
            if let manager = manager {
                self.updateVPNStatus(manager)
            }
        }
        addVPNStatusObserver()
    }
    
    func addVPNStatusObserver() {
        guard !observerAdded else{
            return
        }
        loadProviderManager { [unowned self] (manager) -> Void in
            if let manager = manager {
                self.observerAdded = true
                NSNotificationCenter.defaultCenter().addObserverForName(NEVPNStatusDidChangeNotification, object: manager.connection, queue: NSOperationQueue.mainQueue(), usingBlock: { [unowned self] (notification) -> Void in
                    self.updateVPNStatus(manager)
                })
            }
        }
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    func updateVPNStatus(manager: NEVPNManager) {
        switch manager.connection.status {
        case .Connected:
            self.vpnStatus = .On
        case .Connecting, .Reasserting:
            self.vpnStatus = .Connecting
        case .Disconnecting:
            self.vpnStatus = .Disconnecting
        case .Disconnected, .Invalid:
            self.vpnStatus = .Off
        }
    }

    public func switchVPN(completion: ((NETunnelProviderManager?, ErrorType?) -> Void)? = nil) {
        loadProviderManager { [unowned self] (manager) in
            if let manager = manager {
                self.updateVPNStatus(manager)
            }
            let current = self.vpnStatus
            guard current != .Connecting && current != .Disconnecting else {
                return
            }
            if current == .Off {
                self.startVPN { (manager, error) -> Void in
                    completion?(manager, error)
                }
            }else {
                self.stopVPN()
                completion?(nil, nil)
            }

        }
    }
    
    public func switchVPNFromTodayWidget(context: NSExtensionContext) {
        if let url = NSURL(string: "potatso://switch") {
            context.openURL(url, completionHandler: nil)
        }
    }
    
    public func setup() {
        setupDefaultReaml()
        do {
            try copyGEOIPData()
        }catch{
            print("copyGEOIPData fail")
        }
        do {
            try copyTemplateData()
        }catch{
            print("copyTemplateData fail")
        }
    }

    func copyGEOIPData() throws {
        guard let fromURL = NSBundle.mainBundle().URLForResource("GeoLite2-Country", withExtension: "mmdb") else {
            return
        }
        let toURL = Potatso.sharedUrl().URLByAppendingPathComponent("GeoLite2-Country.mmdb")
        if NSFileManager.defaultManager().fileExistsAtPath(fromURL.path!) {
            if NSFileManager.defaultManager().fileExistsAtPath(toURL.path!) {
                try NSFileManager.defaultManager().removeItemAtURL(toURL)
            }
            try NSFileManager.defaultManager().copyItemAtURL(fromURL, toURL: toURL)
        }
    }

    func copyTemplateData() throws {
        guard let bundleURL = NSBundle.mainBundle().URLForResource("template", withExtension: "bundle") else {
            return
        }
        let fm = NSFileManager.defaultManager()
        let toDirectoryURL = Potatso.sharedUrl().URLByAppendingPathComponent("httptemplate")
        if !fm.fileExistsAtPath(toDirectoryURL.path!) {
            try fm.createDirectoryAtURL(toDirectoryURL, withIntermediateDirectories: true, attributes: nil)
        }
        for file in try fm.contentsOfDirectoryAtPath(bundleURL.path!) {
            let destURL = toDirectoryURL.URLByAppendingPathComponent(file)
            let dataURL = bundleURL.URLByAppendingPathComponent(file)
            if NSFileManager.defaultManager().fileExistsAtPath(dataURL.path!) {
                if NSFileManager.defaultManager().fileExistsAtPath(destURL.path!) {
                    try NSFileManager.defaultManager().removeItemAtURL(destURL)
                }
                try fm.copyItemAtURL(dataURL, toURL: destURL)
            }
        }
    }

    private func getDefaultConfigGroup() -> ConfigurationGroup {
        if let groupUUID = Potatso.sharedUserDefaults().stringForKey(kDefaultGroupIdentifier), group = DBUtils.get(groupUUID, type: ConfigurationGroup.self) where !group.deleted {
            return group
        }else {
            var group: ConfigurationGroup
            if let g = DBUtils.allNotDeleted(ConfigurationGroup.self, sorted: "createAt").first {
                group = g
            }else {
                group = ConfigurationGroup()
                group.name = "Default".localized()
                do {
                    try DBUtils.add(group)
                }catch {
                    fatalError("Fail to generate default group")
                }
            }
            let uuid = group.uuid
            let name = group.name
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), { 
                self.setDefaultConfigGroup(uuid, name: name)
            })
            return group
        }
    }
    
    public func setDefaultConfigGroup(id: String, name: String) {
        do {
            try regenerateConfigFiles()
        } catch {

        }
        Potatso.sharedUserDefaults().setObject(id, forKey: kDefaultGroupIdentifier)
        Potatso.sharedUserDefaults().setObject(name, forKey: kDefaultGroupName)
        Potatso.sharedUserDefaults().synchronize()
    }
    
    public func regenerateConfigFiles() throws {
        try generateGeneralConfig()
        try generateSocksConfig()
        try generateShadowsocksConfig()
        try generateHttpProxyConfig()
    }

}

extension ConfigurationGroup {

    public var isDefault: Bool {
        let defaultUUID = Manager.sharedManager.defaultConfigGroup.uuid
        let isDefault = defaultUUID == uuid
        return isDefault
    }
    
}

extension Manager {
    
    var upstreamProxy: Proxy? {
        return defaultConfigGroup.proxies.first
    }
    
    var defaultToProxy: Bool {
        return upstreamProxy != nil && defaultConfigGroup.defaultToProxy
    }
    
    func generateGeneralConfig() throws {
        let confURL = Potatso.sharedGeneralConfUrl()
        let json: NSDictionary = ["dns": defaultConfigGroup.dns ?? ""]
        try json.jsonString()?.writeToURL(confURL, atomically: true, encoding: NSUTF8StringEncoding)
    }
    
    func generateSocksConfig() throws {
        let root = NSXMLElement.elementWithName("antinatconfig") as! NSXMLElement
        let interface = NSXMLElement.elementWithName("interface", children: nil, attributes: [NSXMLNode.attributeWithName("value", stringValue: "127.0.0.1") as! DDXMLNode]) as! NSXMLElement
        root.addChild(interface)
        
        let port = NSXMLElement.elementWithName("port", children: nil, attributes: [NSXMLNode.attributeWithName("value", stringValue: "0") as! DDXMLNode])  as! NSXMLElement
        root.addChild(port)
        
        let maxbindwait = NSXMLElement.elementWithName("maxbindwait", children: nil, attributes: [NSXMLNode.attributeWithName("value", stringValue: "10") as! DDXMLNode]) as! NSXMLElement
        root.addChild(maxbindwait)
        
        
        let authchoice = NSXMLElement.elementWithName("authchoice") as! NSXMLElement
        let select = NSXMLElement.elementWithName("select", children: nil, attributes: [NSXMLNode.attributeWithName("mechanism", stringValue: "anonymous") as! DDXMLNode])  as! NSXMLElement
        
        authchoice.addChild(select)
        root.addChild(authchoice)
        
        let filter = NSXMLElement.elementWithName("filter") as! NSXMLElement
        if let upstreamProxy = upstreamProxy {
            let chain = NSXMLElement.elementWithName("chain", children: nil, attributes: [NSXMLNode.attributeWithName("name", stringValue: upstreamProxy.name) as! DDXMLNode]) as! NSXMLElement
            switch upstreamProxy.type {
            case .Shadowsocks:
                let uriString = "socks5://127.0.0.1:${ssport}"
                let uri = NSXMLElement.elementWithName("uri", children: nil, attributes: [NSXMLNode.attributeWithName("value", stringValue: uriString) as! DDXMLNode]) as! NSXMLElement
                chain.addChild(uri)
                let authscheme = NSXMLElement.elementWithName("authscheme", children: nil, attributes: [NSXMLNode.attributeWithName("value", stringValue: "anonymous") as! DDXMLNode]) as! NSXMLElement
                chain.addChild(authscheme)
            default:
                break
            }
            root.addChild(chain)
        }
        
        let accept = NSXMLElement.elementWithName("accept") as! NSXMLElement
        filter.addChild(accept)
        root.addChild(filter)
        
        let socksConf = root.XMLString
        try socksConf.writeToURL(Potatso.sharedSocksConfUrl(), atomically: true, encoding: NSUTF8StringEncoding)
    }
    
    func generateShadowsocksConfig() throws {
        let confURL = Potatso.sharedProxyConfUrl()
        var content = ""
        if let upstreamProxy = upstreamProxy where upstreamProxy.type == .Shadowsocks || upstreamProxy.type == .ShadowsocksR {
            content = ["host": upstreamProxy.host, "port": upstreamProxy.port, "password": upstreamProxy.password ?? "", "authscheme": upstreamProxy.authscheme ?? "", "ota": upstreamProxy.ota, "protocol": upstreamProxy.ssrProtocol ?? "", "obfs": upstreamProxy.ssrObfs ?? "", "obfs_param": upstreamProxy.ssrObfsParam ?? ""].jsonString() ?? ""
        }
        try content.writeToURL(confURL, atomically: true, encoding: NSUTF8StringEncoding)
    }
    
    func generateHttpProxyConfig() throws {
        let rootUrl = Potatso.sharedUrl()
        let confDirUrl = rootUrl.URLByAppendingPathComponent("httpconf")
        let templateDirPath = rootUrl.URLByAppendingPathComponent("httptemplate").path!
        let temporaryDirPath = rootUrl.URLByAppendingPathComponent("httptemporary").path!
        let logDir = rootUrl.URLByAppendingPathComponent("log").path!
        let maxminddbPath = Potatso.sharedUrl().URLByAppendingPathComponent("GeoLite2-Country.mmdb").path!
        let userActionUrl = confDirUrl.URLByAppendingPathComponent("potatso.action")
        for p in [confDirUrl.path!, templateDirPath, temporaryDirPath, logDir] {
            if !NSFileManager.defaultManager().fileExistsAtPath(p) {
                _ = try? NSFileManager.defaultManager().createDirectoryAtPath(p, withIntermediateDirectories: true, attributes: nil)
            }
        }
        var mainConf: [String: AnyObject] = [:]
        if let path = NSBundle.mainBundle().pathForResource("proxy", ofType: "plist"), defaultConf = NSDictionary(contentsOfFile: path) as? [String: AnyObject] {
            mainConf = defaultConf
        }
        mainConf["confdir"] = confDirUrl.path!
        mainConf["templdir"] = templateDirPath
        mainConf["logdir"] = logDir
        mainConf["mmdbpath"] = maxminddbPath
        mainConf["global-mode"] = defaultToProxy
//        mainConf["debug"] = 1024+65536+1
//        mainConf["debug"] = 131071
        mainConf["debug"] = mainConf["debug"] as! Int + 4096
        mainConf["actionsfile"] = userActionUrl.path!

        let mainContent = mainConf.map { "\($0) \($1)"}.joinWithSeparator("\n")
        try mainContent.writeToURL(Potatso.sharedHttpProxyConfUrl(), atomically: true, encoding: NSUTF8StringEncoding)

        var actionContent: [String] = []
        var forwardURLRules: [String] = []
        var forwardIPRules: [String] = []
        var forwardGEOIPRules: [String] = []
        let rules = defaultConfigGroup.ruleSets.flatMap({ $0.rules })
        for rule in rules {
            
            switch rule.type {
            case .GeoIP:
                forwardGEOIPRules.append(rule.description)
            case .IPCIDR:
                forwardIPRules.append(rule.description)
            default:
                forwardURLRules.append(rule.description)
            }
        }

        if forwardURLRules.count > 0 {
            actionContent.append("{+forward-rule}")
            actionContent.appendContentsOf(forwardURLRules)
        }

        if forwardIPRules.count > 0 {
            actionContent.append("{+forward-rule}")
            actionContent.appendContentsOf(forwardIPRules)
        }

        if forwardGEOIPRules.count > 0 {
            actionContent.append("{+forward-rule}")
            actionContent.appendContentsOf(forwardGEOIPRules)
        }

        // DNS pollution
        actionContent.append("{+forward-rule}")
        actionContent.appendContentsOf(Pollution.dnsList.map({ "DNS-IP-CIDR, \($0)/32, PROXY" }))

        let userActionString = actionContent.joinWithSeparator("\n")
        try userActionString.writeToFile(userActionUrl.path!, atomically: true, encoding: NSUTF8StringEncoding)
    }

}

extension Manager {
    
    public func isVPNStarted(complete: (Bool, NETunnelProviderManager?) -> Void) {
        loadProviderManager { (manager) -> Void in
            if let manager = manager {
                complete(manager.connection.status == .Connected, manager)
            }else{
                complete(false, nil)
            }
        }
    }
    
    public func startVPN(complete: ((NETunnelProviderManager?, ErrorType?) -> Void)? = nil) {
        startVPNWithOptions(nil, complete: complete)
    }
    
    private func startVPNWithOptions(options: [String : NSObject]?, complete: ((NETunnelProviderManager?, ErrorType?) -> Void)? = nil) {
        // regenerate config files
        do {
            try Manager.sharedManager.regenerateConfigFiles()
        }catch {
            complete?(nil, error)
            return
        }
        // Load provider
        loadAndCreateProviderManager { (manager, error) -> Void in
            if let error = error {
                complete?(nil, error)
            }else{
                guard let manager = manager else {
                    complete?(nil, ManagerError.InvalidProvider)
                    return
                }
                if manager.connection.status == .Disconnected || manager.connection.status == .Invalid {
                    do {
                        try manager.connection.startVPNTunnelWithOptions(options)
                        self.addVPNStatusObserver()
                        complete?(manager, nil)
                    }catch {
                        complete?(nil, error)
                    }
                }else{
                    self.addVPNStatusObserver()
                    complete?(manager, nil)
                }
            }
        }
    }
    
    public func stopVPN() {
        // Stop provider
        loadProviderManager { (manager) -> Void in
            guard let manager = manager else {
                return
            }
            manager.connection.stopVPNTunnel()
        }
    }
    
    public func postMessage() {
        loadProviderManager { (manager) -> Void in
            if let session = manager?.connection as? NETunnelProviderSession,
                message = "Hello".dataUsingEncoding(NSUTF8StringEncoding)
                where manager?.connection.status != .Invalid
            {
                do {
                    try session.sendProviderMessage(message) { response in
                        
                    }
                } catch {
                    print("Failed to send a message to the provider")
                }
            }
        }
    }
    
    private func loadAndCreateProviderManager(complete: (NETunnelProviderManager?, ErrorType?) -> Void ) {
        NETunnelProviderManager.loadAllFromPreferencesWithCompletionHandler { [unowned self] (managers, error) -> Void in
            if let managers = managers {
                let manager: NETunnelProviderManager
                if managers.count > 0 {
                    manager = managers[0]
                }else{
                    manager = self.createProviderManager()
                }
                manager.enabled = true
                manager.localizedDescription = AppEnv.appName
                manager.protocolConfiguration?.serverAddress = AppEnv.appName
                manager.onDemandEnabled = true
                let quickStartRule = NEOnDemandRuleEvaluateConnection()
                quickStartRule.connectionRules = [NEEvaluateConnectionRule(matchDomains: ["connect.potatso.com"], andAction: NEEvaluateConnectionRuleAction.ConnectIfNeeded)]
                manager.onDemandRules = [quickStartRule]
                manager.saveToPreferencesWithCompletionHandler({ (error) -> Void in
                    if let error = error {
                        complete(nil, error)
                    }else{
                        manager.loadFromPreferencesWithCompletionHandler({ (error) -> Void in
                            if let error = error {
                                complete(nil, error)
                            }else{
                                complete(manager, nil)
                            }
                        })
                    }
                })
            }else{
                complete(nil, error)
            }
        }
    }
    
    public func loadProviderManager(complete: (NETunnelProviderManager?) -> Void) {
        NETunnelProviderManager.loadAllFromPreferencesWithCompletionHandler { (managers, error) -> Void in
            if let managers = managers {
                if managers.count > 0 {
                    let manager = managers[0]
                    complete(manager)
                    return
                }
            }
            complete(nil)
        }
    }
    
    private func createProviderManager() -> NETunnelProviderManager {
        let manager = NETunnelProviderManager()
        manager.protocolConfiguration = NETunnelProviderProtocol()
        return manager
    }
}

