
import CloudKit

public struct CKFetchZoneChangesResponse {
    public let token: CKServerChangeToken?
    public let recordsToSave: [CKRecord]
    public let recordIDsToDelete: [(CKRecord.ID, CKRecord.RecordType)]
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
        var resultingError: Error?
        let operation = CKModifyRecordZonesOperation(
            recordZonesToSave: [zone],
            recordZoneIDsToDelete: nil
        )
        operation.modifyRecordZonesCompletionBlock = { _, _, error in
            resultingError = resultingError ?? error
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
            if let error = error as? CKError, error.containsPartialErrors(with: .serverRejectedRequest) {
                // (gz) The subsctipion already exists
            } else {
                resultingError = resultingError ?? error
            }
        }
        subscriptionOperation.addDependency(operation)
        subscriptionOperation.completionBlock = {
            if let error = resultingError {
                completion(.failure(CKCloudStoreError(error)))
            } else {
                completion(.success(()))
            }
        }
        privateDatabase.add(operation)
        privateDatabase.add(subscriptionOperation)
    }

    public func clearAllPrivateSubscriptions(completion: @escaping (Result<Void, CKCloudStoreError>) -> Void) {
        let database = privateDatabase
        let fetchOperation = CKFetchSubscriptionsOperation.fetchAllSubscriptionsOperation()
        fetchOperation.fetchSubscriptionCompletionBlock = { subscriptions, error in
            if let error = error {
                completion(.failure(CKCloudStoreError(error)))
            } else if let ids = subscriptions?.keys {
                let deleteOperation = CKModifySubscriptionsOperation()
                deleteOperation.subscriptionIDsToDelete = Array(ids)
                deleteOperation.modifySubscriptionsCompletionBlock = { _, _, error in
                    if let error = error {
                        completion(.failure(CKCloudStoreError(error)))
                    } else {
                        completion(.success(()))
                    }
                }
                database.add(deleteOperation)
            }
        }
        database.add(fetchOperation)
    }

    public func fetchChanges(in zone: CKRecordZone,
                             desiredKeys: [CKRecord.FieldKey]? = nil,
                             since token: CKServerChangeToken? = nil,
                             completion: @escaping (Result<CKFetchZoneChangesResponse, CKCloudStoreError>) -> Void) {
        let userZoneID = zone.zoneID
        let operation: CKFetchRecordZoneChangesOperation
        if #available(iOS 12.0, *) {
            operation = CKFetchRecordZoneChangesOperation(recordZoneIDs: [], configurationsByRecordZoneID: [:])
            let configuration = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
            configuration.previousServerChangeToken = token
            configuration.desiredKeys = desiredKeys
            operation.configurationsByRecordZoneID = [userZoneID: configuration]
        } else {
            operation = CKFetchRecordZoneChangesOperation(recordZoneIDs: [], optionsByRecordZoneID: [:])
            let configuration = CKFetchRecordZoneChangesOperation.ZoneOptions()
            configuration.previousServerChangeToken = token
            configuration.desiredKeys = desiredKeys
            operation.optionsByRecordZoneID = [userZoneID: configuration]
        }
        operation.recordZoneIDs = [userZoneID]
        operation.fetchAllChanges = true
        var recordsToSave: [CKRecord] = []
        var recordIDsToDelete: [(CKRecord.ID, CKRecord.RecordType)] = []
        var serverToken: CKServerChangeToken?
        operation.recordChangedBlock = { record in
            recordsToSave.append(record)
        }
        operation.recordWithIDWasDeletedBlock = { recordID, type in
            recordIDsToDelete.append((recordID, type))
        }
        operation.recordZoneFetchCompletionBlock = { _, token, _, _, _ in
            serverToken = token
        }
        operation.fetchRecordZoneChangesCompletionBlock = { error in
            if let error = error {
                completion(.failure(CKCloudStoreError(error)))
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
                             savePolicy: CKModifyRecordsOperation.RecordSavePolicy = .changedKeys,
                             isAtomic: Bool = true,
                             completion: @escaping (Result<CKPerformBatchChangesResponse, CKCloudStoreError>) -> Void) {
        let operation = CKModifyRecordsOperation(
            recordsToSave: recordsToSave,
            recordIDsToDelete: recordIDsToDelete
        )
        operation.isAtomic = isAtomic
        operation.savePolicy = savePolicy
        operation.modifyRecordsCompletionBlock = { records, recordIDs, error in
            if let error = error {
                completion(.failure(CKCloudStoreError(error)))
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
