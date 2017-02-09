import Foundation
import CloudKit
import RealmSwift


// MARK: - CloudKit related functions

/**
 Set the `changeToken` for this `zoneID`.
 */
public func setZoneChangeToken(_ zoneID: CKRecordZoneID, changeToken: CKServerChangeToken?) {
    let key = "\(zoneID.zoneName)_serverChangeToken"
    if let changeToken = changeToken {
        UserDefaults.standard.set(
            NSKeyedArchiver.archivedData(withRootObject: changeToken),
            forKey: key)
    } else {
        UserDefaults.standard.removeObject(forKey: key)
    }
    UserDefaults.standard.synchronize()
}

/**
 Get the local change token for this `zoneID` if one exists.
 */
public func getZoneChangeToken(_ zoneID: CKRecordZoneID) -> CKServerChangeToken? {
    let encodedObjectData = UserDefaults.standard.object(forKey: "\(zoneID.zoneName)_serverChangeToken") as? Data
    var decodedData: CKServerChangeToken? = nil
    if encodedObjectData != nil {
        decodedData = NSKeyedUnarchiver.unarchiveObject(with: encodedObjectData!) as? CKServerChangeToken
    }
    return decodedData
}

/**
 Archive the CKRecord to the local database. This data will be used next time
 the updated record is send to CloudKit.
 */
public func recordToLocalData(_ record: CKRecord) -> Data {
    // Archive CKRecord into NSMutableData
    let archivedData = NSMutableData()
    let archiver = NSKeyedArchiver(forWritingWith: archivedData)
    archiver.requiresSecureCoding = true
    record.encodeSystemFields(with: archiver)
    archiver.finishEncoding()
    return archivedData as Data
}

// MARK: - Local database modification


// MARK: - Conflict resolution

/**
    Resolve conflicts between two CKRecords.
    
    Best practice is to perform desired changes on server record and then resend.
 */
public func resolveConflicts(_ error: NSError,
                             completionHandler: (NSError!) -> (),
                             resolver: (CKRecord, _ serverRecord: CKRecord) -> CKRecord) -> [CKRecord]? {
    
    var adjustedRecords = [CKRecord]()
    
    if let errorDict = error.userInfo[CKPartialErrorsByItemIDKey]
        as? [CKRecordID : NSError] {
        
        for (_, partialError) in errorDict {
            let errorCode = CKError(_nsError: NSError(domain: Bundle.main.bundleIdentifier!, code: partialError.code))
            if errorCode.code == CKError.Code.serverRecordChanged {
                let userInfo = partialError.userInfo
                
                guard let serverRecord = userInfo[CKRecordChangedErrorServerRecordKey] as? CKRecord,
                    let ancestorRecord = userInfo[CKRecordChangedErrorAncestorRecordKey] as? CKRecord,
                    let clientRecord = userInfo[CKRecordChangedErrorClientRecordKey] as? CKRecord else {
                        
                        completionHandler(error)
                        // TODO: correctly handle error here
                        return nil
                }
                
                print("Client change tag: \(clientRecord.recordChangeTag)")
                print("Server change tag: \(serverRecord.recordChangeTag)")
                print("Ancestor change tag: \(ancestorRecord.recordChangeTag)")
                
                if serverRecord.recordChangeTag != clientRecord.recordChangeTag {
                    
                    print("Client text: \(clientRecord["text"])")
                    print("Server text: \(serverRecord["text"])")
                    
                    let adjustedRecord = resolver(
                        clientRecord,
                        serverRecord)
                    
                    print("Adjusted text: \(adjustedRecord["text"])")
                    
                    adjustedRecords.append(adjustedRecord)
                    
                } else {
                    completionHandler(error)
                }
            }
        }
    }
    return adjustedRecords
}

public func overwriteFromClient(_ clientRecord: CKRecord, serverRecord: CKRecord) -> CKRecord {
    let adjustedRecord = serverRecord
    for key in clientRecord.allKeys() {
        adjustedRecord[key] = clientRecord[key]
    }
    return adjustedRecord
}


/**
 TODO: implement diff3 conflict resolution using client, server and ancestor records.
 
 https://opensource.apple.com/source/gnudiff/gnudiff-10/diffutils/diff3.c
 */

// MARK: - Helpers

// I can't figure out how to extend realm errors so I'm creating a custom swift error code.
public enum CustomRealmErrorCode: Int {
    case fail
    case fileAccess
    case filePermissionDenied
    case fileExists
    case fileNotFound
    case fileFormatUpgradeRequired
    case incompatibleLockFile
    case addressSpaceExhausted
    case schemaMismatch
}

public func createAlertOperation(_ error: NSError) -> AlertOperation {
    let alert = AlertOperation()
    
    switch error.domain {
    case "io.realm":
        var errorString = "Unknown"
        
        if let rlmErrorCode = CustomRealmErrorCode(rawValue: error.code) {
            errorString = String(describing: rlmErrorCode)
        }
        
        alert.title = "Write Error"
        alert.message =
            "Cannot write data to iPhone." +
            "\n\n" +
            "Error Code: RLMError.\(errorString) (\(error.localizedDescription))"
        
    case CKErrorDomain:
        let ckErrorCode: CKError = CKError(_nsError: NSError(domain: Bundle.main.bundleIdentifier!, code: error.code))
        
        alert.title = "Cloud Error"
        alert.message =
            "Cannot complete sync operation. Try again later." +
            "\n\n" +
            "Error Code: CKError.\(String(describing: ckErrorCode)) (\(error.localizedDescription))"
        
    default:
        alert.title = "Error"
        alert.message = "Cannot complete sync operation. Try again later."
    }
    
    return alert
}

// Extend `CKErrorCode` to provide more descriptive errors to user.
extension CKError: CustomStringConvertible {
    public var description: String {
        switch self.code {
        case .internalError: return "InternalError"
        case .partialFailure: return "PartialFailure"
        case .networkUnavailable: return "NetworkUnavailable"
        case .networkFailure: return "NetworkFailure"
        case .badContainer: return "BadContainer"
        case .serviceUnavailable: return "ServiceUnavailable"
        case .requestRateLimited: return "RequestRateLimited"
        case .missingEntitlement: return "MissingEntitlement"
        case .notAuthenticated: return "NotAuthenticated"
        case .permissionFailure: return "PermissionFailure"
        case .unknownItem: return "UnknownItem"
        case .invalidArguments: return "InvalidArguments"
        case .resultsTruncated: return "ResultsTruncated"
        case .serverRecordChanged: return "ServerRecordChanged"
        case .serverRejectedRequest: return "ServerRejectedRequest"
        case .assetFileNotFound: return "AssetFileNotFound"
        case .assetFileModified: return "AssetFileModified"
        case .incompatibleVersion: return "IncompatibleVersion"
        case .constraintViolation: return "ConstraintViolation"
        case .operationCancelled: return "OperationCancelled"
        case .changeTokenExpired: return "ChangeTokenExpired"
        case .batchRequestFailed: return "BatchRequestFailed"
        case .zoneBusy: return "ZoneBusy"
        case .badDatabase: return "BadDatabase"
        case .quotaExceeded: return "QuotaExceeded"
        case .zoneNotFound: return "ZoneNotFound"
        case .limitExceeded: return "LimitExceeded"
        case .userDeletedZone: return "UserDeletedZone"
        default: return "Un-recognized value"
        }
    }
}
