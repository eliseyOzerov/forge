#if canImport(UIKit)
import XCTest
@testable import ForgeSwift

@MainActor
final class LayoutTests: XCTestCase {

    private let acc = 0.5

    // MARK: - proposeBounds: Fix

    func testProposeBoundsFixNoPadding() {
        let layout = BoxLayout(frame: .fixed(100, 80))
        let bounds = layout.proposeBounds(proposed: Size(200, 200))
        XCTAssertEqual(bounds.width, 100, accuracy: acc)
        XCTAssertEqual(bounds.height, 80, accuracy: acc)
    }

    func testProposeBoundsFixWithPadding() {
        let layout = BoxLayout(padding: .all(15), frame: .fixed(100, 80))
        let bounds = layout.proposeBounds(proposed: Size(200, 200))
        XCTAssertEqual(bounds.width, 70, accuracy: acc)
        XCTAssertEqual(bounds.height, 50, accuracy: acc)
    }

    func testProposeBoundsFixPaddingExceedsFixed() {
        let layout = BoxLayout(padding: .all(60), frame: .fixed(100, 80))
        let bounds = layout.proposeBounds(proposed: Size(200, 200))
        XCTAssertEqual(bounds.width, 0, accuracy: acc)
        XCTAssertEqual(bounds.height, 0, accuracy: acc)
    }

    func testProposeBoundsFixIgnoresProposed() {
        let layout = BoxLayout(frame: .fixed(80, 60))
        let a = layout.proposeBounds(proposed: Size(300, 300))
        let b = layout.proposeBounds(proposed: Size(50, 50))
        XCTAssertEqual(a.width, 80, accuracy: acc)
        XCTAssertEqual(b.width, 80, accuracy: acc)
    }

    // MARK: - proposeBounds: Hug

    func testProposeBoundsHugNoPadding() {
        let layout = BoxLayout()
        let bounds = layout.proposeBounds(proposed: Size(200, 200))
        XCTAssertEqual(bounds.width, 200, accuracy: acc)
        XCTAssertEqual(bounds.height, 200, accuracy: acc)
    }

    func testProposeBoundsHugWithPadding() {
        let layout = BoxLayout(padding: .all(20))
        let bounds = layout.proposeBounds(proposed: Size(200, 200))
        XCTAssertEqual(bounds.width, 160, accuracy: acc)
        XCTAssertEqual(bounds.height, 160, accuracy: acc)
    }

    func testProposeBoundsHugPaddingExceedsProposed() {
        let layout = BoxLayout(padding: .all(25))
        let bounds = layout.proposeBounds(proposed: Size(30, 30))
        XCTAssertEqual(bounds.width, 0, accuracy: acc)
        XCTAssertEqual(bounds.height, 0, accuracy: acc)
    }

    func testProposeBoundsHugMinClampsUp() {
        // proposed (50) - padding (0) = 50, clamped to min 100
        let layout = BoxLayout(frame: Frame(.hug(min: 100), .hug(min: 100)))
        let bounds = layout.proposeBounds(proposed: Size(50, 50))
        XCTAssertEqual(bounds.width, 100, accuracy: acc)
        XCTAssertEqual(bounds.height, 100, accuracy: acc)
    }

    func testProposeBoundsHugMinNoEffectWhenLarger() {
        // proposed (200) - padding (0) = 200, already > min 100
        let layout = BoxLayout(frame: Frame(.hug(min: 100), .hug(min: 100)))
        let bounds = layout.proposeBounds(proposed: Size(200, 200))
        XCTAssertEqual(bounds.width, 200, accuracy: acc)
        XCTAssertEqual(bounds.height, 200, accuracy: acc)
    }

    func testProposeBoundsHugMaxClampsDown() {
        // proposed (200) - padding (0) = 200, clamped to max 150
        let layout = BoxLayout(frame: Frame(.hug(max: 150), .hug(max: 150)))
        let bounds = layout.proposeBounds(proposed: Size(200, 200))
        XCTAssertEqual(bounds.width, 150, accuracy: acc)
        XCTAssertEqual(bounds.height, 150, accuracy: acc)
    }

    func testProposeBoundsHugMaxNoEffectWhenSmaller() {
        // proposed (100) - padding (0) = 100, already < max 150
        let layout = BoxLayout(frame: Frame(.hug(max: 150), .hug(max: 150)))
        let bounds = layout.proposeBounds(proposed: Size(100, 100))
        XCTAssertEqual(bounds.width, 100, accuracy: acc)
        XCTAssertEqual(bounds.height, 100, accuracy: acc)
    }

    func testProposeBoundsHugMinWithPadding() {
        // proposed (80) - padding (40) = 40, clamped to min 100
        let layout = BoxLayout(padding: .all(20), frame: Frame(.hug(min: 100), .hug(min: 100)))
        let bounds = layout.proposeBounds(proposed: Size(80, 80))
        XCTAssertEqual(bounds.width, 100, accuracy: acc)
        XCTAssertEqual(bounds.height, 100, accuracy: acc)
    }

    // MARK: - proposeBounds: Fill

    func testProposeBoundsFillReturnsZero() {
        let layout = BoxLayout(frame: .fill)
        let bounds = layout.proposeBounds(proposed: Size(200, 200))
        XCTAssertEqual(bounds.width, 0, accuracy: acc)
        XCTAssertEqual(bounds.height, 0, accuracy: acc)
    }

    func testProposeBoundsFillWithPaddingReturnsZero() {
        let layout = BoxLayout(padding: .all(20), frame: .fill)
        let bounds = layout.proposeBounds(proposed: Size(200, 200))
        XCTAssertEqual(bounds.width, 0, accuracy: acc)
        XCTAssertEqual(bounds.height, 0, accuracy: acc)
    }

    func testProposeBoundsFillMinMaxDontAffectProposal() {
        let layout = BoxLayout(frame: Frame(.fill(min: 50, max: 150), .fill(min: 50, max: 150)))
        let bounds = layout.proposeBounds(proposed: Size(200, 200))
        XCTAssertEqual(bounds.width, 0, accuracy: acc)
        XCTAssertEqual(bounds.height, 0, accuracy: acc)
    }

    // MARK: - proposeBounds: Mixed axes

    func testProposeBoundsFixWidthHugHeight() {
        let layout = BoxLayout(padding: .all(10), frame: .fillWidth)
        let bounds = layout.proposeBounds(proposed: Size(200, 200))
        // Width is fill → 0, height is hug → 200 - 20 = 180
        XCTAssertEqual(bounds.width, 0, accuracy: acc)
        XCTAssertEqual(bounds.height, 180, accuracy: acc)
    }

    func testProposeBoundsAsymmetricPadding() {
        let layout = BoxLayout(padding: Padding(horizontal: 10, vertical: 30), frame: .fixed(100, 100))
        let bounds = layout.proposeBounds(proposed: Size(200, 200))
        XCTAssertEqual(bounds.width, 80, accuracy: acc)
        XCTAssertEqual(bounds.height, 40, accuracy: acc)
    }
}

#endif
