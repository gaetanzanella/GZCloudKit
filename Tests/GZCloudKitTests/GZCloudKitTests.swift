import XCTest
@testable import GZCloudKit

final class GZCloudKitTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(GZCloudKit().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
