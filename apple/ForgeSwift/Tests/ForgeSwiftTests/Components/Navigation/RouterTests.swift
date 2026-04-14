#if canImport(UIKit)
import XCTest
@testable import ForgeSwift

@MainActor
final class RouterTests: XCTestCase {

    // MARK: - Test routes

    struct TestRoute: Route {
        let name: String
        func body() -> any View { EmptyView() }
    }

    private func r(_ name: String) -> TestRoute { TestRoute(name: name) }

    private func ids(_ stack: [AnyRoute]) -> [String] {
        stack.map { ($0.id.base as? TestRoute)?.name ?? "?" }
    }

    private func handle(with declarative: [TestRoute]) -> RouterHandle {
        let h = RouterHandle()
        h.setDeclarative(declarative.map { AnyRoute($0) })
        return h
    }

    // MARK: - Declarative baseline

    func testDeclarativeSeed() {
        let h = handle(with: [r("a"), r("b")])
        XCTAssertEqual(ids(h.resolvedStack), ["a", "b"])
    }

    func testDeclarativeUpdateReplaces() {
        let h = handle(with: [r("a"), r("b")])
        h.setDeclarative([AnyRoute(r("x"))])
        XCTAssertEqual(ids(h.resolvedStack), ["x"])
    }

    // MARK: - Push

    func testPushAppends() {
        let h = handle(with: [r("a")])
        h.push(r("b"))
        XCTAssertEqual(ids(h.resolvedStack), ["a", "b"])
    }

    func testPushOntoEmptyAnchorsStart() {
        let h = handle(with: [])
        h.push(r("x"))
        XCTAssertEqual(ids(h.resolvedStack), ["x"])
    }

    func testPushMultipleChains() {
        let h = handle(with: [r("a")])
        h.push(r("b"))
        h.push(r("c"))
        XCTAssertEqual(ids(h.resolvedStack), ["a", "b", "c"])
    }

    // MARK: - Pop

    func testPopRemovesTopImperative() {
        let h = handle(with: [r("a")])
        h.push(r("b"))
        h.pop()
        XCTAssertEqual(ids(h.resolvedStack), ["a"])
    }

    func testPopRemovesTopDeclarativeViaSuppression() {
        let h = handle(with: [r("a"), r("b")])
        h.pop()
        XCTAssertEqual(ids(h.resolvedStack), ["a"])
    }

    func testSuppressionPersistsAcrossDeclarativeRebuild() {
        let h = handle(with: [r("a"), r("b")])
        h.pop()
        // Builder re-emits b; should stay suppressed.
        h.setDeclarative([AnyRoute(r("a")), AnyRoute(r("b"))])
        XCTAssertEqual(ids(h.resolvedStack), ["a"])
    }

    func testUnsuppressBringsRouteBack() {
        let h = handle(with: [r("a"), r("b")])
        h.pop()
        XCTAssertEqual(ids(h.resolvedStack), ["a"])
        h.unsuppress(id: AnyHashable(r("b")))
        XCTAssertEqual(ids(h.resolvedStack), ["a", "b"])
    }

    func testRemoveByRouteValue() {
        let h = handle(with: [r("a"), r("b"), r("c")])
        h.remove(r("b"))
        XCTAssertEqual(ids(h.resolvedStack), ["a", "c"])
    }

    func testRemoveImperativeRoute() {
        let h = handle(with: [r("a")])
        h.push(r("b"))
        h.push(r("c"))
        h.remove(r("b"))
        XCTAssertEqual(ids(h.resolvedStack), ["a", "c"])
    }

    func testPopToRootClearsImperativeAndSuppression() {
        let h = handle(with: [r("a"), r("b")])
        h.push(r("c"))
        h.pop()  // removes c (imperative)
        h.pop()  // suppresses b
        XCTAssertEqual(ids(h.resolvedStack), ["a"])
        h.popToRoot()
        XCTAssertEqual(ids(h.resolvedStack), ["a", "b"])
    }

