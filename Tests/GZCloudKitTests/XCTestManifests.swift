import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(GZCloudKitTests.allTests),
    ]
}
#endif
