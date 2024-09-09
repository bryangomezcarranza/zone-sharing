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
    let author: String
    let associatedRecord: CKRecord
}

extension Post {
    init?(record: CKRecord) {
        guard let message = record["message"] as? String,
              let author = record["author"] as? String else {
            return nil
        }
        
        self.id = record.recordID.recordName
        self.message = message
        self.author = author
        self.associatedRecord = record
    }
}
