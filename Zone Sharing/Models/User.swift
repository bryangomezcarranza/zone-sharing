//
//  User.swift
//  Zone Sharing
//
//  Created by Bryan Gomez on 9/6/24.
//

import Foundation
import CloudKit

struct User {
    let zone: CKRecordZone
    let post: [Post]
    
    var name: String {
        zone.zoneID.zoneName
    }
}

extension User: Identifiable {
    var id: String {
        name
    }
}
