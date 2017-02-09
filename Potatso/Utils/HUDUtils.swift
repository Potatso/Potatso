//
//  HUDUtils.swift
//  Potatso
//
//  Created by LEI on 3/25/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import UIKit
import MBProgressHUD
import Async

private var hudKey = "hud"

extension UIViewController {
    
    func showProgreeHUD(_ text: String? = nil) {
        hideHUD()
        let hud = MBProgressHUD.showAdded(to: view, animated: true)
        hud.mode = .indeterminate
        hud.label.text = text
    }
    
    func showTextHUD(_ text: String?, dismissAfterDelay: TimeInterval) {
        hideHUD()
        let hud = MBProgressHUD.showAdded(to: view, animated: true)
        hud.mode = .text
        hud.detailsLabel.text = text
        hideHUD(dismissAfterDelay)
    }
    
    func hideHUD() {
        MBProgressHUD.hide(for: view, animated: true)
    }
    
    func hideHUD(_ afterDelay: TimeInterval) {
        Async.main(after: afterDelay) { 
            self.hideHUD()
        }
    }
    
}

