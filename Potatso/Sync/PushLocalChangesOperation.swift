//
//  PushLocalChangesOperation.swift
//  Potatso
//
//  Created by LEI on 8/12/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import Foundation
import PSOperations
import CloudKit

class PushLocalChangesOperation: PSOperations.Operation {

    let zoneID: CKRecordZoneID
    fileprivate let internalQueue = PSOperations.OperationQueue()
    var toSaveRecords: [CKRecord] = []
    var toDeleteRecordIDs: [CKRecordID] = []
    var maxRecordsPerRequest = 400

    init(zoneID: CKRecordZoneID) {
        self.zoneID = zoneID
        super.init()
        internalQueue.maxConcurrentOperationCount = 15
    }

    override func execute() {
        DDLogInfo(">>>>>> Start Push Local Changes...")
        let toSaveObjects = DBUtils.allObjectsToSyncModified()
        let toDeleteObjects = DBUtils.allObjectsToSyncDeleted()
        toSaveRecords = toSaveObjects.map {
            ($0 as! CloudKitRecord).toCloudKitRecord()
        }
        toDeleteRecordIDs = toDeleteObjects.map {
            ($0 as! CloudKitRecord).recordId
        }
        DDLogInfo("toSaveRecords: \(toSaveRecords.count), toDeleteRecordIDs: \(toDeleteRecordIDs.count)")
        let finishObserver = BlockObserver { operation, errors in
            self.finish(errors)
            return
        }
        let finishOp = PSOperations.BlockOperation {}
        finishOp.addObserver(finishObserver)
        if toSaveRecords.count > maxRecordsPerRequest {
            let total = toSaveRecords.count/maxRecordsPerRequest + 1
            for i in 0..<total {
                let start = i * maxRecordsPerRequest
                let end = min((i + 1) * maxRecordsPerRequest, toSaveRecords.count)
                let records = Array(toSaveRecords[start..<end])
                let op = addModifiedOperation("Push Local Modified Changes <\(i)/\(total), count: \(records.count)>", records: records)
                internalQueue.addOperation(op)
                finishOp.addDependency(op)
            }
        } else {
            let op = addModifiedOperation("Push Local Modified Changes<count: \(toSaveRecords.count)>", records: toSaveRecords)
            internalQueue.addOperation(op)
            finishOp.addDependency(op)
        }
        if toDeleteRecordIDs.count > maxRecordsPerRequest {
            let total = toDeleteRecordIDs.count/maxRecordsPerRequest + 1
            for i in 0..<total {
                let start = i * maxRecordsPerRequest
                let end = min((i + 1) * maxRecordsPerRequest, toDeleteRecordIDs.count)
                let recordIDs = Array(toDeleteRecordIDs[start..<end])
                let op = addDeletedOperation("Push Local Deleted Changes <\(i)/\(total), count: \(recordIDs.count)>", recordIDs: recordIDs)
                internalQueue.addOperation(op)
                finishOp.addDependency(op)
            }
        } else {
            let op = addDeletedOperation("Push Local Deleted Changes<count: \(toDeleteRecordIDs.count)>", recordIDs: toDeleteRecordIDs)
            internalQueue.addOperation(op)
            finishOp.addDependency(op)
        }
        internalQueue.addOperation(finishOp)
    }

    func addModifiedOperation(_ name: String, records: [CKRecord]) -> PSOperations.Operation {
        let op = PushLocalModifiedChangesOperation(zoneID: potatsoZoneId, name: name, modifiedRecords: records)
        return op
    }

    func addDeletedOperation(_ name: String, recordIDs: [CKRecordID]) -> PSOperations.Operation {
        let op = PushLocalDeletedChangesOperation(zoneID: potatsoZoneId, name: name, deletedRecordIDs: recordIDs)
        return op
    }

}
