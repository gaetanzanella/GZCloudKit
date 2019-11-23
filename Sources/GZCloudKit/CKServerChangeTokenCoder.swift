
import CloudKit
import Foundation

public class CKServerChangeTokenCoder {

    public init() {}

    public func decodeToken(from data: Data) -> CKServerChangeToken? {
        let coder = NSKeyedUnarchiver(forReadingWith: data)
        coder.requiresSecureCoding = true
        let token = CKServerChangeToken(coder: coder)
        coder.finishDecoding()
        return token
    }

    public func encode(_ token: CKServerChangeToken) -> Data {
        let data = NSMutableData()
        let coder = NSKeyedArchiver(forWritingWith: data)
        coder.requiresSecureCoding = true
        token.encode(with: coder)
        coder.finishEncoding()
        return data as Data
    }
}
