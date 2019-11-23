
import CloudKit

public struct CKFetchZoneChangesResponse {
    public let token: CKServerChangeToken?
    public let recordsToSave: [CKRecord]
    public let recordIDsToDelete: [CKRecord.ID]
}

public struct CKPerformBatchChangesResponse {
    public let recordsModified: [CKRecord]
    public let recordIDsDeleted: [CKRecord.ID]
}

@available(iOS 10, *)
public class CKCloudStore {

    private let container: CKContainer

    private var privateDatabase: CKDatabase {
        return container.privateCloudDatabase
    }

    public init(container: CKContainer) {
        self.container = container
    }

    // MARK: - RemoteStore

    public func createAndSubscribe(to zone: CKRecordZone,
                                   completion: @escaping (Result<Void, CKCloudStoreError>) -> Void) {
        var hasError = false
        let operation = CKModifyRecordZonesOperation(
            recordZonesToSave: [zone],
            recordZoneIDsToDelete: nil
        )
        operation.modifyRecordZonesCompletionBlock = { _, _, error in
            hasError = hasError || error != nil
        }
        let subscription = CKRecordZoneSubscription(
            zoneID: zone.zoneID
        )
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo
        let subscriptionOperation = CKModifySubscriptionsOperation(
            subscriptionsToSave: [subscription],
            subscriptionIDsToDelete: nil
        )
        subscriptionOperation.modifySubscriptionsCompletionBlock = { _, _, error in
            hasError = hasError || error != nil
        }
        subscriptionOperation.addDependency(operation)
        subscriptionOperation.completionBlock = {
            completion(!hasError ? .success(()) : .failure(.generic))
        }
        privateDatabase.add(operation)
        privateDatabase.add(subscriptionOperation)
    }


    public func fetchChanges(in zone: CKRecordZone,
                             since token: CKServerChangeToken? = nil,
                             completion: @escaping (Result<CKFetchZoneChangesResponse, CKCloudStoreError>) -> Void) {
        let userZoneID = zone.zoneID
        let operation: CKFetchRecordZoneChangesOperation
        if #available(iOS 12.0, *) {
            operation = CKFetchRecordZoneChangesOperation(recordZoneIDs: [], configurationsByRecordZoneID: [:])
            let configuration = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
            configuration.previousServerChangeToken = token
            operation.configurationsByRecordZoneID = [userZoneID: configuration]
        } else {
            operation = CKFetchRecordZoneChangesOperation(recordZoneIDs: [], optionsByRecordZoneID: [:])
            let configuration = CKFetchRecordZoneChangesOperation.ZoneOptions()
            configuration.previousServerChangeToken = token
            operation.optionsByRecordZoneID = [userZoneID: configuration]
        }
        operation.recordZoneIDs = [userZoneID]
        operation.fetchAllChanges = true
        var recordsToSave: [CKRecord] = []
        var recordIDsToDelete: [CKRecord.ID] = []
        var serverToken: CKServerChangeToken?
        operation.recordChangedBlock = { record in
            recordsToSave.append(record)
        }
        operation.recordWithIDWasDeletedBlock = { recordID, _ in
            recordIDsToDelete.append(recordID)
        }
        operation.recordZoneFetchCompletionBlock = { _, token, _, _, _ in
            serverToken = token
        }
        operation.fetchRecordZoneChangesCompletionBlock = { error in
            if let error = error {
                completion(.failure(CKCloudStoreError(error: error)))
            } else {
                let response = CKFetchZoneChangesResponse(
                    token: serverToken,
                    recordsToSave: recordsToSave,
                    recordIDsToDelete: recordIDsToDelete
                )
                completion(.success(response))
            }
        }
        privateDatabase.add(operation)
    }

    public func performBatch(recordsToSave: [CKRecord],
                             recordIDsToDelete: [CKRecord.ID],
                             completion: @escaping (Result<CKPerformBatchChangesResponse, CKCloudStoreError>) -> Void) {
        let operation = CKModifyRecordsOperation(
            recordsToSave: recordsToSave,
            recordIDsToDelete: recordIDsToDelete
        )
        operation.isAtomic = true
        operation.savePolicy = .changedKeys
        operation.modifyRecordsCompletionBlock = { records, recordIDs, error in
            if let error = error {
                completion(.failure(CKCloudStoreError(error: error)))
            } else {
                let response = CKPerformBatchChangesResponse(
                    recordsModified: records ?? [],
                    recordIDsDeleted: recordIDs ?? []
                )
                completion(.success(response))
            }
        }
        privateDatabase.add(operation)
    }
}
