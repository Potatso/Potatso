//
//  AlertUtils.swift
//  Potatso
//
//  Created by LEI on 4/10/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import Foundation

class Alert: NSObject {

    static func show(_ vc: UIViewController, title: String? = nil, message: String? = nil, confirmMessage: String = "OK".localized(), confirmCallback: (() -> Void)?, cancelMessage: String = "CANCEL".localized(), cancelCallback: (() -> Void)?) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: confirmMessage, style: .default, handler: { (action) in
            confirmCallback?()
        }))
        alert.addAction(UIAlertAction(title: cancelMessage, style: .cancel, handler: { (action) in
            cancelCallback?()
        }))
        vc.present(alert, animated: true, completion: nil)
    }
    
    static func show(_ vc: UIViewController, title: String? = nil, message: String? = nil, confirmCallback: (() -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK".localized(), style: .default, handler: { (action) in
            confirmCallback?()
        }))
        vc.present(alert, animated: true, completion: nil)
    }
    
}
