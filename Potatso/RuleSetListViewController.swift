//
//  RuleSetListViewController.swift
//  Potatso
//
//  Created by LEI on 5/31/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import Foundation
import PotatsoModel
import Cartography
import Realm

private let rowHeight: CGFloat = 54
private let kRuleSetCellIdentifier = "ruleset"

class RuleSetListViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    var ruleSets: [RuleSet] = []
    var chooseCallback: (RuleSet? -> Void)?
    // Observe Realm Notifications
    var token: RLMNotificationToken?

    init(chooseCallback: (RuleSet? -> Void)? = nil) {
        self.chooseCallback = chooseCallback
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        navigationItem.title = "Rule Set".localized()
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .Add, target: self, action: #selector(add))
        reloadData()
        token = defaultRealm.addNotificationBlock { [unowned self] notification, realm in
            self.reloadData()
        }
    }

    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        token?.stop()
    }

    func add() {
        let vc = RuleSetConfigurationViewController()
        navigationController?.pushViewController(vc, animated: true)
    }

    func reloadData() {
        ruleSets = defaultRealm.objects(RuleSet).sorted("createAt").map({ $0 })
        tableView.reloadData()
    }

    func showRuleSetConfiguration(ruleSet: RuleSet?) {
        let vc = RuleSetConfigurationViewController(ruleSet: ruleSet)
        navigationController?.pushViewController(vc, animated: true)
    }

    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return ruleSets.count
    }

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(kRuleSetCellIdentifier, forIndexPath: indexPath) as! RuleSetCell
        cell.setRuleSet(ruleSets[indexPath.row], showSubscribe: true)
        return cell
    }

    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
        let ruleSet = ruleSets[indexPath.row]
        if let cb = chooseCallback {
            cb(ruleSet)
            close()
        }else {
            showRuleSetConfiguration(ruleSet)
        }
    }

    func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return chooseCallback == nil
    }

    func tableView(tableView: UITableView, editingStyleForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCellEditingStyle {
        return .Delete
    }

    func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if editingStyle == .Delete {
            let item: RuleSet
            guard indexPath.row < ruleSets.count else {
                return
            }
            item = ruleSets[indexPath.row]
            tableView.beginUpdates()
            defer {
                tableView.endUpdates()
            }
            do {
                ruleSets.removeAtIndex(indexPath.row)
                try defaultRealm.write {
                    defaultRealm.delete(item)
                }
                tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Automatic)
            }catch {
                self.showTextHUD("\("Fail to delete item".localized()): \((error as NSError).localizedDescription)", dismissAfterDelay: 1.5)
            }
        }
    }
    

    override func loadView() {
        super.loadView()
        view.backgroundColor = UIColor.clearColor()
        view.addSubview(tableView)
        tableView.registerClass(RuleSetCell.self, forCellReuseIdentifier: kRuleSetCellIdentifier)

        constrain(tableView, view) { tableView, view in
            tableView.edges == view.edges
        }
    }

    lazy var tableView: UITableView = {
        let v = UITableView(frame: CGRect.zero, style: .Plain)
        v.dataSource = self
        v.delegate = self
        v.tableFooterView = UIView()
        v.tableHeaderView = UIView()
        v.separatorStyle = .SingleLine
        v.rowHeight = UITableViewAutomaticDimension
        v.estimatedRowHeight = rowHeight
        return v
    }()

}