//
//  RuleConfigurationViewController.swift
//  Potatso
//
//  Created by LEI on 3/9/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import UIKit
import Eureka
import PotatsoLibrary
import PotatsoModel
import RealmSwift

private let kRuleFormType = "type"
private let kRuleFormValue = "value"
private let kRuleFormAction = "action"

extension Rule {
    
    var rowDescription: (String?, String?) {
        return (action.rawValue, "\(type.rawValue)(\(value))")
    }
    
}

class RuleConfigurationViewController: FormViewController {

    var rule: Rule
    var callback: ((Rule) -> Void)?
    var editable: Bool = true
    let isEdit: Bool
    
    init(rule: Rule?, callback: ((Rule) -> Void)?) {
        if let rule = rule {
            self.rule = rule
            isEdit = true
        }else {
            self.rule = Rule(type: RuleType.DomainSuffix, action: RuleAction.Proxy, value: "")
            isEdit = false
        }
        self.callback = callback
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if editable {
            if isEdit {
                self.navigationItem.title = "Edit Rule".localized()
            }else {
                self.navigationItem.title = "Add Rule".localized()
            }
            navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(save))
        }else {
            navigationItem.title = "Rule".localized()
        }
        generateForm()
    }
    
    func generateForm() {
        form +++ Section()
            <<< PushRow<RuleType>(kRuleFormType) {
                $0.title = "Type".localized()
                $0.selectorTitle = "Choose type of rule".localized()
                $0.options = [RuleType.DomainSuffix, RuleType.DomainMatch, RuleType.Domain, RuleType.IPCIDR, RuleType.GeoIP]
                $0.value = self.rule.type
                $0.disabled = Condition(booleanLiteral: !editable)
                }.cellSetup({ (cell, row) -> () in
                    cell.accessoryType = .disclosureIndicator
                })
            <<< TextRow(kRuleFormValue) {
                $0.title = "Value".localized()
                $0.value = self.rule.value
                $0.disabled = Condition(booleanLiteral: !editable)
                }.cellSetup({ (cell, row) -> () in
                    cell.textField.keyboardType = .URL
                    cell.textField.autocorrectionType = .no
                    cell.textField.autocapitalizationType = .none
                })
            <<< PushRow<RuleAction>(kRuleFormAction) {
                $0.title = "Action".localized()
                $0.selectorTitle = "Choose action for rule".localized()
                $0.options = [RuleAction.Proxy, RuleAction.Direct, RuleAction.Reject]
                $0.value = self.rule.action
                $0.disabled = Condition(booleanLiteral: !editable)
                }.cellSetup({ (cell, row) -> () in
                    cell.accessoryType = .disclosureIndicator
                })
    }
    
    func save() {
        do {
            let values = form.values()
            guard let type = values[kRuleFormType] as? RuleType else {
                throw "You must choose a type".localized()
            }
            guard let value = (values[kRuleFormValue] as? String)?.trimmingCharacters(in: CharacterSet.whitespaces), value.characters.count > 0 else {
                throw "Value can't be empty".localized()
            }
            guard let action = values[kRuleFormAction] as? RuleAction else {
                throw "You must choose a action".localized()
            }
            rule.type = type
            rule.value = value
            rule.action = action
            callback?(rule)
            close()
        }catch {
            showTextHUD("\(error)", dismissAfterDelay: 1.0)
        }
    }

    
}
