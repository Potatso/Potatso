//
//  RuleSetConfigurationViewController.swift
//  Potatso
//
//  Created by LEI on 3/9/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import UIKit
import Eureka
import PotatsoLibrary
import PotatsoModel

private let kRuleSetFormName = "name"

class RuleSetConfigurationViewController: FormViewController {

    var ruleSet: PotatsoModel.RuleSet
    var rules: [Rule]
    let isEdit: Bool
    var editable: Bool {
        return ruleSet.editable && !ruleSet.isSubscribe
    }
    var callback: ((PotatsoModel.RuleSet?) -> Void)?
    var editSection: Section = Section()

    init(ruleSet: PotatsoModel.RuleSet? = nil, callback: ((PotatsoModel.RuleSet?) -> Void)? = nil) {
        self.callback = callback
        if let ruleSet = ruleSet {
            self.ruleSet = RuleSet(value: ruleSet)
            self.isEdit = true
        }else {
            self.ruleSet = RuleSet()
            self.isEdit = false
        }
        self.rules = self.ruleSet.rules
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if editable {
            navigationItem.title = isEdit ? "Edit Rule Set".localized() : "Add Rule Set".localized()
        }else {
            navigationItem.title = ruleSet.name
        }
        generateForm()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if editable {
            navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(save))
        }
        tableView?.reloadSections(IndexSet(integer: 1), with: .none)
    }

    func generateForm() {
        form.removeAll()
        form +++ Section()
            <<< TextRow(kRuleSetFormName) {
                $0.title = "Name".localized()
                $0.value = self.ruleSet.name
                $0.disabled = Condition(booleanLiteral: !self.editable)
            }.cellSetup { cell, row in
                cell.textField.placeholder = "Rule Set Name".localized()
            }
        
        editSection = Section("Rule".localized())
        if editable {
            editSection <<< BaseButtonRow () {
                $0.title = "Add Rule".localized()
            }.cellUpdate({ (cell, row) in
                cell.textLabel?.textColor = Color.Brand
            }).onCellSelection({ [unowned self] (cell, row) -> () in
                self.showRuleConfiguration(nil)
            })
        }
        for rule in rules {
            insertRule(rule, atIndex: editSection.count)
        }
        form +++ editSection
    }

    func insertRule(_ rule: Rule, atIndex index: NSInteger) {
        editSection.insert(LabelRow () {
                $0.title = rule.rowDescription.0 == nil ? "" : "\(rule.rowDescription.0!)"
                $0.value = rule.rowDescription.1 == nil ? "" : "\(rule.rowDescription.1!)"
                $0.disabled = Condition(booleanLiteral: !self.editable)
            }.cellSetup({ (cell, row) -> () in
                cell.accessoryType = .disclosureIndicator
                cell.selectionStyle = .default
            }).cellUpdate({ (cell, row) -> () in
                row.title = rule.rowDescription.0 == nil ? "" : "\(rule.rowDescription.0!)"
                row.value = rule.rowDescription.1 == nil ? "" : "\(rule.rowDescription.1!)"
            }).onCellSelection({ [unowned self] (cell, row) -> () in
                self.showRuleConfiguration(rule)
            }),
            at: index)
    }
    
    func showRuleConfiguration(_ rule: Rule?) {
        let vc = RuleConfigurationViewController(rule: rule) { result in
            if rule == nil {
                self.insertRule(result, atIndex: self.form[1].count)
                self.ruleSet.addRule(result)
            }
        }
        vc.editable = editable
        navigationController?.pushViewController(vc, animated: true)
    }
    
    func save() {
        do {
            let values = form.values()
            guard let name = (values[kRuleSetFormName] as? String)?.trimmingCharacters(in: CharacterSet.whitespaces), name.characters.count > 0 else {
                throw "Name can't be empty".localized()
            }
            ruleSet.name = name
            try DBUtils.add(ruleSet)
            callback?(ruleSet)
            close()
        }catch {
            showTextHUD("\(error)", dismissAfterDelay: 1.0)
        }
    }
    
    func tableView(_ tableView: UITableView, canEditRowAtIndexPath indexPath: IndexPath) -> Bool {
        if indexPath.section == 1 {
            return editable
        }
        return false
    }
    
    func tableView(_ tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: IndexPath) {
        if editingStyle == .delete {
            ruleSet.removeRule(atIndex: indexPath.row - 1)
            form[indexPath].hidden = true
            form[indexPath].evaluateHidden()
        }
    }
    
    func tableView(_ tableView: UITableView, editingStyleForRowAtIndexPath indexPath: IndexPath) -> UITableViewCellEditingStyle {
        return UITableViewCellEditingStyle.delete
    }
    
}
