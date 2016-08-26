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
    
    func showProgreeHUD(text: String? = nil) {
        hideHUD()
        let hud = MBProgressHUD.showHUDAddedTo(view, animated: true)
        hud.mode = .Indeterminate
        hud.label.text = text
    }
    
    func showTextHUD(text: String?, dismissAfterDelay: NSTimeInterval) {
        hideHUD()
        let hud = MBProgressHUD.showHUDAddedTo(view, animated: true)
        hud.mode = .Text
        hud.detailsLabel.text = text
        hideHUD(dismissAfterDelay)
    }
    
    func hideHUD() {
        MBProgressHUD.hideHUDForView(view, animated: true)
    }
    
    func hideHUD(afterDelay: NSTimeInterval) {
        Async.main(after: afterDelay) { 
            self.hideHUD()
        }
    }
    
}

