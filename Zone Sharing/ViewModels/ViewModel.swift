//
//  ViewModel.swift
//  Zone Sharing
//
//  Created by Bryan Gomez on 9/6/24.
//

import Foundation
import CloudKit
import OSLog

@MainActor
final class ViewModel: ObservableObject {
    
    // MARK: - Error
    
    enum ViewModelError: Error {
        case invalidRemoteShare
        case userZoneNotFound
    }
    
    // MARK: - State
    
    enum State {
        case loading
        case loaded(privatePosts: [Post], sharedPosts: [Post])
        case error(Error)
    }
    
    // MARK: - Properties
    
    @Published private(set) var currentUserName: String = "Me"
    /// State directly observable by our view.
    @Published private(set) var state: State = .loading
    /// Use the specified iCloud container ID, which should also be present in the entitlements file.
    lazy var container = CKContainer(identifier: Config.containerIndetifier)
    /// This project uses the user's private database.
    private lazy var database = container.privateCloudDatabase
    /// Sharing requires using a custom record zone.
    private var userZone: CKRecordZone?
    
    // MARK: - Init
    
    nonisolated init() {}
    
    /// Initializer to provide explicit state (e.g. for previews).
    init(state: State) {
        self.state = state
    }
    
    // MARK: - API
    
    /// Fetches contacts from the remote databases and updates local state.
    func refresh() async throws {
        state = .loading
        do {
            try await ensureUserZoneExists()
            let (privatePosts, sharedPosts) = try await fetchPrivateAndSharedPosts()
            state = .loaded(privatePosts: privatePosts, sharedPosts: sharedPosts)
        } catch {
            state = .error(error)
        }
    }
    
    /// Fetches both private and shared contacts in parallel.
    /// - Returns: A tuple containing separated private and shared contacts.
    func fetchPrivateAndSharedPosts() async throws -> (private: [Post], shared: [Post]) {
        guard let userZone = userZone else {
            throw ViewModelError.userZoneNotFound
        }
        
        // This will run each of these operations in parallel.
        async let privatePosts = fetchPosts(scope: .private, in: [userZone])
        async let sharedPosts = fetchSharedPosts()
        
        return (private: try await privatePosts, shared: try await sharedPosts)
    }
    
    /// Adds a new Contact to the database.
    /// - Parameters:
    ///   - name: Name of the Contact.
    ///   - phoneNumber: Phone number of the contact.
    ///   - author: iCloud user name
    func addPost(message: String) async throws {
        guard let userZone = userZone else {
            throw ViewModelError.userZoneNotFound
        }
        
        do {
            let id = CKRecord.ID(zoneID: userZone.zoneID)
            let postRecord = CKRecord(recordType: "SharedPost", recordID: id)
            postRecord["message"] = message
            postRecord["author"] = currentUserName
            
            try await database.save(postRecord)
            
        } catch {
            debugPrint("ERROR: Failed to save new Contact: \(error)")
            throw error
        }
    }
    
    /// Fetches an existing `CKShare` on a Contact record, or creates a new one in preparation to share a Contact with another user.
    /// - Parameters:
    ///   - contact: Contact to share.
    ///   - completionHandler: Handler to process a `success` or `failure` result.
    func fetchOrCreateShare() async throws -> (CKShare, CKContainer) {
        guard let userZone = userZone else {
            throw ViewModelError.userZoneNotFound
        }
        
        if let existingShare = userZone.share {
            guard let share = try await database.record(for: existingShare.recordID) as? CKShare else {
                throw ViewModelError.userZoneNotFound
            }
            
            return (share, container)
        } else {
            let share =  CKShare(recordZoneID: userZone.zoneID)
            share[CKShare.SystemFieldKey.title] = "My Posts"
            _ = try await database.modifyRecords(saving: [share], deleting: [])
            return (share, container)
        }
    }
    
    private func fetchSharedPosts() async throws -> [Post] {
        let shareZones = try await container.sharedCloudDatabase.allRecordZones()
        return try await fetchPosts(scope: .shared, in: shareZones)
    }
    
    private func ensureUserZoneExists() async throws {
        let userId = try await container.userRecordID()
        let zoneName = "user-\(userId.recordName)"
        let zone = CKRecordZone(zoneName: zoneName)
        
        do {
            try await database.save(zone)
            userZone = zone
        } catch  {
            if let ckError = error as? CKError, ckError.code == .zoneNotFound {
                userZone = try await database.recordZone(for: zone.zoneID)
            } else {
                throw error
            }
        }
    }
    
    //MARK: - Author/Username
    
        func fetchUserName() async {
        do {
            let userIdentity = try await container.userIdentity(forUserRecordID: try await container.userRecordID())
            if let name = userIdentity?.nameComponents?.givenName ?? userIdentity?.nameComponents?.familyName {
                currentUserName = name
            } else if let email = userIdentity?.lookupInfo?.emailAddress {
                currentUserName = email
            }
        } catch {
            print("Error fetching user identity: \(error)")
        }
    }
    
    // MARK: - Private
    
    /// Fetches contacts for a given set of zones in a given database scope.
    /// - Parameters:
    ///   - scope: Database scope to fetch from.
    ///   - zones: Record zones to fetch contacts from.
    /// - Returns: Combined set of contacts across all given zones.
    private func fetchPosts(scope: CKDatabase.Scope, in zones: [CKRecordZone]) async throws -> [Post] {
        guard !zones.isEmpty else { return [] }
        
        let database = container.database(with: scope)
        var allPosts: [Post] = []
        
        for zone in zones {
            /// `recordZoneChanges` can return multiple consecutive changesets before completing, so
            /// we use a loop to process multiple results if needed, indicated by the `moreComing` flag.
            var awaitingChanges = true
            /// After each loop, if more changes are coming, they are retrieved by using the `changeToken` property.
            var nextChangeToken: CKServerChangeToken? = nil
            
            while awaitingChanges {
                let zoneChanges = try await database.recordZoneChanges(inZoneWith: zone.zoneID, since: nextChangeToken)
                let posts = zoneChanges.modificationResultsByID.values
                    .compactMap { try? $0.get().record }
                    .compactMap { Post(record: $0) }
                allPosts.append(contentsOf: posts)
                
                awaitingChanges = zoneChanges.moreComing
                nextChangeToken = zoneChanges.changeToken
            }
        }
        
        return allPosts
    }
}
