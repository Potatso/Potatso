import Foundation
import RealmSwift
import CloudKit
import PSOperations

struct FetchResults {
    var changedRecords: [CKRecord] = []
    var deletedRecordIDs: [CKRecordID] = []
    
    var count: Int {
        return changedRecords.count + deletedRecordIDs.count
    }
}

class FetchCloudChangesOperation: Operation {
    
    let zoneID: CKRecordZoneID
    var changeToken: CKServerChangeToken?
    
    let delayOperationQueue = OperationQueue()
    let maximumRetryAttempts: Int
    var retryAttempts: Int = 0

    init(zoneID: CKRecordZoneID, maximumRetryAttempts: Int = 3) {
        self.zoneID = zoneID
        self.maximumRetryAttempts = maximumRetryAttempts
        super.init()
        name = "Fetch Cloud Changes"
    }
    
    override func execute() {
        changeToken = getZoneChangeToken(zoneID)
        DDLogInfo(">>> \(self.name!) started with token: \(changeToken)")
        fetchCloudChanges(changeToken) {
            (nsError) in
            self.finishWithError(nsError)
        }
    }
    
    func fetchCloudChanges(changeToken: CKServerChangeToken?,
                           completionHandler: (NSError!) -> ()) {
        
        let fetchOperation = CKFetchRecordChangesOperation(recordZoneID: zoneID, previousServerChangeToken: changeToken)
        fetchOperation.resultsLimit = CKQueryOperationMaximumResults
        var results = FetchResults()
        
        // Enable resultsLimit to test moreComing
        // fetchOperation.resultsLimit = 10
        
        fetchOperation.recordChangedBlock = {
            (record) in
            results.changedRecords.append(record)
        }
        
        fetchOperation.recordWithIDWasDeletedBlock = {
            (recordID) in
            results.deletedRecordIDs.append(recordID)
        }

        fetchOperation.database = potatsoDB
        fetchOperation.recordZoneID = potatsoZoneId
        
        fetchOperation.fetchRecordChangesCompletionBlock = {
            (serverChangeToken, clientChangeToken, nsError) in
            
            if let error = nsError {
                self.handleCloudKitFetchError(error, completionHandler: completionHandler)
                
            } else {
                
                // Ensure no errors processing the fetch before updating the local change token
                let writeError = self.processFetchResults(results)
                
                if let writeError = writeError {
                    self.finishWithError(writeError)
                    
                } else {
                    setZoneChangeToken(self.zoneID, changeToken: serverChangeToken)
                    self.changeToken = serverChangeToken
                    
                    if fetchOperation.moreComing {
                        DDLogInfo("\(self.name!) more coming...")
                        self.fetchCloudChanges(self.changeToken,
                                               completionHandler: completionHandler)
                    } else {
                        completionHandler(nsError)
                    }
                }
            }
        }
        fetchOperation.start()
    }
    
    func processFetchResults(results: FetchResults) -> NSError? {
        var error: NSError?
        
        do {
            DDLogInfo("****** \(self.name!) processFetchResults changedRecords: \(results.changedRecords.count)")
            for record in results.changedRecords {
                try changeLocalRecord(record)
            }

            DDLogInfo("****** \(self.name!) processFetchResults deletedRecordIDs: \(results.deletedRecordIDs.count)")
            for recordID in results.deletedRecordIDs {
                try deleteLocalRecord(recordID)
            }
        } catch let realmError as NSError {
            error = realmError
            DDLogError("****** \(self.name!) processFetchResults error: \(error)")
        }

        return error
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
    
    // After `maximumRetryAttempts` this function will return an error
    func retryFetch(error: NSError, retryAfter: Double, completionHandler: (NSError!) -> ()) {
        if self.retryAttempts < self.maximumRetryAttempts {
            self.retryAttempts += 1
            
            let delayOperation = DelayOperation(interval: retryAfter)
            let finishObserver = BlockObserver { operation, error in
                self.fetchCloudChanges(self.changeToken, completionHandler: completionHandler)
            }
            delayOperation.addObserver(finishObserver)
            delayOperationQueue.addOperation(delayOperation)
        } else {
            completionHandler(error)
        }
    }
    
    // MARK: - Error Handling
    
    /**
     Implement custom logic here for handling CloudKit fetch errors.
     */
    func handleCloudKitFetchError(error: NSError, completionHandler: (NSError!) -> ()) {
        let ckErrorCode: CKErrorCode = CKErrorCode(rawValue: error.code)!
        
        switch ckErrorCode {
        case .ZoneBusy, .RequestRateLimited, .ServiceUnavailable, .NetworkFailure, .NetworkUnavailable, .ResultsTruncated:
            // Retry necessary
            retryFetch(error, retryAfter: parseRetryTime(error), completionHandler: completionHandler)
            
        case .BadDatabase, .InternalError, .BadContainer, .MissingEntitlement,
             .ConstraintViolation, .IncompatibleVersion, .AssetFileNotFound,
             .AssetFileModified, .InvalidArguments,
             .PermissionFailure, .ServerRejectedRequest:
            // Developer issue
            completionHandler(error)
            
        case .UnknownItem:
            // Developer issue
            // - Never delete CloudKit Record Types.
            // - This issue will arise if you created some records of this type
            //   and then deleted the type. Even if the records were also deleted,
            //   you must keep the type around because deleted recordIDs are stored
            //   along with type information. When fetching, this is unfortunately
            //   checked.
            // - A possible hack is to save a new record with the missing record type
            //   name. This works because field information is not saved on deleted
            //   record IDs. Unfortunately you might accidentally overwrite an existing
            //   record type which will lead to further errors.
            completionHandler(error)
            
        case .QuotaExceeded, .OperationCancelled:
            // User issue. Provide alert.
            completionHandler(error)
            
        case .LimitExceeded, .PartialFailure, .ServerRecordChanged,
             .BatchRequestFailed:
            // Not possible in a fetch operation (I think).
            completionHandler(error)
            
        case .NotAuthenticated:
            // Handled as condition of sync operation.
            completionHandler(error)
            
        case .ZoneNotFound, .UserDeletedZone:
            // Handled in PrepareZoneOperation.
            completionHandler(error)
            
        case .ChangeTokenExpired:
            // TODO: Determine correct handling
            // CK Docs: The previousServerChangeToken value is too old and the client must re-sync from scratch
            SyncManager.shared.sync(true)
        }
    }
}
