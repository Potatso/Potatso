//
//  ICloudSyncService.swift
//  Potatso
//
//  Created by LEI on 8/2/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import Foundation
import CloudKit
import PSOperations
import PotatsoModel
import Async

class ICloudSyncService: SyncServiceProtocol {

    let operationQueue = PSOperations.OperationQueue()

    init() {

    }

    func setup(_ completion: ((Error?) -> Void)?) {
        DDLogInfo(">>>>>> Setuping iCloud sync service")
        let setupOp = ICloudSetupOperation { [weak self] (error) in
            if let e = error {
                DDLogError(">>>>>> Setuping iCloud sync service with error: \(e)")
            } else {
                DDLogInfo(">>>>>> Setuping iCloud sync service with success")
                self?.subscribeNotification()
            }
            completion?(error)
        }
        operationQueue.addOperation(setupOp)
    }

    func sync(_ manually: Bool = false, completion: ((Error?) -> Void)?) {
        DDLogInfo(">>>>>>>>>> iCloud sync start")
        if manually {
            DDLogWarn("Manually sync: clear token and mark all as not synced")
            setZoneChangeToken(potatsoZoneId, changeToken: nil)
            _ = try? DBUtils.markAll(syncd: false)
        }

        let pushLocalChangesOperation = PushLocalChangesOperation(zoneID: potatsoZoneId)
        let pushLocalChangesObserver = BlockObserver { [weak self] operation, error in
            if let _ = error.first {
                DDLogError("<<< pushLocalChangesOperation finished with error: \(error)")
            } else {
                DDLogInfo("<<< pushLocalChangesOperation finished with success")
            }
            self?.finishSync(error.first, completion: completion)
        }
        pushLocalChangesOperation.addObserver(pushLocalChangesObserver)

        let fetchCloudChangesOperation = FetchCloudChangesOperation(zoneID: potatsoZoneId)
        let fetchCloudChangesObserver = BlockObserver { [weak self] operation, error in
            if let error = error.first {
                DDLogError("<<< fetchCloudChangesOperation finished with error: \(error)")
                self?.finishSync(error, completion: completion)
                return
            } else {
                DDLogInfo("<<< fetchCloudChangesOperation finished with success")
            }
            self?.operationQueue.addOperation(pushLocalChangesOperation)
        }
        fetchCloudChangesOperation.addObserver(fetchCloudChangesObserver)

        setup { [weak self] (error) in
            if let error = error {
                self?.finishSync(error, completion: completion)
                return
            } else {
                self?.operationQueue.addOperation(fetchCloudChangesOperation)
            }
        }
    }

    func finishSync(_ error: Error?, completion: ((Error?) -> Void)?) {
        if let error = error {
            DDLogInfo("<<<<<<<<<< iCloud sync finished with error: \(error)")
        } else {
            DDLogInfo("<<<<<<<<<< iCloud sync finished with success")
        }
        Async.main {
            completion?(error)
        }
    }

    func subscribeNotification() {
        DDLogInfo("subscribing cloudkit database changes...")
        let subscription = CKSubscription(zoneID: potatsoZoneId, subscriptionID: potatsoSubscriptionId, options: CKSubscriptionOptions(rawValue: 0))
        let info = CKNotificationInfo()
        info.shouldSendContentAvailable = true
        subscription.notificationInfo = info
        potatsoDB.save(subscription, completionHandler: { (sub, error) in
            if let error = error {
                DDLogError("subscribe cloudkit database changes error: \(error.localizedDescription)")
            } else {
                DDLogInfo("subscribe cloudkit database changes success")
            }
        }) 
    }

    func unsubscribeNotification() {
        DDLogInfo("unsubscribing cloudkit database changes...")
        potatsoDB.delete(withSubscriptionID: potatsoSubscriptionId) { (id, error) in
            if let error = error {
                DDLogError("unsubscribe cloudkit database changes error: \(error.localizedDescription)")
            } else {
                DDLogInfo("unsubscribe cloudkit database changes success")
            }
        }
    }

    func stop() {
        unsubscribeNotification()
    }

}
