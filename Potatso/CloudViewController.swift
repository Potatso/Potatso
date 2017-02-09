//
//  RuleSetListViewController.swift
//  Potatso
//
//  Created by LEI on 5/31/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import Foundation
import PotatsoModel
import Cartography
import ICSPullToRefresh
import Async

private let rowHeight: CGFloat = 120
private let kRuleSetCellIdentifier = "ruleset"
private let pageSize = 20

class CloudViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    var ruleSets: [RuleSet] = []
    var page = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        forceReloadData()
    }

    func forceReloadData() {
        loadData()
    }

    func loadData(isLoadMore loadMore: Bool = false) {
        if !loadMore {
            page = 0
        }
        API.getRuleSets(page + 1, count: pageSize) { (response) in
            defer {
                self.tableView.pullToRefreshView?.stopAnimating()
                self.tableView.infiniteScrollingView?.stopAnimating()
            }
            if response.result.isFailure {
                // Fail
                let errDesc = response.result.error?.localizedDescription ?? ""
                self.showTextHUD((errDesc.characters.count > 0 ? "\(errDesc)" : "Unkown error".localized()), dismissAfterDelay: 1.5)
            }else {
                guard let result = response.result.value else {
                    return
                }
                self.tableView.addInfiniteScrollingWithHandler({ [weak self] in
                    self?.loadData(isLoadMore: true)
                })
                self.tableView.setShowsInfiniteScrolling(result.count >= pageSize)
                if result.count > 0 {
                    self.page += 1
                }
                let data = result.filter({ $0.name.characters.count > 0})
                if loadMore {
                    self.ruleSets.append(contentsOf: data)
                    if result.count < pageSize {
                        self.showTextHUD("No more data".localized(), dismissAfterDelay: 1.0)
                    }
                }else {
                    self.ruleSets = data
                }
                self.tableView.reloadData()
            }
        }
    }

    func showRuleSetConfiguration(_ ruleSet: RuleSet?) {
        let vc = RuleSetConfigurationViewController(ruleSet: ruleSet)
        navigationController?.pushViewController(vc, animated: true)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return ruleSets.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: kRuleSetCellIdentifier, for: indexPath) as! RuleSetCell
        cell.setRuleSet(ruleSets[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let vc = CloudDetailViewController(ruleSet: ruleSets[indexPath.row])
        navigationController?.pushViewController(vc, animated: true)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView.addPullToRefreshHandler { [weak self] in
            self?.loadData()
        }
    }

    override func loadView() {
        super.loadView()
        view.backgroundColor = UIColor.init(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0)
        view.addSubview(tableView)
        tableView.register(RuleSetCell.self, forCellReuseIdentifier: kRuleSetCellIdentifier)

        constrain(tableView, view) { tableView, view in
            tableView.edges == view.edges
        }
    }

    lazy var tableView: UITableView = {
        let v = UITableView(frame: CGRect.zero, style: .plain)
        v.dataSource = self
        v.delegate = self
        v.tableFooterView = UIView()
        v.tableHeaderView = UIView()
        v.separatorStyle = .singleLine
        v.rowHeight = UITableViewAutomaticDimension
        v.estimatedRowHeight = rowHeight
        return v
    }()
    
}
