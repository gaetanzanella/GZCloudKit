//
//  File.swift
//  
//
//  Created by Gaétan Zanella on 12/12/2019.
//

import CloudKit

public enum CKAccountStatus {
    case available
    case unavailable
    case unknown
}

@available(iOS 10, *)
public class CKAccountStatusMonitor {

    private let container: CKContainer

    public private(set) var accountStatus: CKAccountStatus = .unknown {
        didSet {
            guard oldValue != accountStatus else { return }
            accountStatusUpdateHandler?(self)
        }
    }
    public var accountStatusUpdateHandler: ((CKAccountStatusMonitor) -> Void)?

    private var observer: NSObjectProtocol?

    // MARK: - Life Cycle

    init(container: CKContainer) {
        self.container = container
        observer = NotificationCenter.default.addObserver(
            forName: .CKAccountChanged,
            object: container,
            queue: .main
        ) { [weak self] _ in
            self?.refreshStatus()
        }
        refreshStatus()
    }

    deinit {
        observer.flatMap { NotificationCenter.default.removeObserver($0) }
    }

    // MARK: - Public

    func forceAccountStatusRefresh(completion: ((CKAccountStatus) -> Void)? = nil) {
        accountStatus = .unknown
        refreshStatus(completion: completion)
    }

    // MARK: - Private

    private func refreshStatus(completion: ((CKAccountStatus) -> Void)? = nil) {
        container.accountStatus { [weak self] status, error in
            DispatchQueue.main.async {
                let accountStatus: CKAccountStatus
                switch status {
                case .available:
                    accountStatus = .available
                case .couldNotDetermine:
                    accountStatus = .unknown
                case .noAccount, .restricted:
                    accountStatus = .unavailable
                @unknown default:
                    accountStatus = .unknown
                }
                completion?(accountStatus)
                self?.accountStatus = accountStatus
            }
        }
    }
}
