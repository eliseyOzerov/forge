#if canImport(UIKit)
import XCTest
@testable import ForgeSwift

@MainActor
final class LiftControllerTests: XCTestCase {

    func testInitialValue() {
        XCTAssertFalse(LiftController().value)
        XCTAssertTrue(LiftController(true).value)
    }

    func testSetFlipsValue() {
        let c = LiftController()
        c.set(true)
        XCTAssertTrue(c.value)
        c.set(false)
        XCTAssertFalse(c.value)
    }

    func testToggleFlipsValue() {
        let c = LiftController()
        c.toggle()
        XCTAssertTrue(c.value)
        c.toggle()
        XCTAssertFalse(c.value)
    }

    func testObserverFiresOnChange() {
        let c = LiftController()
        var calls: [Bool] = []
        _ = c.observe { calls.append($0) }
        c.set(true)
        c.set(false)
        XCTAssertEqual(calls, [true, false])
    }

    func testObserverSkipsIdempotentWrites() {
        let c = LiftController()
        var calls = 0
        _ = c.observe { _ in calls += 1 }
        c.set(false)  // same as initial, no fire
        c.set(true)
        c.set(true)   // same, no fire
        XCTAssertEqual(calls, 1)
    }

    func testUnobserve() {
        let c = LiftController()
        var calls = 0
        let id = c.observe { _ in calls += 1 }
        c.set(true)
        c.unobserve(id)
        c.set(false)
        XCTAssertEqual(calls, 1)
    }

    // MARK: - LiftView

    func testLiftViewReadsLocalValueWritesToCanonical() {
        let canonical = LiftController()
        let slotView = LiftView(value: false, canonical: canonical)
        XCTAssertFalse(slotView.value)
        slotView.set(true)
        XCTAssertTrue(canonical.value)
    }
}
#endif
