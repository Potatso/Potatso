//
//  RequestListVC.swift
//  Potatso
//
//  Created by LEI on 7/15/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import Foundation

class RequestDetailVC: SegmentPageVC {

    let pageVCs: [UIViewController]
    let request: Request

    init(request: Request) {
        self.request = request
        self.pageVCs = [
            RequestOverviewVC(request: request),
        ]
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func pageViewControllersForSegmentPageVC() -> [UIViewController] {
        return pageVCs
    }

    override func segmentsForSegmentPageVC() -> [String] {
        return ["Overview"]
    }

}