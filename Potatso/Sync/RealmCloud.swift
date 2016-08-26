import Foundation
import CloudKit
import RealmSwift


// MARK: - CloudKit related functions

/**
 Set the `changeToken` for this `zoneID`.
 */
public func setZoneChangeToken(zoneID: CKRecordZoneID, changeToken: CKServerChangeToken?) {
    let key = "\(zoneID.zoneName)_serverChangeToken"
    if let changeToken = changeToken {
        NSUserDefaults.standardUserDefaults().setObject(
            NSKeyedArchiver.archivedDataWithRootObject(changeToken),
            forKey: key)
    } else {
        NSUserDefaults.standardUserDefaults().removeObjectForKey(key)
    }
    NSUserDefaults.standardUserDefaults().synchronize()
}

/**
 Get the local change token for this `zoneID` if one exists.
 */
public func getZoneChangeToken(zoneID: CKRecordZoneID) -> CKServerChangeToken? {
    let encodedObjectData = NSUserDefaults.standardUserDefaults().objectForKey("\(zoneID.zoneName)_serverChangeToken") as? NSData
    var decodedData: CKServerChangeToken? = nil
    if encodedObjectData != nil {
        decodedData = NSKeyedUnarchiver.unarchiveObjectWithData(encodedObjectData!) as? CKServerChangeToken
    }
    return decodedData
}

/**
 Archive the CKRecord to the local database. This data will be used next time
 the updated record is send to CloudKit.
 */
public func recordToLocalData(record: CKRecord) -> NSData {
    // Archive CKRecord into NSMutableData
    let archivedData = NSMutableData()
    let archiver = NSKeyedArchiver(forWritingWithMutableData: archivedData)
    archiver.requiresSecureCoding = true
    record.encodeSystemFieldsWithCoder(archiver)
    archiver.finishEncoding()
    return archivedData
}

// MARK: - Local database modification


// MARK: - Conflict resolution

/**
    Resolve conflicts between two CKRecords.
    
    Best practice is to perform desired changes on server record and then resend.
 */
public func resolveConflicts(error: NSError,
                             completionHandler: (NSError!) -> (),
                             resolver: (CKRecord, serverRecord: CKRecord) -> CKRecord) -> [CKRecord]? {
    
    var adjustedRecords = [CKRecord]()
    
    if let errorDict = error.userInfo[CKPartialErrorsByItemIDKey]
        as? [CKRecordID : NSError] {
        
        for (_, partialError) in errorDict {
            let errorCode = CKErrorCode(rawValue: partialError.code)
            if errorCode == .ServerRecordChanged {
                let userInfo = partialError.userInfo
                
                guard let serverRecord = userInfo[CKRecordChangedErrorServerRecordKey] as? CKRecord,
                    ancestorRecord = userInfo[CKRecordChangedErrorAncestorRecordKey] as? CKRecord,
                    clientRecord = userInfo[CKRecordChangedErrorClientRecordKey] as? CKRecord else {
                        
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
                        serverRecord: serverRecord)
                    
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

public func overwriteFromClient(clientRecord: CKRecord, serverRecord: CKRecord) -> CKRecord {
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
    case Fail
    case FileAccess
    case FilePermissionDenied
    case FileExists
    case FileNotFound
    case FileFormatUpgradeRequired
    case IncompatibleLockFile
    case AddressSpaceExhausted
    case SchemaMismatch
}

public func createAlertOperation(error: NSError) -> AlertOperation {
    let alert = AlertOperation()
    
    switch error.domain {
    case "io.realm":
        var errorString = "Unknown"
        
        if let rlmErrorCode = CustomRealmErrorCode(rawValue: error.code) {
            errorString = String(rlmErrorCode)
        }
        
        alert.title = "Write Error"
        alert.message =
            "Cannot write data to iPhone." +
            "\n\n" +
            "Error Code: RLMError.\(errorString) (\(error.localizedDescription))"
        
    case CKErrorDomain:
        let ckErrorCode: CKErrorCode = CKErrorCode(rawValue: error.code)!
        
        alert.title = "Cloud Error"
        alert.message =
            "Cannot complete sync operation. Try again later." +
            "\n\n" +
            "Error Code: CKError.\(String(ckErrorCode)) (\(error.localizedDescription))"
        
    default:
        alert.title = "Error"
        alert.message = "Cannot complete sync operation. Try again later."
    }
    
    return alert
}

// Extend `CKErrorCode` to provide more descriptive errors to user.
extension CKErrorCode: CustomStringConvertible {
    public var description: String {
        switch self {
        case InternalError: return "InternalError"
        case PartialFailure: return "PartialFailure"
        case NetworkUnavailable: return "NetworkUnavailable"
        case NetworkFailure: return "NetworkFailure"
        case BadContainer: return "BadContainer"
        case ServiceUnavailable: return "ServiceUnavailable"
        case RequestRateLimited: return "RequestRateLimited"
        case MissingEntitlement: return "MissingEntitlement"
        case NotAuthenticated: return "NotAuthenticated"
        case PermissionFailure: return "PermissionFailure"
        case UnknownItem: return "UnknownItem"
        case InvalidArguments: return "InvalidArguments"
        case ResultsTruncated: return "ResultsTruncated"
        case ServerRecordChanged: return "ServerRecordChanged"
        case ServerRejectedRequest: return "ServerRejectedRequest"
        case AssetFileNotFound: return "AssetFileNotFound"
        case AssetFileModified: return "AssetFileModified"
        case IncompatibleVersion: return "IncompatibleVersion"
        case ConstraintViolation: return "ConstraintViolation"
        case OperationCancelled: return "OperationCancelled"
        case ChangeTokenExpired: return "ChangeTokenExpired"
        case BatchRequestFailed: return "BatchRequestFailed"
        case ZoneBusy: return "ZoneBusy"
        case BadDatabase: return "BadDatabase"
        case QuotaExceeded: return "QuotaExceeded"
        case ZoneNotFound: return "ZoneNotFound"
        case LimitExceeded: return "LimitExceeded"
        case UserDeletedZone: return "UserDeletedZone"
        }
    }
}
