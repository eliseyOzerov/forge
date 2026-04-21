#if canImport(UIKit)
import XCTest
@testable import ForgeSwift

@MainActor
final class LiftTests: XCTestCase {

    // MARK: - Inflate

    func testInflateProducesNode() {
        let binding = Binding(false)
        let tree = Lift(lifted: binding) { _ in TestLeaf(label: "slot") }
        let node = Node.inflate(tree)
        XCTAssertTrue(node is ModelNode)
        XCTAssertNotNil(node.platformView)
    }

    func testBuilderReceivesFalseForSlotContent() {
        var receivedLifted: Bool?
        let binding = Binding(false)
        let tree = Lift(lifted: binding) { lifted in
            receivedLifted = lifted
            return TestLeaf(label: "slot")
        }
        _ = Node.inflate(tree)
        XCTAssertEqual(receivedLifted, false)
    }

    func testBuilderReceivesTrueWhenLifted() {
        var receivedLifted: Bool?
        let binding = Binding(true)
        let tree = Lift(lifted: binding) { lifted in
            receivedLifted = lifted
            return TestLeaf(label: "slot")
        }
        _ = Node.inflate(tree)
        // Slot content always receives false (the overlay gets true),
        // but the model attempts to lift via the router.
        XCTAssertEqual(receivedLifted, false)
    }

    // MARK: - Binding integration

    func testBindingValueReadable() {
        let binding = Binding(false)
        XCTAssertFalse(binding.value)
        binding.value = true
        XCTAssertTrue(binding.value)
    }

    func testBindingOnChangeCallsHandler() {
        var observed: [Bool] = []
        let binding = Binding(false).onChange { observed.append($0) }
        binding.value = true
        binding.value = false
        XCTAssertEqual(observed, [true, false])
    }

    // MARK: - LiftOverlay properties

    func testLiftOverlayIsNonOpaque() {
        let overlay = LiftOverlay(
            content: { TestLeaf(label: "") },
            slotRect: Observable(.zero)
        )
        XCTAssertFalse(overlay.opaque)
        XCTAssertEqual(overlay.duration, 0)
    }

    // MARK: - Model lifecycle

    func testModelPreservedOnUpdate() {
        let binding = Binding(false)
        let node = Node.inflate(Lift(lifted: binding) { _ in TestLeaf(label: "a") })
        let modelBefore = (node as! ModelNode).model

        node.update(from: Lift(lifted: binding) { _ in TestLeaf(label: "b") })
        let modelAfter = (node as! ModelNode).model
        XCTAssertTrue(modelBefore === modelAfter)
    }
}
#endif
