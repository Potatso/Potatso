//
//  SyncVC.swift
//  Potatso
//
//  Created by LEI on 8/4/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import Foundation
import Eureka

class SyncVC: FormViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "Sync".localized()
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        NSNotificationCenter.defaultCenter().addObserverForName(SyncManager.syncServiceChangedNotification, object: nil, queue: NSOperationQueue.mainQueue()) { [weak self] (noti) in
            self?.generateForm()
        }
        generateForm()
    }

    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }

    func generateForm() {
        form.delegate = nil
        form.removeAll()
        form +++ generateServiceSection()
        form.delegate = self
        tableView?.reloadData()
    }

    func generateServiceSection() -> Section {
        let section = Section()
        section
            <<< PushRow<SyncServiceType>() {
                $0.title = "Sync Service".localized()
                $0.options = [.None, .iCloud]
                $0.value = SyncManager.shared.currentSyncServiceType
                $0.selectorTitle = "Choose Sync Service".localized()
            }.onChange({ [weak self] (row) in
                if let type = row.value {
                    self?.showProgreeHUD()
                    SyncManager.shared.setupNewService(type, completion: { (error) in
                        self?.hideHUD()
                        if let error = error {
                            if let vc = self {
                                Alert.show(vc, title: "Sync Service Setup Failed", message: "\(error)")
                            }
                        } else {
                            SyncManager.shared.currentSyncServiceType = type
                            self?.forceSync()
                        }
                    })
                }
            })
        section
            <<< ButtonRow {
                $0.title = SyncManager.shared.syncing ? "Syncing..." : "Sync Manually"
                $0.hidden = Condition.Function([""]) { form in
                    return SyncManager.shared.currentSyncServiceType == .None
                }
            }.onCellSelection({ [weak self] (cell, row) in
                self?.forceSync()
            })
        return section
    }

    func forceSync() {
        SyncManager.shared.sync(true, completion: { (error) in
            if let error = error {
                Alert.show(self, title: "Sync Failed", message:  "\(error)")
            } else {
                Alert.show(self, title: "Sync Success")
            }
        })
    }

}