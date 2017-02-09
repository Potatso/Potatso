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

    var timer: Timer?

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "Statistics".localized()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startTimer()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopTimer()
    }

    func startTimer() {
        timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(DashboardVC.onTime), userInfo: nil, repeats: true)
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
            DispatchQueue.main.async(execute: {
                self.updateForm(manager)
            })
        })
    }

    func updateForm(_ manager: NETunnelProviderManager?) {
        form.delegate = nil
        form.removeAll()
        form +++ generateTimeSection(manager)
        form +++ generateLogSection()
        form.delegate = self
        tableView?.reloadData()
    }

    func generateTimeSection(_ manager: NETunnelProviderManager?) -> Section {
        let section = Section("Connection".localized())
        section <<< LabelRow() {
            $0.title = "Start".localized()
            if Manager.sharedManager.vpnStatus == .on {
                if let time = Settings.shared().startTime {
                    $0.value = startTimeFormatter.string(from: time)
                    return
                }
            }
            $0.value = "-"
        }
        <<< LabelRow() {
            $0.title = "Up Time".localized()
            if Manager.sharedManager.vpnStatus == .on {
                if let time = Settings.shared().startTime {
                    //let flags = NSCalendar.Unit(rawValue: UInt.max)
                    //let difference = Calendar.current.components(flags, fromDate: time, toDate: Date(), options: NSCalendar.Options.MatchFirst)
                    let difference = Calendar.current.dateComponents([.day], from: time, to: Date())
                    $0.value = durationFormatter.string(from: difference)
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
            cell.accessoryType = .disclosureIndicator
            cell.selectionStyle = .default
        }).onCellSelection({ [unowned self](cell, row) -> () in
            cell.setSelected(false, animated: true)
            self.showRecentRequests()
        })
        <<< LabelRow() {
            $0.title = "Logs".localized()
        }.cellSetup({ (cell, row) -> () in
            cell.accessoryType = .disclosureIndicator
            cell.selectionStyle = .default
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

    lazy var startTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .medium
        return f
    }()

    lazy var durationFormatter: DateComponentsFormatter = {
        let f = DateComponentsFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

}
