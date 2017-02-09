//
//  SyncManager.swift
//  Potatso
//
//  Created by LEI on 8/2/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import Foundation
import CloudKit

public enum SyncServiceType: String {
    case None
    case iCloud
}

public protocol SyncServiceProtocol {
    func setup(_ completion: ((Error?) -> Void)?)
    func sync(_ manually: Bool, completion: ((Error?) -> Void)?)
    func stop()
}

open class SyncManager {

    static let shared = SyncManager()

    open static let syncServiceChangedNotification = "syncServiceChangedNotification"
    fileprivate var services: [SyncServiceType: SyncServiceProtocol] = [:]
    fileprivate static let serviceTypeKey = "serviceTypeKey"

    fileprivate(set) var syncing = false

    var currentSyncServiceType: SyncServiceType {
        get {
            if let raw = UserDefaults.standard.object(forKey: SyncManager.serviceTypeKey) as? String, let type = SyncServiceType(rawValue: raw) {
                return type
            }
            return .None
        }
        set(new) {
            guard currentSyncServiceType != new else {
                return
            }
            getCurrentSyncService()?.stop()
            UserDefaults.standard.set(new.rawValue, forKey: SyncManager.serviceTypeKey)
            UserDefaults.standard.synchronize()
            NotificationCenter.default.post(name: Notification.Name(rawValue: SyncManager.syncServiceChangedNotification), object: nil)
        }
    }

    init() {
    }

    func getCurrentSyncService() -> SyncServiceProtocol? {
        return getSyncService(forType: currentSyncServiceType)
    }

    func getSyncService(forType type: SyncServiceType) -> SyncServiceProtocol? {
        if let service = services[type] {
            return service
        }
        let s: SyncServiceProtocol
        switch type {
        case .iCloud:
            s = ICloudSyncService()
        default:
            return nil
        }
        services[type] = s
        return s
    }

    func showSyncVC(inVC vc:UIViewController? = nil) {
        guard let currentVC = vc ?? UIApplication.shared.keyWindow?.rootViewController else {
            return
        }
        let syncVC = SyncVC()
        currentVC.show(syncVC, sender: self)
    }

}

extension SyncManager {

    func setupNewService(_ type: SyncServiceType, completion: ((Error?) -> Void)?) {
        if let service = getSyncService(forType: type) {
            service.setup(completion)
        } else {
            completion?(nil)
        }
    }

    func setup(_ completion: ((Error?) -> Void)?) {
        getCurrentSyncService()?.setup(completion)
    }

    func sync(_ manually: Bool = false, completion: ((Error?) -> Void)? = nil) {
        if let service = getCurrentSyncService() {
            syncing = true
            NotificationCenter.default.post(name: Notification.Name(rawValue: SyncManager.syncServiceChangedNotification), object: nil)
            service.sync(manually) { [weak self] error in
                self?.syncing = false
                NotificationCenter.default.post(name: Notification.Name(rawValue: SyncManager.syncServiceChangedNotification), object: nil)
                completion?(error)
            }
        }
    }
    
}
