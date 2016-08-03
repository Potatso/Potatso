//
//  DashboardVC.swift
//  Potatso
//
//  Created by LEI on 7/13/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import Foundation
import Eureka
import NetworkExtension

class DashboardVC: FormViewController {

    var timer: NSTimer?

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "Statistics".localized()
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        startTimer()
    }

    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        stopTimer()
    }

    func startTimer() {
        timer = NSTimer.scheduledTimerWithTimeInterval(1, target: self, selector: #selector(DashboardVC.onTime), userInfo: nil, repeats: true)
        timer?.fire()
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    func onTime() {
        handleRefreshUI()
    }

    func handleRefreshUI() {
        Manager.sharedManager.loadProviderManager({ (manager) in
            dispatch_async(dispatch_get_main_queue(), {
                self.updateForm(manager)
            })
        })
    }

    func updateForm(manager: NETunnelProviderManager?) {
        form.delegate = nil
        form.removeAll()
        form +++ generateTimeSection(manager)
        form +++ generateLogSection()
        form.delegate = self
        tableView?.reloadData()
    }

    func generateTimeSection(manager: NETunnelProviderManager?) -> Section {
        let section = Section("Connection".localized())
        section <<< LabelRow() {
            $0.title = "Start".localized()
            if Manager.sharedManager.vpnStatus == .On {
                if let time = Settings.shared().startTime {
                    $0.value = startTimeFormatter.stringFromDate(time)
                    return
                }
            }
            $0.value = "-"
        }
        <<< LabelRow() {
            $0.title = "Up Time".localized()
            if Manager.sharedManager.vpnStatus == .On {
                if let time = Settings.shared().startTime {
                    let flags = NSCalendarUnit(rawValue: UInt.max)
                    let difference = NSCalendar.currentCalendar().components(flags, fromDate: time, toDate: NSDate(), options: NSCalendarOptions.MatchFirst)
                    $0.value = durationFormatter.stringFromDateComponents(difference)
                    return
                }
            }
            $0.value = "-"
        }
        return section
    }

    func generateLogSection() -> Section {
        let section = Section()
        section <<< LabelRow() {
            $0.title = "Recent Requests".localized()
        }.cellSetup({ (cell, row) -> () in
            cell.accessoryType = .DisclosureIndicator
            cell.selectionStyle = .Default
        }).onCellSelection({ [unowned self](cell, row) -> () in
            cell.setSelected(false, animated: true)
            self.showRecentRequests()
        })
        <<< LabelRow() {
            $0.title = "Logs".localized()
        }.cellSetup({ (cell, row) -> () in
            cell.accessoryType = .DisclosureIndicator
            cell.selectionStyle = .Default
        }).onCellSelection({ [unowned self](cell, row) -> () in
            cell.setSelected(false, animated: true)
            self.showLogs()
        })
        return section
    }

    func showRecentRequests() {
        let vc = RecentRequestsVC()
        navigationController?.pushViewController(vc, animated: true)
    }

    func showLogs() {
        navigationController?.pushViewController(LogDetailViewController(), animated: true)
    }

    lazy var startTimeFormatter: NSDateFormatter = {
        let f = NSDateFormatter()
        f.dateStyle = .MediumStyle
        f.timeStyle = .MediumStyle
        return f
    }()

    lazy var durationFormatter: NSDateComponentsFormatter = {
        let f = NSDateComponentsFormatter()
        f.unitsStyle = .Abbreviated
        return f
    }()

}
