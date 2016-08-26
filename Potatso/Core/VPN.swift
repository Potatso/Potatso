//
//  ProxyService.swift
//  Potatso
//
//  Created by LEI on 12/28/15.
//  Copyright © 2015 TouchingApp. All rights reserved.
//

import Foundation
import Async
import PotatsoModel
import Appirater
import PotatsoLibrary

class VPN {
    
    static func switchVPN(group: ConfigurationGroup, completion: ((ErrorType?) -> Void)? = nil) {
        let defaultUUID = Manager.sharedManager.defaultConfigGroup.uuid
        let isDefault = defaultUUID == group.uuid
        if !isDefault {
            Manager.sharedManager.stopVPN()
            Async.main(after: 1) {
                _switchDefaultVPN(group, completion: completion)
            }
        }else {
            _switchDefaultVPN(group, completion: completion)
        }
    }

    private static func _switchDefaultVPN(group: ConfigurationGroup, completion: ((ErrorType?) -> Void)? = nil) {
        Manager.sharedManager.setDefaultConfigGroup(group.uuid, name: group.name)
        Manager.sharedManager.switchVPN { (manager, error) in
            if let _ = manager {
                Async.background(after: 2, block: { () -> Void in
                    Appirater.userDidSignificantEvent(false)
                })
            }
            Async.main{
                completion?(error)
            }
        }
    }
    
}
