//
//  PushLocalDeletedChangesOperation.swift
//  Potatso
//
//  Created by LEI on 8/12/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import Foundation
import CloudKit
import PSOperations

class PushLocalDeletedChangesOperation: PushLocalChangesBaseOperation {

    var deletedRecordIDs: [CKRecordID]

    init(zoneID: CKRecordZoneID, name: String? = nil, deletedRecordIDs: [CKRecordID], maximumRetryAttempts: Int = 3) {
        self.deletedRecordIDs = deletedRecordIDs
        super.init(zoneID: zoneID, maximumRetryAttempts: maximumRetryAttempts)
        self.name = name ?? "Push Local Deleted Changes"
    }

    override func pushRecords(_ completionHandler: @escaping (NSError?) -> ()) {
        pushLocalRecords(nil, recordIDsToDelete: deletedRecordIDs, completionHandler: completionHandler)
    }
    
}

