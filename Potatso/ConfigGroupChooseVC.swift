//
//  ConfigGroupChooseVC.swift
//  Potatso
//
//  Created by LEI on 5/27/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import Foundation
import Cartography
import PotatsoModel
import RealmSwift
import Realm
import PotatsoLibrary

private let kGroupCellIdentifier = "group"

private let rowHeight: CGFloat = 110

class ConfigGroupChooseManager {

    static let shared = ConfigGroupChooseManager()

    var window: ConfigGroupChooseWindow?

    func show() {
        if window == nil {
            window = ConfigGroupChooseWindow(frame: UIScreen.mainScreen().bounds)
            window?.backgroundColor = UIColor.clearColor()
            window?.makeKeyAndVisible()
            window?.chooseVC.view.frame = CGRect(x: 0, y: window!.frame.height, width: window!.frame.width, height: window!.frame.height)
            UIView.animateWithDuration(0.3) {
                self.window?.backgroundColor = "000".color.alpha(0.5)
                self.window?.chooseVC.view.frame.origin = CGPoint(x: 0, y: 0)
            }
        }
    }

    func hide() {
        if let window = window  {
            UIView.animateWithDuration(0.3, animations: {
                window.chooseVC.view.frame.origin = CGPoint(x: 0, y: window.frame.height)
            }, completion: { (finished) in
                window.chooseVC.view.removeFromSuperview()
                self.window?.hidden = true
                self.window = nil
            })
        }
    }

}

class ConfigGroupChooseWindow: UIWindow {

    let chooseVC = ConfigGroupChooseVC()

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(chooseVC.view)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(ConfigGroupChooseWindow.onStatusBarFrameChange), name: UIApplicationDidChangeStatusBarFrameNotification, object: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func onStatusBarFrameChange() {
        frame = UIScreen.mainScreen().bounds
    }

}

class ConfigGroupChooseVC: UIViewController, UITableViewDataSource, UITableViewDelegate {

    let groups: Results<ConfigurationGroup>
    let colors = ["3498DB", "E74C3C", "8E44AD", "16A085", "E67E22", "2C3E50"]
    var gesture: UITapGestureRecognizer?
    var token: RLMNotificationToken?

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
        groups = DBUtils.allNotDeleted(ConfigurationGroup.self, sorted: "createAt")
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(onVPNStatusChanged), name: kProxyServiceVPNStatusNotification, object: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        updateUI()
        token = groups.addNotificationBlock { [unowned self] (changed) in
            switch changed {
            case let .Update(_, deletions: deletions, insertions: insertions, modifications: modifications):
                self.tableView.beginUpdates()
                defer {
                    self.tableView.endUpdates()
                    CurrentGroupManager.shared.setConfigGroupId(CurrentGroupManager.shared.group.uuid)
                }
                self.tableView.deleteRowsAtIndexPaths(deletions.map({ NSIndexPath(forRow: $0, inSection: 0) }), withRowAnimation: .Automatic)
                self.tableView.insertRowsAtIndexPaths(insertions.map({ NSIndexPath(forRow: $0, inSection: 0) }), withRowAnimation: .Automatic)
                self.tableView.reloadRowsAtIndexPaths(modifications.map({ NSIndexPath(forRow: $0, inSection: 0) }), withRowAnimation: .Automatic)
            default:
                break
            }
        }
    }

    override func viewWillDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
        token?.stop()
    }

    func onVPNStatusChanged() {
        updateUI()
    }

    func updateUI() {
        tableView.reloadData()
    }

    func showConfigGroup(group: ConfigurationGroup, animated: Bool = true) {
        CurrentGroupManager.shared.setConfigGroupId(group.uuid)
        ConfigGroupChooseManager.shared.hide()
    }

    func onTap() {
        ConfigGroupChooseManager.shared.hide()
    }

    func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldReceiveTouch touch: UITouch) -> Bool {
        if let view = touch.view where view.isDescendantOfView(tableView){
            return false
        }
        return true
    }

    // MARK: - TableView DataSource & Delegate
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return groups.count
    }

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(kGroupCellIdentifier, forIndexPath: indexPath) as! ConfigGroupCell
        cell.config(groups[indexPath.row], hintColor: colors[indexPath.row % colors.count].color )
        return cell
    }

    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        showConfigGroup(groups[indexPath.row])
    }

    func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        let group = groups[indexPath.row]
        if group.isDefault && Manager.sharedManager.vpnStatus != .Off {
            return false
        }
        return groups.count > 1
    }

    func tableView(tableView: UITableView, editingStyleForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCellEditingStyle {
        return .Delete
    }

    func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if editingStyle == .Delete {
            let item: ConfigurationGroup
            guard indexPath.row < groups.count else {
                return
            }
            item = groups[indexPath.row]
            do {
                try DBUtils.softDelete(item.uuid, type: ConfigurationGroup.self)
            }catch {
                self.showTextHUD("\("Fail to delete item".localized()): \((error as NSError).localizedDescription)", dismissAfterDelay: 1.5)
            }
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let tableRowHeight = CGFloat(groups.count) * rowHeight
        let maxHeight = view.bounds.size.height * 0.7
        let height = min(tableRowHeight, maxHeight)
        let originY = view.bounds.size.height - height
        tableView.scrollEnabled = (tableRowHeight > maxHeight)
        tableView.frame = CGRect(x: 0, y: originY, width: view.bounds.size.width, height: height)
    }

    override func loadView() {
        super.loadView()
        view.backgroundColor = UIColor.clearColor()
        gesture = UITapGestureRecognizer(target: self, action: #selector(onTap))
        gesture?.delegate = self
        view.addGestureRecognizer(gesture!)
        view.addSubview(tableView)
        tableView.registerClass(ConfigGroupCell.self, forCellReuseIdentifier: kGroupCellIdentifier)
    }

    lazy var tableView: UITableView = {
        let v = UITableView(frame: CGRect.zero, style: .Plain)
        v.dataSource = self
        v.delegate = self
        v.tableFooterView = UIView()
        v.tableHeaderView = UIView()
        v.separatorStyle = .SingleLine
        v.rowHeight = rowHeight
        return v
    }()

}