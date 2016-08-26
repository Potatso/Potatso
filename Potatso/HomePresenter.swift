//
//  HomePresenter.swift
//  Potatso
//
//  Created by LEI on 6/22/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import Foundation

protocol HomePresenterProtocol: class {
    func handleRefreshUI()
}

class HomePresenter: NSObject {

    var vc: UIViewController!

    var group: ConfigurationGroup {
        return CurrentGroupManager.shared.group
    }

    var proxy: Proxy? {
        return group.proxies.first
    }

    weak var delegate: HomePresenterProtocol?

    override init() {
        super.init()
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(onVPNStatusChanged), name: kProxyServiceVPNStatusNotification, object: nil)
        CurrentGroupManager.shared.onChange = { group in
            self.delegate?.handleRefreshUI()
        }
    }

    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }

    func bindToVC(vc: UIViewController) {
        self.vc = vc
    }

    // MARK: - Actions

    func switchVPN() {
        VPN.switchVPN(group) { [unowned self] (error) in
            if let error = error {
                Alert.show(self.vc, message: "\("Fail to switch VPN.".localized()) (\(error))")
            }
        }
    }

    func chooseProxy() {
        let chooseVC = ProxyListViewController(allowNone: true) { [unowned self] proxy in
            do {
                try ConfigurationGroup.changeProxy(forGroupId: self.group.uuid, proxyId: proxy?.uuid)
                self.delegate?.handleRefreshUI()
            }catch {
                self.vc.showTextHUD("\("Fail to change proxy".localized()): \((error as NSError).localizedDescription)", dismissAfterDelay: 1.5)
            }
        }
        vc.navigationController?.pushViewController(chooseVC, animated: true)
    }

    func chooseConfigGroups() {
        ConfigGroupChooseManager.shared.show()
    }

    func showAddConfigGroup() {
        var urlTextField: UITextField?
        let alert = UIAlertController(title: "Add Config Group".localized(), message: nil, preferredStyle: .Alert)
        alert.addTextFieldWithConfigurationHandler { (textField) in
            textField.placeholder = "Name".localized()
            urlTextField = textField
        }
        alert.addAction(UIAlertAction(title: "OK".localized(), style: .Default, handler: { (action) in
            if let input = urlTextField?.text {
                do {
                    try self.addEmptyConfigGroup(input)
                }catch{
                    Alert.show(self.vc, message: "\("Failed to add config group".localized()): \(error)")
                }
            }
        }))
        alert.addAction(UIAlertAction(title: "CANCEL".localized(), style: .Cancel, handler: nil))
        vc.presentViewController(alert, animated: true, completion: nil)
    }

    func addEmptyConfigGroup(name: String) throws {
        let trimmedName = name.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
        if trimmedName.characters.count == 0 {
            throw "Name can't be empty".localized()
        }
        let group = ConfigurationGroup()
        group.name = trimmedName
        try DBUtils.add(group)
        CurrentGroupManager.shared.setConfigGroupId(group.uuid)
    }

    func addRuleSet() {
        let destVC: UIViewController
        if defaultRealm.objects(RuleSet).count == 0 {
            destVC = RuleSetConfigurationViewController() { [unowned self] ruleSet in
                self.appendRuleSet(ruleSet)
            }
        }else {
            destVC = RuleSetListViewController { [unowned self] ruleSet in
                self.appendRuleSet(ruleSet)
            }
        }
        vc.navigationController?.pushViewController(destVC, animated: true)
    }

    func appendRuleSet(ruleSet: RuleSet?) {
        guard let ruleSet = ruleSet where !group.ruleSets.contains(ruleSet) else {
            return
        }
        do {
            try ConfigurationGroup.appendRuleSet(forGroupId: group.uuid, rulesetId: ruleSet.uuid)
            self.delegate?.handleRefreshUI()
        }catch {
            self.vc.showTextHUD("\("Fail to add ruleset".localized()): \((error as NSError).localizedDescription)", dismissAfterDelay: 1.5)
        }
    }

    func updateDNS(dnsString: String) {
        var dns: String = ""
        let trimmedDNSString = dnsString.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
        if trimmedDNSString.characters.count > 0 {
            let dnsArray = dnsString.componentsSeparatedByString(",").map({ $0.componentsSeparatedByString("，") }).flatMap({ $0 }).map({ $0.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())}).filter({ $0.characters.count > 0 })
            let ipRegex = "^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$";
            guard let regex = try? Regex(ipRegex) else {
                fatalError()
            }
            let valids = dnsArray.map({ regex.test($0) })
            let valid = valids.reduce(true, combine: { $0 && $1 })
            if !valid {
                dns = ""
                Alert.show(self.vc, title: "Invalid DNS".localized(), message: "DNS should be valid ip addresses (separated by commas if multiple). e.g.: 8.8.8.8,8.8.4.4".localized())
            }else {
                dns = dnsArray.joinWithSeparator(",")
            }
        }
        do {
            try ConfigurationGroup.changeDNS(forGroupId: group.uuid, dns: dns)
        }catch {
            self.vc.showTextHUD("\("Fail to change dns".localized()): \((error as NSError).localizedDescription)", dismissAfterDelay: 1.5)
        }
    }

    func onVPNStatusChanged() {
        self.delegate?.handleRefreshUI()
    }

    func changeGroupName() {
        var urlTextField: UITextField?
        let alert = UIAlertController(title: "Change Name".localized(), message: nil, preferredStyle: .Alert)
        alert.addTextFieldWithConfigurationHandler { (textField) in
            textField.placeholder = "Input New Name".localized()
            urlTextField = textField
        }
        alert.addAction(UIAlertAction(title: "OK".localized(), style: .Default, handler: { [unowned self] (action) in
            if let newName = urlTextField?.text {
                do {
                    try ConfigurationGroup.changeName(forGroupId: self.group.uuid, name: newName)
                }catch {
                    Alert.show(self.vc, title: "Failed to change name", message: "\(error)")
                }
                self.delegate?.handleRefreshUI()
            }
        }))
        alert.addAction(UIAlertAction(title: "CANCEL".localized(), style: .Cancel, handler: nil))
        vc.presentViewController(alert, animated: true, completion: nil)
    }

}

class CurrentGroupManager {

    static let shared = CurrentGroupManager()

    private init() {
        _groupUUID = Manager.sharedManager.defaultConfigGroup.uuid
    }

    var onChange: (ConfigurationGroup? -> Void)?

    private var _groupUUID: String {
        didSet(o) {
            self.onChange?(group)
        }
    }

    var group: ConfigurationGroup {
        if let group = DBUtils.get(_groupUUID, type: ConfigurationGroup.self, filter: "deleted = false") {
            return group
        } else {
            let defaultGroup = Manager.sharedManager.defaultConfigGroup
            setConfigGroupId(defaultGroup.uuid)
            return defaultGroup
        }
    }

    func setConfigGroupId(id: String) {
        if let _ = DBUtils.get(id, type: ConfigurationGroup.self, filter: "deleted = false") {
            _groupUUID = id
        } else {
            _groupUUID = Manager.sharedManager.defaultConfigGroup.uuid
        }
    }
    
}