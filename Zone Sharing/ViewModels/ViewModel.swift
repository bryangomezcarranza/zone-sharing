//
//  ViewModel.swift
//  Zone Sharing
//
//  Created by Bryan Gomez on 9/6/24.
//

import Foundation
import CloudKit

@MainActor
final class ViewModel: ObservableObject {
    
    //MARK: - Error
    
    enum ViewModelError: Error {
        case invalidRemoteShare
    }
    
    //MARK: - State
    
    enum State {
        case loading
        case loaded(privateUsers: [User], shareUsers: [User])
        case error(Error)
    }
    
    //MARK: - Properties
    
    /// State directly observed by view
    @Published private(set) var state: State = .loading
    /// Uses iCloud container ID
    lazy var container = CKContainer(identifier: Config.containerIndetifier)
    ///Project uses user private data base
    private lazy var database = container.privateCloudDatabase
    
    let defaultZoneName = "DefaultPostZone"
    //MARK: - init
    
    nonisolated init() {}
    
    /// For previews
    init(state: State) {
        self.state = state
    }
    
    //MARK: - API Calls
    
    /// Updates posts from the remote database and updates local state
    func refresh() async throws {
        state = .loading
        do {
            let (privatePosts, sharedPosts) = try await fetchPrivateAndSharedPosts()
            state = .loaded(privateUsers: privatePosts, shareUsers: sharedPosts)
        } catch {
            state = .error(error)
        }
    }
    
    /// Fetches both private and shared posts
    /// - Returns: A tuple containing seperated private and shared posts
    func fetchPrivateAndSharedPosts() async throws -> (private: [User], shared: [User]) {
        // Determine zones for each set of posts
        // In the private DB, we want to ignore the default zone.
        let privateZones = try await database.allRecordZones().filter({ $0.zoneID != CKRecordZone.default().zoneID })
        let sharedZones = try await container.sharedCloudDatabase.allRecordZones()
        
        // Runs operations in parallel
        async let privatePosts = fetchPosts(scope: .private, in: privateZones)
        async let sharedPosts = fetchPosts(scope: .shared, in: sharedZones)
        
        return (private: try await privatePosts, shared: try await sharedPosts)
        
    }
    
    func addContact(message: String) async throws {
        do {
            // Ensure zone exists first
            let zone = CKRecordZone(zoneName: defaultZoneName)
            try await database.save(zone)
            
            let id = CKRecord.ID(zoneID: zone.zoneID)
            let postRecord = CKRecord(recordType: "SharedPost", recordID: id)
            postRecord["message"] = message
            
            try await database.save(postRecord)
            
        } catch {
            debugPrint("Error: Failed to save new post: \(error)")
            throw error 
        }
    }
    
    func fetchOrCreateShare(post: User) async throws -> (CKShare, CKContainer) {
        guard let existingShare = post.zone.share else {
            let share = CKShare(recordZoneID: post.zone.zoneID)
            share[CKShare.SystemFieldKey.title] = "User: \(post.name)"
            _ = try await database.modifyRecords(saving: [share], deleting: [])
            return (share, container)
        }
        
        guard let share = try await database.record(for: existingShare.recordID) as? CKShare else {
            throw ViewModelError.invalidRemoteShare
        }
        
        return (share, container)
    }
    
    //MARK: -  Private
    
    func fetchPosts(scope: CKDatabase.Scope, in zones: [CKRecordZone]) async throws -> [User] {
        guard !zones.isEmpty else { return [] }
        
        let database = container.database(with: scope)
        var allPosts: [User] = []
        
        @Sendable func postInZone(_ zone: CKRecordZone) async throws -> [Post] {
            if zone.zoneID == CKRecordZone.default().zoneID {
                return []
            }
            
            var allPosts: [Post] = []
            
            var awaitingChanges = true
            var nextChangeToken: CKServerChangeToken? = nil
            
            while awaitingChanges {
                let zoneChanges = try await database.recordZoneChanges(inZoneWith: zone.zoneID, since: nextChangeToken)
                let posts = zoneChanges.modificationResultsByID.values
                    .compactMap({ try? $0.get().record })
                    .compactMap({ Post(record: $0)})
                allPosts.append(contentsOf: posts)
                
                awaitingChanges = zoneChanges.moreComing
                nextChangeToken = zoneChanges.changeToken
            }
            
            return allPosts
        }
        
        // Fetch each zones posts in parallel
        try await withThrowingTaskGroup(of: (CKRecordZone, [Post]).self) { user in
            for zone in zones {
                user.addTask {
                    (zone, try await postInZone(zone))
                }
            }
            
            for try await (zone, postsResult) in user {
                allPosts.append(User(zone: zone, post: postsResult))
            }
        }
        
        return allPosts
    }
}