    func testSetImperativeClearsSuppression() {
        let h = handle(with: [r("a"), r("b")])
        h.pop()  // suppresses b
        h.setImperative([r("z")])
        XCTAssertEqual(ids(h.resolvedStack), ["a", "b", "z"])
    }

    // MARK: - Insert

    func testInsertAfter() {
        let h = handle(with: [r("a"), r("b"), r("c")])
        h.insert(r("q"), after: r("b"))
        XCTAssertEqual(ids(h.resolvedStack), ["a", "b", "q", "c"])
    }

    func testInsertBefore() {
        let h = handle(with: [r("a"), r("b"), r("c")])
        h.insert(r("q"), before: r("c"))
        XCTAssertEqual(ids(h.resolvedStack), ["a", "b", "q", "c"])
    }

    func testInsertAtIndex() {
        let h = handle(with: [r("a"), r("b"), r("c")])
        h.insert(r("q"), at: 1)
        XCTAssertEqual(ids(h.resolvedStack), ["a", "q", "b", "c"])
    }

    func testInsertAtZero() {
        let h = handle(with: [r("a"), r("b")])
        h.insert(r("q"), at: 0)
        XCTAssertEqual(ids(h.resolvedStack), ["q", "a", "b"])
    }

    // MARK: - Anchor survival across declarative churn

    func testAnchoredRouteRidesAlongOnReorder() {
        let h = handle(with: [r("a"), r("b"), r("c")])
        h.insert(r("q"), after: r("b"))
        // Declarative reorders — b moves
        h.setDeclarative([AnyRoute(r("c")), AnyRoute(r("b")), AnyRoute(r("a"))])
        XCTAssertEqual(ids(h.resolvedStack), ["c", "b", "q", "a"])
    }

    func testAnchorVanishingSlidesBackwardForAfter() {
        let h = handle(with: [r("a"), r("b"), r("c")])
        h.insert(r("q"), after: r("b"))
        // b leaves
        h.setDeclarative([AnyRoute(r("a")), AnyRoute(r("c"))])
        // q had anchor=b side=.after; b gone → walk fallback backward
        // from b's position in [a,b,c] → find a → insert after a.
        XCTAssertEqual(ids(h.resolvedStack), ["a", "q", "c"])
    }

    func testAnchorVanishingSlidesForwardForBefore() {
        let h = handle(with: [r("a"), r("b"), r("c")])
        h.insert(r("q"), before: r("b"))
        // b leaves
        h.setDeclarative([AnyRoute(r("a")), AnyRoute(r("c"))])
        // q had anchor=b side=.before; b gone → walk fallback forward
        // from b's position → find c → insert before c.
        XCTAssertEqual(ids(h.resolvedStack), ["a", "q", "c"])
    }

    func testAnchorReappearing() {
        let h = handle(with: [r("a"), r("b"), r("c")])
        h.insert(r("q"), after: r("b"))
        // b leaves
        h.setDeclarative([AnyRoute(r("a")), AnyRoute(r("c"))])
        XCTAssertEqual(ids(h.resolvedStack), ["a", "q", "c"])
        // b comes back — q should reattach
        h.setDeclarative([AnyRoute(r("a")), AnyRoute(r("b")), AnyRoute(r("c"))])
        XCTAssertEqual(ids(h.resolvedStack), ["a", "b", "q", "c"])
    }

    func testAnchorFullyGoneSnapsToEdge() {
        let h = handle(with: [r("a"), r("b")])
        h.insert(r("q"), after: r("b"))
        // Wipe all declaratives
        h.setDeclarative([])
        // Nothing in fallback survives → snap to end for .after
        XCTAssertEqual(ids(h.resolvedStack), ["q"])
    }

    // MARK: - List-like declaratives

