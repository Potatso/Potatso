import Foundation
import RealmSwift
import CloudKit
import PSOperations

class PushLocalChangesBaseOperation: PSOperations.Operation {
    
    let zoneID: CKRecordZoneID

    let delayOperationQueue = PSOperations.OperationQueue()
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

    func pushRecords(_ completionHandler: @escaping (NSError?) -> ()) {

    }

    func pushLocalRecords(_ recordsToSave: [CKRecord]?, recordIDsToDelete: [CKRecordID]?, completionHandler: @escaping (NSError?) -> ()) {
        let modifyOperation = CKModifyRecordsOperation(recordsToSave: recordsToSave, recordIDsToDelete: recordIDsToDelete)
        modifyOperation.savePolicy = .changedKeys
        modifyOperation.modifyRecordsCompletionBlock = {
            (savedRecords, deletedRecordIDs, nsError) -> Void in
            if let error = nsError {
                DDLogError("\(self.name!) error: \(error)")
                self.handleCloudKitPushError(savedRecords, deletedRecordIDs: deletedRecordIDs, error: error as NSError, completionHandler: completionHandler)
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
                completionHandler(nsError as NSError?)
            }
        }
        modifyOperation.start()
    }
    
    // MARK: - Error Handling
    
    /**
     Implement custom logic here for handling CloudKit push errors.
     */
    func handleCloudKitPushError(_ savedRecords: [CKRecord]?, deletedRecordIDs: [CKRecordID]?, error: NSError, completionHandler: @escaping (NSError?) -> ()) {
        let ckErrorCode: CKError = CKError(_nsError: NSError(domain: Bundle.main.bundleIdentifier!, code: error.code))
        switch ckErrorCode.code {
        case .partialFailure:
            resolvePushConflictsAndRetry(savedRecords, deletedRecordIDs: deletedRecordIDs, error: error, completionHandler: completionHandler)
            
        case .limitExceeded:
            completionHandler(error)

        case .zoneBusy, .requestRateLimited, .serviceUnavailable, .networkFailure, .networkUnavailable, .resultsTruncated:
            // Retry necessary
            retryPush(error, retryAfter: parseRetryTime(error), completionHandler: completionHandler)
            
        case .badDatabase, .internalError, .badContainer, .missingEntitlement,
             .constraintViolation, .incompatibleVersion, .assetFileNotFound,
             .assetFileModified, .invalidArguments, .unknownItem,
             .permissionFailure, .serverRejectedRequest:
            // Developer issue
            completionHandler(error)
            
        case .quotaExceeded, .operationCancelled:
            // User issue. Provide alert.
            completionHandler(error)
            
        case .batchRequestFailed, .serverRecordChanged:
            // Not possible for push operation (I think) only possible for
            // individual records within the userInfo dictionary of a PartialFailure
            completionHandler(error)
            
        case .notAuthenticated:
            // Handled as condition of SyncOperation
            // TODO: add logic to retry entire operation
            completionHandler(error)
            
        case .zoneNotFound, .userDeletedZone:
            // Handled in PrepareZoneOperation.
            // TODO: add logic to retry entire operation
            completionHandler(error)
            
        case .changeTokenExpired:
            // TODO: Determine correct handling
            completionHandler(error)
            
        default: break 
        }
    }

    func resolvePushConflictsAndRetry(_ savedRecords: [CKRecord]?, deletedRecordIDs: [CKRecordID]?, error: NSError, completionHandler: @escaping (NSError?) -> ()) {
        let adjustedRecords = resolveConflicts(error, completionHandler: completionHandler, resolver: overwriteFromClient)
        pushLocalRecords(adjustedRecords, recordIDsToDelete: deletedRecordIDs, completionHandler: completionHandler)
    }
    
    // MARK: - Retry
    
    // Wait a default of 3 seconds
    func parseRetryTime(_ error: NSError) -> Double {
        var retrySecondsDouble: Double = 3
        if let retrySecondsString = error.userInfo[CKErrorRetryAfterKey] as? String {
            retrySecondsDouble = Double(retrySecondsString)!
        }
        return retrySecondsDouble
    }
    
    /**
     After `maximumRetryAttempts` this function will return an error.
     */
    func retryPush(_ error: NSError, retryAfter: Double, completionHandler: @escaping (NSError?) -> ()) {
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
