//
//  TodayViewController.swift
//  TodayWidget
//
//  Created by LEI on 4/12/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import UIKit
import NotificationCenter
import PotatsoBase
import Cartography
import SwiftColor
import PotatsoLibrary
import MMWormhole
import CocoaAsyncSocket

private let kCurrentGroupCellIndentifier = "kCurrentGroupIndentifier"

class TodayViewController: UIViewController, NCWidgetProviding, UITableViewDataSource, UITableViewDelegate, GCDAsyncSocketDelegate {
    
    let constrainGroup = ConstraintGroup()
    
    let wormhole = Manager.sharedManager.wormhole
    
    var timer: NSTimer?
    
    var rowCount: Int {
        return 1
    }
    
    var status: Bool = false

    var socket: GCDAsyncSocket!

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        socket = GCDAsyncSocket(delegate: self, delegateQueue: dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let port = Potatso.sharedUserDefaults().integerForKey("tunnelStatusPort")
        status = port > 0
        tableView.registerClass(CurrentGroupCell.self, forCellReuseIdentifier: kCurrentGroupCellIndentifier)
        view.addSubview(tableView)
        updateLayout()
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        startTimer()
        tableView.reloadData()
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        stopTimer()
    }

    func tryConnectStatusSocket() {
        let port = Potatso.sharedUserDefaults().integerForKey("tunnelStatusPort")
        guard port > 0 else {
            updateStatus(false)
            return
        }
        do {
            socket.delegate = self
            try socket.connectToHost("127.0.0.1", onPort: UInt16(port))
        }catch {
            updateStatus(false)
        }
    }

    func startTimer() {
        timer = NSTimer.scheduledTimerWithTimeInterval(1, target: self, selector: #selector(TodayViewController.tryConnectStatusSocket), userInfo: nil, repeats: true)
        timer?.fire()
    }

    func stopTimer() {
        socket.disconnect()
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Socket

    func socket(sock: GCDAsyncSocket!, didConnectToHost host: String!, port: UInt16) {
        updateStatus(true)
        sock.delegate = nil
        sock.disconnect()
    }

    func socketDidDisconnect(sock: GCDAsyncSocket!, withError err: NSError!) {
        updateStatus(false)
    }

    func updateStatus(current: Bool) {
        if status != current {
            status = current
            dispatch_async(dispatch_get_main_queue(), { 
                self.tableView.reloadRowsAtIndexPaths([NSIndexPath(forRow: 0, inSection: 0)], withRowAnimation: .None)
            })
        }
    }
    
    func switchVPN() {
        if status {
            wormhole.passMessageObject("", identifier: "stopTunnel")
        }else {
            NSURLSession.sharedSession().dataTaskWithURL(NSURL(string: "https://on-demand.connect.potatso.com/start/")!).resume()
        }
    }
    
    func widgetMarginInsetsForProposedMarginInsets(defaultMarginInsets: UIEdgeInsets) -> UIEdgeInsets {
        var inset = defaultMarginInsets
        inset.bottom = 0
        return inset
    }

    func widgetPerformUpdateWithCompletionHandler(completionHandler: ((NCUpdateResult) -> Void)) {
        // Perform any setup necessary in order to update the view.

        // If an error is encountered, use NCUpdateResult.Failed
        // If there's no update required, use NCUpdateResult.NoData
        // If there's an update, use NCUpdateResult.NewData
        
        completionHandler(NCUpdateResult.NewData)
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return rowCount
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        var cell: UITableViewCell!
        if indexPath.row == 0 {
            cell = tableView.dequeueReusableCellWithIdentifier(kCurrentGroupCellIndentifier, forIndexPath: indexPath)
            let name = Potatso.sharedUserDefaults().objectForKey(kDefaultGroupName) as? String
            (cell as? CurrentGroupCell)?.config(name ?? "Default".localized(), status: status, switchVPN: switchVPN)
        }
        cell.preservesSuperviewLayoutMargins = false
        cell.layoutMargins = UIEdgeInsetsZero
        cell.separatorInset = UIEdgeInsetsZero
        cell.selectionStyle = .None
        if indexPath.row == rowCount - 1 {
            cell.separatorInset = UIEdgeInsetsMake(0, cell.bounds.size.width, 0, 0)
        }else {
            cell.separatorInset = UIEdgeInsetsZero
        }
        
        return cell
    }
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return 60
    }
    
    func updateLayout() {
        constrain(tableView, view, replace: constrainGroup) { tableView, superView in
            tableView.leading == superView.leading
            tableView.top == superView.top
            tableView.trailing == superView.trailing
            tableView.bottom == superView.bottom - 15
            tableView.height == CGFloat(44 * rowCount)
        }
    }
    
    lazy var tableView: UITableView = {
        let v = UITableView(frame: CGRectZero, style: .Plain)
        v.tableFooterView = UIView()
        v.tableHeaderView = UIView()
        v.dataSource = self
        v.delegate = self
        return v
    }()
    
    
    
}
