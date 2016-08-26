//
//  CloudDetailViewController.swift
//  Potatso
//
//  Created by LEI on 6/6/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import Foundation
import PotatsoModel
import Cartography

private let rowHeight: CGFloat = 54
private let kRuleSetCellIdentifier = "ruleset"
private let kRuleCellIdentifier = "rule"

class CloudDetailViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    var ruleSet: RuleSet

    init(ruleSet: RuleSet) {
        self.ruleSet = ruleSet
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "Detail".localized()
        loadData()
        if isExist(ruleSet.uuid) {
            subscribeButton.setTitle("Unsubscribe".localized(), forState: .Normal)
            subscribeButton.backgroundColor = "FF5E3B".color
        }else {
            subscribeButton.setTitle("Subscribe".localized(), forState: .Normal)
            subscribeButton.backgroundColor = "1E96E2".color
        }
    }

    func loadData() {
        activityIndicator.startAnimating()
        activityIndicator.hidden = false
        subscribeButton.hidden = true
        API.getRuleSetDetail(ruleSet.uuid) { (response) in
            defer {
                self.activityIndicator.stopAnimating()
            }
            if response.result.isFailure {
                // Fail
                let errDesc = response.result.error?.localizedDescription ?? ""
                self.showTextHUD((errDesc.characters.count > 0 ? "\(errDesc)" : "Unkown error".localized()), dismissAfterDelay: 1.5)
            }else {
                guard let result = response.result.value else {
                    return
                }
                self.ruleSet = result
                self.tableView.reloadData()
                self.subscribeButton.hidden = false
            }
        }
    }

    func isExist(uuid: String) -> Bool {
        return defaultRealm.objects(RuleSet).filter("uuid == '\(uuid)' && deleted == false").count > 0
    }

    func subscribe() {
        let uuid = ruleSet.uuid
        if isExist(uuid) {
            do {
                try DBUtils.softDelete([uuid], type: RuleSet.self)
            }catch {
                self.showTextHUD("Fail to unsubscribe".localized(), dismissAfterDelay: 1.0)
                return
            }
        }else {
            do {
                try RuleSet.addRemoteObject(ruleSet)
            }catch {
                self.showTextHUD("Fail to subscribe".localized(), dismissAfterDelay: 1.0)
                return
            }
        }
        Alert.show(self, message: "Success".localized()) { [weak self] in
            self?.navigationController?.popViewControllerAnimated(true)
        }
    }

    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        if ruleSet.rules.count > 0 {
            return 2
        }
        return 1
    }

    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return 1
        case 1:
            return ruleSet.rules.count
        default:
            fatalError()
        }
    }

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell: UITableViewCell
        switch indexPath.section {
        case 0:
            cell = tableView.dequeueReusableCellWithIdentifier(kRuleSetCellIdentifier, forIndexPath: indexPath)
            (cell as? RuleSetCell)?.setRuleSet(ruleSet, showFullDescription: true)
        case 1:
            cell = tableView.dequeueReusableCellWithIdentifier(kRuleCellIdentifier, forIndexPath: indexPath)
            (cell as? RuleCell)?.setRule(ruleSet.rules[indexPath.row])
        default:
            fatalError()
        }
        cell.selectionStyle = .None
        cell.preservesSuperviewLayoutMargins = false
        cell.layoutMargins = UIEdgeInsetsZero
        cell.separatorInset = UIEdgeInsetsZero
        return cell
    }

    func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 1:
            return "Rules".localized()
        default:
            return nil
        }
    }

    func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch section {
        case 0:
            return 0.01
        default:
            return UITableViewAutomaticDimension
        }
    }

    override func loadView() {
        super.loadView()
        view.backgroundColor = UIColor.clearColor()
        view.addSubview(tableView)
        tableView.registerClass(RuleSetCell.self, forCellReuseIdentifier: kRuleSetCellIdentifier)
        tableView.registerClass(RuleCell.self, forCellReuseIdentifier: kRuleCellIdentifier)
        view.addSubview(activityIndicator)
        view.addSubview(subscribeButton)

        let buttonHeight: CGFloat = 49

        constrain(tableView, activityIndicator, subscribeButton, view) { tableView, activityIndicator, subscribeButton,  view in
            tableView.edges == inset(view.edges, 0, 0, buttonHeight, 0)
            activityIndicator.center == view.center
            subscribeButton.leading == view.leading
            subscribeButton.trailing == view.trailing
            subscribeButton.bottom == view.bottom
            subscribeButton.height == buttonHeight
        }
    }

    lazy var tableView: UITableView = {
        let v = UITableView(frame: CGRect.zero, style: .Grouped)
        v.dataSource = self
        v.delegate = self
        v.tableFooterView = UIView()
        v.tableHeaderView = UIView(frame: CGRect(x: 0, y: 0, width: 1, height: 0.01))
        v.separatorStyle = .SingleLine
        v.rowHeight = UITableViewAutomaticDimension
        v.estimatedRowHeight = rowHeight
        return v
    }()

    lazy var activityIndicator: UIActivityIndicatorView = {
        let v = UIActivityIndicatorView(activityIndicatorStyle: .Gray)
        v.hidesWhenStopped = true
        return v
    }()

    lazy var subscribeButton: UIButton = {
        let v = UIButton(frame: CGRect.zero)
        v.addTarget(self, action: #selector(subscribe), forControlEvents: .TouchUpInside)
        v.setTitleColor(UIColor.whiteColor(), forState: .Normal)
        return v
    }()

}