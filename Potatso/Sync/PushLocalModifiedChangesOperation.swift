//
//  PushLocalModifiedChangesOperation.swift
//  Potatso
//
//  Created by LEI on 8/12/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import Foundation
import CloudKit
import PSOperations

class PushLocalModifiedChangesOperation: PushLocalChangesBaseOperation {

    var recordsToSave: [CKRecord]

    init(zoneID: CKRecordZoneID, name: String? = nil, modifiedRecords: [CKRecord], maximumRetryAttempts: Int = 3) {
        self.recordsToSave = modifiedRecords
        super.init(zoneID: zoneID, maximumRetryAttempts: maximumRetryAttempts)
        self.name = name ?? "Push Local Modified Changes"
    }

    override func pushRecords(_ completionHandler: @escaping (NSError?) -> ()) {
        pushLocalRecords(recordsToSave, recordIDsToDelete: nil, completionHandler: completionHandler)
    }

}
