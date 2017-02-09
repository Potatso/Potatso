//
//  LoggerUtils.swift
//  Potatso
//
//  Created by LEI on 6/21/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import Foundation

extension Error {

    func log(_ message: String?) {
        if let message = message {
            DDLogError("\(message): \(self)")
        }else {
            DDLogError("\(self)")
        }
    }

}
