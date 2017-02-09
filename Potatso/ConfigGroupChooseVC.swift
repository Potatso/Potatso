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
            window = ConfigGroupChooseWindow(frame: UIScreen.main.bounds)
            window?.backgroundColor = UIColor.init(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0)
            window?.makeKeyAndVisible()
            window?.chooseVC.view.frame = CGRect(x: 0, y: window!.frame.height, width: window!.frame.width, height: window!.frame.height)
            UIView.animate(withDuration: 0.3, animations: {
                self.window?.backgroundColor = "000".color.alpha(0.5)
                self.window?.chooseVC.view.frame.origin = CGPoint(x: 0, y: 0)
            }) 
        }
    }

    func hide() {
        if let window = window  {
            UIView.animate(withDuration: 0.3, animations: {
                window.chooseVC.view.frame.origin = CGPoint(x: 0, y: window.frame.height)
            }, completion: { (finished) in
                window.chooseVC.view.removeFromSuperview()
                self.window?.isHidden = true
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
        NotificationCenter.default.addObserver(self, selector: #selector(ConfigGroupChooseWindow.onStatusBarFrameChange), name: NSNotification.Name.UIApplicationDidChangeStatusBarFrame, object: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func onStatusBarFrameChange() {
        frame = UIScreen.main.bounds
    }

}

class ConfigGroupChooseVC: UIViewController, UITableViewDataSource, UITableViewDelegate {

    let groups: Results<ConfigurationGroup>
    let colors = ["3498DB", "E74C3C", "8E44AD", "16A085", "E67E22", "2C3E50"]
    var gesture: UITapGestureRecognizer?
    var token: RLMNotificationToken?

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        groups = DBUtils.allNotDeleted(ConfigurationGroup.self, sorted: "createAt")
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        NotificationCenter.default.addObserver(self, selector: #selector(onVPNStatusChanged), name: NSNotification.Name(rawValue: kProxyServiceVPNStatusNotification), object: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateUI()
        token = groups.addNotificationBlock { [unowned self] (changed) in
            switch changed {
            case let .update(_, deletions: deletions, insertions: insertions, modifications: modifications):
                self.tableView.beginUpdates()
                defer {
                    self.tableView.endUpdates()
                    CurrentGroupManager.shared.setConfigGroupId(CurrentGroupManager.shared.group.uuid)
                }
                self.tableView.deleteRows(at: deletions.map({ IndexPath(row: $0, section: 0) }), with: .automatic)
                self.tableView.insertRows(at: insertions.map({ IndexPath(row: $0, section: 0) }), with: .automatic)
                self.tableView.reloadRows(at: modifications.map({ IndexPath(row: $0, section: 0) }), with: .automatic)
            default:
                break
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        token?.stop()
    }

    func onVPNStatusChanged() {
        updateUI()
    }

    func updateUI() {
        tableView.reloadData()
    }

    func showConfigGroup(_ group: ConfigurationGroup, animated: Bool = true) {
        CurrentGroupManager.shared.setConfigGroupId(group.uuid)
        ConfigGroupChooseManager.shared.hide()
    }

    func onTap() {
        ConfigGroupChooseManager.shared.hide()
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceiveTouch touch: UITouch) -> Bool {
        if let view = touch.view, view.isDescendant(of: tableView){
            return false
        }
        return true
    }

    // MARK: - TableView DataSource & Delegate
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return groups.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: kGroupCellIdentifier, for: indexPath) as! ConfigGroupCell
        cell.config(groups[indexPath.row], hintColor: colors[indexPath.row % colors.count].color )
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        showConfigGroup(groups[indexPath.row])
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        let group = groups[indexPath.row]
        if group.isDefault && Manager.sharedManager.vpnStatus != .off {
            return false
        }
        return groups.count > 1
    }

    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCellEditingStyle {
        return .delete
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
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
        tableView.isScrollEnabled = (tableRowHeight > maxHeight)
        tableView.frame = CGRect(x: 0, y: originY, width: view.bounds.size.width, height: height)
    }

    override func loadView() {
        super.loadView()
        view.backgroundColor = UIColor.init(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0)
        gesture = UITapGestureRecognizer(target: self, action: #selector(onTap))
        gesture?.delegate = self
        view.addGestureRecognizer(gesture!)
        view.addSubview(tableView)
        tableView.register(ConfigGroupCell.self, forCellReuseIdentifier: kGroupCellIdentifier)
    }

    lazy var tableView: UITableView = {
        let v = UITableView(frame: CGRect.zero, style: .plain)
        v.dataSource = self
        v.delegate = self
        v.tableFooterView = UIView()
        v.tableHeaderView = UIView()
        v.separatorStyle = .singleLine
        v.rowHeight = rowHeight
        return v
    }()

}
