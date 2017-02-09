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
    
    var timer: Timer?
    
    var rowCount: Int {
        return 1
    }
    
    var status: Bool = false

    var socket: GCDAsyncSocket!

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        socket = GCDAsyncSocket(delegate: self, delegateQueue: DispatchQueue.global(priority: DispatchQueue.GlobalQueuePriority.background))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let port = Potatso.sharedUserDefaults().integer(forKey: "tunnelStatusPort")
        status = port > 0
        tableView.register(CurrentGroupCell.self, forCellReuseIdentifier: kCurrentGroupCellIndentifier)
        view.addSubview(tableView)
        updateLayout()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startTimer()
        tableView.reloadData()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopTimer()
    }

    func tryConnectStatusSocket() {
        let port = Potatso.sharedUserDefaults().integer(forKey: "tunnelStatusPort")
        guard port > 0 else {
            updateStatus(false)
            return
        }
        do {
            socket.delegate = self
            try socket.connect(toHost: "127.0.0.1", onPort: UInt16(port))
        }catch {
            updateStatus(false)
        }
    }

    func startTimer() {
        timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(TodayViewController.tryConnectStatusSocket), userInfo: nil, repeats: true)
        timer?.fire()
    }

    func stopTimer() {
        socket.disconnect()
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Socket

    func socket(_ sock: GCDAsyncSocket!, didConnectToHost host: String!, port: UInt16) {
        updateStatus(true)
        sock.delegate = nil
        sock.disconnect()
    }

    func socketDidDisconnect(_ sock: GCDAsyncSocket!, withError err: NSError!) {
        updateStatus(false)
    }

    func updateStatus(_ current: Bool) {
        if status != current {
            status = current
            DispatchQueue.main.async(execute: { 
                self.tableView.reloadRows(at: [IndexPath(row: 0, section: 0)], with: .none)
            })
        }
    }
    
    func switchVPN() {
        if status {
            wormhole.passMessageObject("" as NSCoding?, identifier: "stopTunnel")
        }else {
            URLSession.shared.dataTask(with: URL(string: "https://on-demand.connect.potatso.com/start/")!).resume()
        }
    }
    
    func widgetMarginInsets(forProposedMarginInsets defaultMarginInsets: UIEdgeInsets) -> UIEdgeInsets {
        var inset = defaultMarginInsets
        inset.bottom = 0
        return inset
    }

    func widgetPerformUpdate(_ completionHandler: (@escaping (NCUpdateResult) -> Void)) {
        // Perform any setup necessary in order to update the view.

        // If an error is encountered, use NCUpdateResult.Failed
        // If there's no update required, use NCUpdateResult.NoData
        // If there's an update, use NCUpdateResult.NewData
        
        completionHandler(NCUpdateResult.newData)
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return rowCount
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell: UITableViewCell!
        if indexPath.row == 0 {
            cell = tableView.dequeueReusableCell(withIdentifier: kCurrentGroupCellIndentifier, for: indexPath)
            let name = Potatso.sharedUserDefaults().object(forKey: kDefaultGroupName) as? String
            (cell as? CurrentGroupCell)?.config(name ?? "Default".localized(), status: status, switchVPN: switchVPN)
        }
        cell.preservesSuperviewLayoutMargins = false
        cell.layoutMargins = UIEdgeInsets.zero
        cell.separatorInset = UIEdgeInsets.zero
        cell.selectionStyle = .none
        if indexPath.row == rowCount - 1 {
            cell.separatorInset = UIEdgeInsetsMake(0, cell.bounds.size.width, 0, 0)
        }else {
            cell.separatorInset = UIEdgeInsets.zero
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
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
        let v = UITableView(frame: CGRect.zero, style: .plain)
        v.tableFooterView = UIView()
        v.tableHeaderView = UIView()
        v.dataSource = self
        v.delegate = self
        return v
    }()
    
    
    
}
