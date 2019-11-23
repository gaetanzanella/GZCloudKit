
import Foundation
import CloudKit

public enum CKCloudStoreError: Error {
    case generic
    case serverRecordChanged
    case noAccount
    case tokenExpired
    case quotaExceeded
}

extension CKCloudStoreError {
    init(error: Error) {
        guard let error = error as? CKError else {
            self = .generic
            return
        }
        if error.containsPartialErrors(with: .changeTokenExpired) {
            self = .tokenExpired
        } else if error.code == .notAuthenticated {
            self = .noAccount
        } else if error.containsPartialErrors(with: .quotaExceeded) {
            self = .quotaExceeded
        } else if error.containsPartialErrors(with: .unknownItem)
            || error.containsPartialErrors(with: .serverRecordChanged) {
            self = .serverRecordChanged
        } else {
            self = .generic
        }
    }
}

private extension CKError {
    func partialErrors() -> [CKError] {
        return (partialErrorsByItemID?.values).flatMap({ Array($0) }) as? [CKError] ?? []
    }

    func containsPartialErrors(with code: CKError.Code) -> Bool {
        return partialErrors().contains(where: { $0.code == code })
    }
}
