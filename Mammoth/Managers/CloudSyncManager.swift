//
//  CloudSyncManager.swift
//  Mammoth
//
//  Created by Bill Burgess on 6/21/24
//  Copyright © 2024 The BLVD. All rights reserved.
//

struct CloudSyncConstants {
    struct Keys {
        static let kLastFollowingSyncDate = "dev.umarhadi.mammoth.icloud.following.lastsync"
        static let kLastFollowingSyncID = "dev.umarhadi.mammoth.icloud.following.syncid"
        static let kLastForYouSyncDate = "dev.umarhadi.mammoth.icloud.foryou.lastsync"
        static let kLastForYouSyncID = "dev.umarhadi.mammoth.icloud.foryou.syncid"
        static let kLastFederatedSyncDate = "dev.umarhadi.mammoth.icloud.federated.lastsync"
        static let kLastFederatedSyncID = "dev.umarhadi.mammoth.icloud.federated.syncid"
        static let kLastMentionsInSyncDate = "dev.umarhadi.mammoth.icloud.mentionsIn.lastsync"
        static let kLastMentionsInSyncID = "dev.umarhadi.mammoth.icloud.mentionsIn.syncid"
        static let kLastMentionsOutSyncDate = "dev.umarhadi.mammoth.icloud.mentionsOut.lastsync"
        static let kLastMentionsOutSyncID = "dev.umarhadi.mammoth.icloud.mentionsOut.syncid"
    }
}

class CloudSyncManager {
    static let sharedManager = CloudSyncManager()
    
    // Toggle these on/off while refresh cycle is happening to avoid scroll conflicts
    var shouldSaveFollowing = false
    var shouldSaveForYou = false
    var shouldSaveFederated = false
    var shouldSaveMentionsIn = false
    var shouldSaveMentionsOut = false
    
    private let jsonEncoder = JSONEncoder()
    private let jsonDecoder = JSONDecoder()
    private var syncDebouncer: Timer?
    private var cloudStore = NSUbiquitousKeyValueStore.default
    private var userDefaults = UserDefaults.standard

    init() {

    }
    
    public func enableSaving(forFeedType feedType: NewsFeedTypes) {
        if !GlobalStruct.cloudSync { return }
        
        switch feedType {
        case .following:
            shouldSaveFollowing = true
        case .forYou:
            shouldSaveForYou = true
        case .federated:
            shouldSaveFederated = true
        case .mentionsIn:
            shouldSaveMentionsIn = true
        case .mentionsOut:
            shouldSaveMentionsOut = true
        default:
            return
        }
    }
    
    public func disableSaving(forFeedType feedType: NewsFeedTypes) {
        switch feedType {
        case .following:
            shouldSaveFollowing = false
        case .forYou:
            shouldSaveForYou = false
        case .federated:
            shouldSaveFederated = false
        case .mentionsIn:
            shouldSaveMentionsIn = false
        case .mentionsOut:
            shouldSaveMentionsOut = false
        default:
            return
        }
    }
    
    public func disableAllSaving() {
        shouldSaveFollowing = false
        shouldSaveForYou = false
        shouldSaveFederated = false
        shouldSaveMentionsIn = false
        shouldSaveMentionsOut = false
    }

    public func saveSyncStatus(for type: NewsFeedTypes, scrollPosition: NewsFeedScrollPosition) {
        if !GlobalStruct.cloudSync { return }
        
        switch type {
        case .following:
            if !shouldSaveFollowing {
                return
            }
        case .forYou:
            if !shouldSaveForYou {
                return
            }
        case .federated:
            if !shouldSaveFederated {
                return
            }
        case .mentionsIn:
            if !shouldSaveMentionsIn {
                return
            }
        case .mentionsOut:
            if !shouldSaveMentionsOut {
                return
            }
        default:
            return
        }
        
        // Trying without debounce, we want to more eagerly save if we're doing tight syncing
        self.setSyncStatus(for: type, scrollPosition: scrollPosition)
        
        /*syncDebouncer?.invalidate()
        syncDebouncer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            self?.setSyncStatus(for: type, scrollPosition: scrollPosition)
        }*/
    }

