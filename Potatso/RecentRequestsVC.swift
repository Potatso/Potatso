//
//  RecentRequestsViewController.swift
//  Potatso
//
//  Created by LEI on 4/19/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import Foundation
import Cartography
import PotatsoModel
import RealmSwift
import PotatsoLibrary
import PotatsoBase

private let kRecentRequestCellIdentifier = "recentRequests"
private let kRecentRequestCachedIdentifier = "requestsCached"

class RecentRequestsVC: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    var requests: [Request] = []
    let wormhole = Manager.sharedManager.wormhole
    var timer: NSTimer?
    var appear = false
    var stopped = false
    var showingCache = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "Recent Requests".localized()
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(onVPNStatusChanged), name: kProxyServiceVPNStatusNotification, object: nil)
        wormhole.listenForMessageWithIdentifier("tunnelConnectionRecords") { [unowned self](response) in
            self.updateUI(response as? String)
            Potatso.sharedUserDefaults().setObject(response as? String, forKey: kRecentRequestCachedIdentifier)
            Potatso.sharedUserDefaults().synchronize()
            return
        }
        self.updateUI(Potatso.sharedUserDefaults().stringForKey(kRecentRequestCachedIdentifier))
        if Manager.sharedManager.vpnStatus == .Off {
            showingCache = true
        }
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        appear = true
        onVPNStatusChanged()
    }
    
    func refresh() {
        wormhole.passMessageObject("", identifier: "getTunnelConnectionRecords")
    }
    
    func updateUI(requestString: String?) {
        if let responseStr = requestString, jsonArray = responseStr.jsonArray() {
            self.requests = jsonArray.reverse().filter({ ($0 as? [String : AnyObject]) != nil }).flatMap({ Request(dict: $0 as! [String : AnyObject]) })
        }else {
            self.requests = []
        }
        tableView.reloadData()
    }
    
    func onVPNStatusChanged() {
        let on = [VPNStatus.On, VPNStatus.Connecting].contains(Manager.sharedManager.vpnStatus)
        hintLabel.hidden = on
        if on {
            navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .Refresh, target: self, action: #selector(refresh))
        }else {
            navigationItem.rightBarButtonItem = nil
        }
        if on && showingCache {
            updateUI(nil)
        }
        showingCache = !on
    }
    
    // MARK: - TableView DataSource & Delegate
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        emptyView.hidden = requests.count > 0
        return requests.count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(kRecentRequestCellIdentifier, forIndexPath: indexPath) as! RecentRequestsCell
        cell.config(requests[indexPath.row])
        return cell
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
        navigationController?.pushViewController(RequestDetailVC(request: requests[indexPath.row]), animated: true)
    }
    
    func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return true
    }

    override func loadView() {
        super.loadView()
        view.backgroundColor = Color.Background
        view.addSubview(tableView)
        view.addSubview(emptyView)
        view.addSubview(hintLabel)
        tableView.registerClass(RecentRequestsCell.self, forCellReuseIdentifier: kRecentRequestCellIdentifier)
        setupLayout()
    }
    
    func setupLayout() {
        constrain(tableView, view) { tableView, view in
            tableView.edges == view.edges
        }
        constrain(hintLabel, emptyView, view) { hintLabel, emptyView, view in
            hintLabel.leading == view.leading
            hintLabel.trailing == view.trailing
            hintLabel.bottom == view.bottom
            hintLabel.height == 35
            
            emptyView.edges == view.edges
        }
    }
    
    lazy var tableView: UITableView = {
        let v = UITableView(frame: CGRect.zero, style: .Plain)
        v.dataSource = self
        v.delegate = self
        v.tableFooterView = UIView()
        v.tableHeaderView = UIView()
        v.separatorStyle = .SingleLine
        v.estimatedRowHeight = 70
        v.rowHeight = UITableViewAutomaticDimension
        return v
    }()
    
    lazy var emptyView: BaseEmptyView = {
        let v = BaseEmptyView()
        v.title = "You should manually refresh to see the request log.".localized()
        return v
    }()
    
    lazy var hintLabel: UILabel = {
        let v = UILabel()
        v.text = "Potatso is not connected".localized()
        v.textColor = UIColor.whiteColor()
        v.backgroundColor = "E74C3C".color
        v.textAlignment = .Center
        v.font = UIFont.systemFontOfSize(14)
        v.alpha = 0.8
        v.hidden = true
        return v
    }()
    
}
