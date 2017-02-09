//
//  CollectionViewController.swift
//  Potatso
//
//  Created by LEI on 5/31/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import Foundation
import Cartography

private let rowHeight: CGFloat = 135

class CollectionViewController: SegmentPageVC {

    let pageVCs = [
        RuleSetListViewController(),
        ProxyListViewController(),
        CloudViewController(),
    ]

    override func pageViewControllersForSegmentPageVC() -> [UIViewController] {
        return pageVCs
    }

    override func segmentsForSegmentPageVC() -> [String] {
        return ["Rule Set".localized(), "Proxy".localized(), "Cloud Set".localized()]
    }

    override func showPage(_ index: Int) {
        if index < 2 {
            navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(add))
        }else {
            navigationItem.rightBarButtonItem = nil
        }
        super.showPage(index)
    }

    func add() {
        switch segmentedControl.selectedSegmentIndex {
        case 0:
            let vc = RuleSetConfigurationViewController()
            navigationController?.pushViewController(vc, animated: true)
        case 1:
            let vc = ProxyConfigurationViewController()
            navigationController?.pushViewController(vc, animated: true)
        default:
            break
        }
    }
    
}