    public func cloudSavedPosition(for type: NewsFeedTypes) -> NewsFeedScrollPosition? {
        if !GlobalStruct.cloudSync { return nil }
        
        let (itemKey, dateKey) = keys(for: type)
        
        guard !itemKey.isEmpty, !dateKey.isEmpty else { return nil }
        
        if let scrollPositionJSON = cloudStore.data(forKey: itemKey) {
            do {
                let scrollPosition = try jsonDecoder.decode(NewsFeedScrollPosition.self, from: scrollPositionJSON)
                return scrollPosition
            } catch {
                log.error("Failed to decode object: \(error)")
            }
        }
        log.debug("iCloud Sync: No saved conditions satisfied, providing nil sync position")
        return nil
    }

    private func setSyncStatus(for type: NewsFeedTypes, scrollPosition: NewsFeedScrollPosition) {
        if !GlobalStruct.cloudSync { return }
        
        let (itemKey, dateKey) = keys(for: type)
        guard !itemKey.isEmpty, !dateKey.isEmpty else { return }
        
        do {
            let scrollPositionJSON = try jsonEncoder.encode(scrollPosition)
            let syncDate = Date()
            cloudStore.set(scrollPositionJSON, forKey: itemKey)
            cloudStore.set(syncDate, forKey: dateKey)
            cloudStore.synchronize()
            log.debug("iCloud Sync: Synced \(type.title()) position at \(syncDate)")
        } catch {
            log.error("Failed to encode object: \(error)")
        }
    }

    private func keys(for type: NewsFeedTypes) -> (itemKey: String, dateKey: String) {
        // NB: We don't want to bake the "." into the sync ID lets because of matching elsewhere
        switch type {
        case .following:
            return (CloudSyncConstants.Keys.kLastFollowingSyncID + "." + (AccountsManager.shared.currentAccount?.fullAcct ?? ""), CloudSyncConstants.Keys.kLastFollowingSyncDate + "." + (AccountsManager.shared.currentAccount?.fullAcct ?? ""))
        case .forYou:
            return (CloudSyncConstants.Keys.kLastForYouSyncID + "." + (AccountsManager.shared.currentAccount?.fullAcct ?? ""), CloudSyncConstants.Keys.kLastForYouSyncDate + "." + (AccountsManager.shared.currentAccount?.fullAcct ?? ""))
        case .federated:
            return (CloudSyncConstants.Keys.kLastFederatedSyncID + "." + (AccountsManager.shared.currentAccount?.fullAcct ?? ""), CloudSyncConstants.Keys.kLastFederatedSyncDate + "." + (AccountsManager.shared.currentAccount?.fullAcct ?? ""))
        case .mentionsIn:
            return (CloudSyncConstants.Keys.kLastMentionsInSyncID + "." + (AccountsManager.shared.currentAccount?.fullAcct ?? ""), CloudSyncConstants.Keys.kLastMentionsInSyncDate + "." + (AccountsManager.shared.currentAccount?.fullAcct ?? ""))
        case .mentionsOut:
            return (CloudSyncConstants.Keys.kLastMentionsOutSyncID + "." + (AccountsManager.shared.currentAccount?.fullAcct ?? ""), CloudSyncConstants.Keys.kLastMentionsOutSyncDate + "." + (AccountsManager.shared.currentAccount?.fullAcct ?? ""))
        default:
            return ("", "")
        }
    }

    private func typeFor(key: String) -> NewsFeedTypes {
        switch key {
        case let string where string.contains(CloudSyncConstants.Keys.kLastFollowingSyncID):
            return .following
        case let string where string.contains(CloudSyncConstants.Keys.kLastForYouSyncID):
            return .forYou
        case let string where string.contains(CloudSyncConstants.Keys.kLastFederatedSyncID):
            return .federated
        case let string where string.contains(CloudSyncConstants.Keys.kLastMentionsInSyncID):
            return .mentionsIn
        case let string where string.contains(CloudSyncConstants.Keys.kLastMentionsOutSyncID):
            return .mentionsOut
        default:
            return .activity(nil) // unsupported type
        }

    }
}
