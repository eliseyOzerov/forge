import XCTest
@testable import ForgeSwift

@MainActor final class BindingTests: XCTestCase {

    func testBindingValueInit() {
        let b = Binding("hello")
        XCTAssertEqual(b.value, "hello")
    }

    func testBindingMutation() {
        let b = Binding(0)
        b.value = 42
        XCTAssertEqual(b.value, 42)
    }

    func testBindingClosureInit() {
        var storage = "initial"
        let b = Binding(get: { storage }, set: { storage = $0 })
        XCTAssertEqual(b.value, "initial")
        b.value = "changed"
        XCTAssertEqual(storage, "changed")
        XCTAssertEqual(b.value, "changed")
    }

    func testBindingSharedState() {
        let b = Binding(10)
        let copy = b
        copy.value = 20
        XCTAssertEqual(b.value, 20)
    }
}