    func testInsertBetweenListItemsSurvivesListChurn() {
        let h = handle(with: [r("a"), r("x"), r("y"), r("z")])
        h.insert(r("q"), after: r("y"))
        XCTAssertEqual(ids(h.resolvedStack), ["a", "x", "y", "q", "z"])

        // New item w inserted between y and z
        h.setDeclarative([AnyRoute(r("a")), AnyRoute(r("x")),
                          AnyRoute(r("y")), AnyRoute(r("w")), AnyRoute(r("z"))])
        // q anchored .after y → stays right after y
        XCTAssertEqual(ids(h.resolvedStack), ["a", "x", "y", "q", "w", "z"])
    }

    func testInsertBeforeListItemSticksToSuccessor() {
        let h = handle(with: [r("a"), r("x"), r("y"), r("z")])
        h.insert(r("q"), before: r("z"))
        XCTAssertEqual(ids(h.resolvedStack), ["a", "x", "y", "q", "z"])

        // New item w between y and z
        h.setDeclarative([AnyRoute(r("a")), AnyRoute(r("x")),
                          AnyRoute(r("y")), AnyRoute(r("w")), AnyRoute(r("z"))])
        // q anchored .before z → stays right before z
        XCTAssertEqual(ids(h.resolvedStack), ["a", "x", "y", "w", "q", "z"])
    }

    // MARK: - Chained imperatives

    func testChainedImperativesPreserveOrder() {
        let h = handle(with: [r("a")])
        h.push(r("b"))  // after a
        h.push(r("c"))  // after b
        XCTAssertEqual(ids(h.resolvedStack), ["a", "b", "c"])
        // a vanishes → b slides backward to start edge, c follows chain
        h.setDeclarative([])
        XCTAssertEqual(ids(h.resolvedStack), ["b", "c"])
    }

    // MARK: - Replace top

    func testReplaceTopSwapsImperative() {
        let h = handle(with: [r("a")])
        h.push(r("b"))
        h.replaceTop(with: r("c"))
        XCTAssertEqual(ids(h.resolvedStack), ["a", "c"])
    }

    func testReplaceTopOnDeclarativeSuppressesAndPushes() {
        let h = handle(with: [r("a"), r("b")])
        h.replaceTop(with: r("c"))
        // b suppressed, c pushed on top of a
        XCTAssertEqual(ids(h.resolvedStack), ["a", "c"])
    }

    // MARK: - Presentation

    struct SheetTestRoute: Route {
        let name: String
        func body() -> any View { EmptyView() }
        var presentation: RoutePresentation {
            .sheet(detents: [.medium, .large])
        }
    }

    func testDefaultPresentationIsScreen() {
        let h = handle(with: [r("a")])
        guard case .screen = h.resolvedStack[0].presentation else {
            return XCTFail("Expected .screen, got \(h.resolvedStack[0].presentation)")
        }
    }

    func testSheetPresentationPreserved() {
        let h = RouterHandle()
        h.setDeclarative([AnyRoute(SheetTestRoute(name: "s"))])
        guard case .sheet(let detents, _, _, _) = h.resolvedStack[0].presentation else {
            return XCTFail("Expected .sheet")
        }
        XCTAssertEqual(detents.count, 2)
    }

    func testMixedPushSheetOverScreen() {
        let h = handle(with: [r("root")])
        h.push(SheetTestRoute(name: "s"))
        XCTAssertEqual(h.resolvedStack.count, 2)
        guard case .screen = h.resolvedStack[0].presentation,
              case .sheet = h.resolvedStack[1].presentation else {
            return XCTFail("Expected screen then sheet")
        }
    }

    // MARK: - onChange

    func testOnChangeFiresOnPush() {
        var calls = 0
        let h = handle(with: [r("a")])
        h.onChange = { calls += 1 }
        h.push(r("b"))
        XCTAssertEqual(calls, 1)
    }

    func testOnChangeFiresOnDeclarative() {
        var calls = 0
        let h = handle(with: [r("a")])
        h.onChange = { calls += 1 }
        h.setDeclarative([AnyRoute(r("x"))])
        XCTAssertEqual(calls, 1)
    }
}
#endif
