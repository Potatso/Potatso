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

    override func viewWillAppear(_ animated: Bool) {
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

    func tableView(_ tableView: UITableView, shouldShowMenuForRowAtIndexPath indexPath: IndexPath) -> Bool {
        return true
    }

    func tableView(_ tableView: UITableView, canPerformAction action: Selector, forRowAtIndexPath indexPath: IndexPath, withSender sender: AnyObject?) -> Bool {
        return action == #selector(copy(_:))
    }

    func tableView(_ tableView: UITableView, performAction action: Selector, forRowAtIndexPath indexPath: IndexPath, withSender sender: AnyObject?) {
        switch action {
        case #selector(copy(_:)):
            guard let cell = tableView.cellForRow(at: indexPath) as? RequestEventRowCell else {
                return
            }
            UIPasteboard.general.string = cell.copyContent
            // implement copy here
        default:
            assertionFailure()
        }
    }

}
