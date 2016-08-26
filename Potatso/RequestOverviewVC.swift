//
//  RequestOverviewVC.swift
//  Potatso
//
//  Created by LEI on 7/15/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import Foundation
import Eureka

class RequestOverviewVC: FormViewController {

    let request: Request

    init(request: Request) {
        self.request = request
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        handleRefreshUI()
    }

    func handleRefreshUI() {
        updateForm()
    }

    func updateForm() {
        form.delegate = nil
        form.removeAll()
        form +++ generateTimelineSection()
        form.delegate = self
        tableView?.reloadData()
    }

    func generateTimelineSection() -> Section {
        let section = Section()
        for event in request.events {
            section <<< RequestEventRow() {
                $0.value = event
            }
        }
        return section
    }

    func tableView(tableView: UITableView, shouldShowMenuForRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return true
    }

    func tableView(tableView: UITableView, canPerformAction action: Selector, forRowAtIndexPath indexPath: NSIndexPath, withSender sender: AnyObject?) -> Bool {
        return action == #selector(NSObject.copy(_:))
    }

    func tableView(tableView: UITableView, performAction action: Selector, forRowAtIndexPath indexPath: NSIndexPath, withSender sender: AnyObject?) {
        switch action {
        case #selector(NSObject.copy(_:)):
            guard let cell = tableView.cellForRowAtIndexPath(indexPath) as? RequestEventRowCell else {
                return
            }
            UIPasteboard.generalPasteboard().string = cell.copyContent
            // implement copy here
        default:
            assertionFailure()
        }
    }

}