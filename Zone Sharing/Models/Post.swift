//
//  Post.swift
//  Zone Sharing
//
//  Created by Bryan Gomez on 9/6/24.
//

import Foundation
import CloudKit

struct Post: Identifiable {
    let id: String
    let message: String
    let associatedRecord: CKRecord
}

extension Post {
    init?(record: CKRecord) {
        guard let message = record["message"] as? String else { return nil }
        
        self.id = record.recordID.recordName
        self.message = message
        self.associatedRecord = record
    }
}
