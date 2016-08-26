import Foundation
import RealmSwift
import CloudKit
import PSOperations

class PushLocalChangesBaseOperation: Operation {
    
    let zoneID: CKRecordZoneID

    let delayOperationQueue = OperationQueue()
    let maximumRetryAttempts: Int
    var retryAttempts: Int = 0
    var finishObserver: BlockObserver!

    init(zoneID: CKRecordZoneID, maximumRetryAttempts: Int = 3) {
        self.zoneID = zoneID
        self.maximumRetryAttempts = maximumRetryAttempts
        super.init()
        self.name = "Push Local Changes"
        self.finishObserver = BlockObserver { [unowned self] operation, errors in
            if let error = errors.first {
                DDLogError("<<<<<< \(self.name!) finished with error: \(error)")
            } else {
                DDLogInfo("<<<<<< \(self.name!) finished")
            }
            return
        }
        self.addObserver(finishObserver)
    }
    
    override func execute() {
        DDLogInfo(">>>>>> \(self.name!) starting...")
        pushRecords { [weak self] (error) in
            self?.finishWithError(error)
            return
        }
    }

    func pushRecords(completionHandler: (NSError?) -> ()) {

    }

    func pushLocalRecords(recordsToSave: [CKRecord]?, recordIDsToDelete: [CKRecordID]?, completionHandler: (NSError?) -> ()) {
        let modifyOperation = CKModifyRecordsOperation(recordsToSave: recordsToSave, recordIDsToDelete: recordIDsToDelete)
        modifyOperation.savePolicy = .ChangedKeys
        modifyOperation.modifyRecordsCompletionBlock = {
            (savedRecords, deletedRecordIDs, nsError) -> Void in
            if let error = nsError {
                DDLogError("\(self.name!) error: \(error)")
                self.handleCloudKitPushError(savedRecords, deletedRecordIDs: deletedRecordIDs, error: error, completionHandler: completionHandler)
            } else {
                do {
                    // Update local modified flag
                    if let savedRecords = savedRecords {
                        for record in savedRecords {
                            try DBUtils.mark(record.recordID.recordName, type: record.realmClassType!, synced: true)
                        }
                    }
                    if let recordIDsToDelete = recordIDsToDelete {
                        for recordID in recordIDsToDelete {
                            try deleteLocalRecord(recordID)
                        }
                    }
                } catch let realmError as NSError {
                    self.finishWithError(realmError)
                }
                completionHandler(nsError)
            }
        }
        modifyOperation.start()
    }
    
    // MARK: - Error Handling
    
    /**
     Implement custom logic here for handling CloudKit push errors.
     */
    func handleCloudKitPushError(savedRecords: [CKRecord]?, deletedRecordIDs: [CKRecordID]?, error: NSError, completionHandler: (NSError?) -> ()) {
        let ckErrorCode: CKErrorCode = CKErrorCode(rawValue: error.code)!
        switch ckErrorCode {
        case .PartialFailure:
            resolvePushConflictsAndRetry(savedRecords, deletedRecordIDs: deletedRecordIDs, error: error, completionHandler: completionHandler)
            
        case .LimitExceeded:
            completionHandler(error)

        case .ZoneBusy, .RequestRateLimited, .ServiceUnavailable, .NetworkFailure, .NetworkUnavailable, .ResultsTruncated:
            // Retry necessary
            retryPush(error, retryAfter: parseRetryTime(error), completionHandler: completionHandler)
            
        case .BadDatabase, .InternalError, .BadContainer, .MissingEntitlement,
             .ConstraintViolation, .IncompatibleVersion, .AssetFileNotFound,
             .AssetFileModified, .InvalidArguments, .UnknownItem,
             .PermissionFailure, .ServerRejectedRequest:
            // Developer issue
            completionHandler(error)
            
        case .QuotaExceeded, .OperationCancelled:
            // User issue. Provide alert.
            completionHandler(error)
            
        case .BatchRequestFailed, .ServerRecordChanged:
            // Not possible for push operation (I think) only possible for
            // individual records within the userInfo dictionary of a PartialFailure
            completionHandler(error)
            
        case .NotAuthenticated:
            // Handled as condition of SyncOperation
            // TODO: add logic to retry entire operation
            completionHandler(error)
            
        case .ZoneNotFound, .UserDeletedZone:
            // Handled in PrepareZoneOperation.
            // TODO: add logic to retry entire operation
            completionHandler(error)
            
        case .ChangeTokenExpired:
            // TODO: Determine correct handling
            completionHandler(error)
        }
    }

    func resolvePushConflictsAndRetry(savedRecords: [CKRecord]?, deletedRecordIDs: [CKRecordID]?, error: NSError, completionHandler: (NSError?) -> ()) {
        let adjustedRecords = resolveConflicts(error, completionHandler: completionHandler, resolver: overwriteFromClient)
        pushLocalRecords(adjustedRecords, recordIDsToDelete: deletedRecordIDs, completionHandler: completionHandler)
    }
    
    // MARK: - Retry
    
    // Wait a default of 3 seconds
    func parseRetryTime(error: NSError) -> Double {
        var retrySecondsDouble: Double = 3
        if let retrySecondsString = error.userInfo[CKErrorRetryAfterKey] as? String {
            retrySecondsDouble = Double(retrySecondsString)!
        }
        return retrySecondsDouble
    }
    
    /**
     After `maximumRetryAttempts` this function will return an error.
     */
    func retryPush(error: NSError, retryAfter: Double, completionHandler: (NSError?) -> ()) {
        if retryAttempts < maximumRetryAttempts {
            retryAttempts += 1
            let delayOperation = DelayOperation(interval: retryAfter)
            let finishObserver = BlockObserver { operation, error in
                self.pushRecords(completionHandler)
            }
            delayOperation.addObserver(finishObserver)
            delayOperationQueue.addOperation(delayOperation)
        } else {
            completionHandler(error)
        }
    }

    
}