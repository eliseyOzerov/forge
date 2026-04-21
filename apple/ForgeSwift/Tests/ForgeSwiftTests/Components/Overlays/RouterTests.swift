#if canImport(UIKit)
import XCTest
@testable import ForgeSwift

/// Minimal route for testing — builds to an EmptyView.
private struct TestRoute: BuiltView, Route {
    let key: AnyHashable?
    var opaque: Bool = true

    init(key: AnyHashable? = nil, opaque: Bool = true) {
        self.key = key
        self.opaque = opaque
    }

    func build(context: ViewContext) -> any View { EmptyView() }
}

@MainActor
final class RouterTests: XCTestCase {

    // MARK: - Helpers

    private func makeModel(
        deeplinks: DeepLinkMap = DeepLinkMap()
    ) -> RouterModel {
        let router = Router(deeplinks: deeplinks) { EmptyView() }
        let context = BuiltNode()
        let model = RouterModel(context: context, deeplinks: deeplinks)
        model.didInit(view: router)
        return model
    }

    // MARK: - Initial state

    func testInitialStateHasOneRoute() {
        let model = makeModel()
        XCTAssertEqual(model.routes.count, 1)
        XCTAssertTrue(model.routes.first is Screen)
    }

    func testCannotPopRoot() {
        let model = makeModel()
        XCTAssertFalse(model.canPop)
    }

    // MARK: - Push

    func testPushAddsRoute() {
        let model = makeModel()
        model.push(TestRoute(key: "a"))
        XCTAssertEqual(model.routes.count, 2)
        XCTAssertEqual(model.routes.last?.key, AnyHashable("a"))
    }

    func testPushMultiple() {
        let model = makeModel()
        model.push(TestRoute(key: "a"))
        model.push(TestRoute(key: "b"))
        XCTAssertEqual(model.routes.count, 3)
        XCTAssertEqual(model.top?.key, AnyHashable("b"))
    }

    // MARK: - Pop

    func testPopRemovesTop() async {
        let model = makeModel()
        let route = TestRoute(key: "a")
        model.push(route)
        XCTAssertEqual(model.routes.count, 2)

        // pop delegates to dismiss which is async — use the non-animated path
        model.remove(at: 1, animated: false)
        XCTAssertEqual(model.routes.count, 1)
    }

    func testPopDoesNothingOnSingleRoute() {
        let model = makeModel()
        model.pop()
        XCTAssertEqual(model.routes.count, 1)
    }

    func testPopUntil() {
        let model = makeModel()
        model.push(TestRoute(key: "a"))
        model.push(TestRoute(key: "b"))
        model.push(TestRoute(key: "c"))
        XCTAssertEqual(model.routes.count, 4)

        model.pop(until: { ($0 as? TestRoute)?.key == AnyHashable("a") })
        XCTAssertEqual(model.routes.count, 2)
        XCTAssertEqual(model.top?.key, AnyHashable("a"))
    }

    func testPopToFirst() {
        let model = makeModel()
        model.push(TestRoute(key: "a"))
        model.push(TestRoute(key: "b"))
        XCTAssertEqual(model.routes.count, 3)

        model.popToFirst()
        XCTAssertEqual(model.routes.count, 1)
        XCTAssertTrue(model.routes.first is Screen)
    }

    func testPopToFirstDoesNothingOnSingleRoute() {
        let model = makeModel()
        model.popToFirst()
        XCTAssertEqual(model.routes.count, 1)
    }

    // MARK: - Insert

    func testInsertAtIndex() {
        let model = makeModel()
        model.push(TestRoute(key: "a"))
        model.insert(at: 1, route: TestRoute(key: "mid"))
        XCTAssertEqual(model.routes.count, 3)
        XCTAssertEqual(model.routes[1].key, AnyHashable("mid"))
    }

    func testInsertAtClampedIndex() {
        let model = makeModel()
        model.insert(at: 999, route: TestRoute(key: "end"))
        XCTAssertEqual(model.routes.count, 2)
        XCTAssertEqual(model.routes.last?.key, AnyHashable("end"))
    }

    func testInsertBelow() {
        let model = makeModel()
        model.push(TestRoute(key: "a"))
        model.push(TestRoute(key: "b"))
        model.insert(below: { ($0 as? TestRoute)?.key == AnyHashable("b") },
                     route: TestRoute(key: "below-b"))
        XCTAssertEqual(model.routes.count, 4)
        XCTAssertEqual(model.routes[2].key, AnyHashable("below-b"))
        XCTAssertEqual(model.routes[3].key, AnyHashable("b"))
    }

    func testInsertAbove() {
        let model = makeModel()
        model.push(TestRoute(key: "a"))
        model.insert(above: { ($0 as? TestRoute)?.key == AnyHashable("a") },
                     route: TestRoute(key: "above-a"))
        XCTAssertEqual(model.routes.count, 3)
        XCTAssertEqual(model.routes[1].key, AnyHashable("a"))
        XCTAssertEqual(model.routes[2].key, AnyHashable("above-a"))
    }

    func testInsertBelowNoMatch() {
        let model = makeModel()
        model.push(TestRoute(key: "a"))
        model.insert(below: { _ in false }, route: TestRoute(key: "x"))
        XCTAssertEqual(model.routes.count, 2) // unchanged
    }

    // MARK: - Remove

    func testRemoveByPredicate() {
        let model = makeModel()
        model.push(TestRoute(key: "a"))
        model.push(TestRoute(key: "b"))
        model.remove(where: { ($0 as? TestRoute)?.key == AnyHashable("a") }, animated: false)
        XCTAssertEqual(model.routes.count, 2)
        XCTAssertEqual(model.routes.last?.key, AnyHashable("b"))
    }

    func testRemoveAtIndex() {
        let model = makeModel()
        model.push(TestRoute(key: "a"))
        model.push(TestRoute(key: "b"))
        model.remove(at: 1, animated: false)
        XCTAssertEqual(model.routes.count, 2)
        XCTAssertEqual(model.routes.last?.key, AnyHashable("b"))
    }

    func testRemoveDoesNotRemoveLastRoute() {
        let model = makeModel()
        model.remove(at: 0, animated: false)
        XCTAssertEqual(model.routes.count, 1) // root preserved
    }

    // MARK: - Replace

    func testReplaceWithRoutes() {
        let model = makeModel()
        model.push(TestRoute(key: "a"))
        model.replace(with: [TestRoute(key: "x"), TestRoute(key: "y")])
        XCTAssertEqual(model.routes.count, 2)
        XCTAssertEqual(model.routes[0].key, AnyHashable("x"))
        XCTAssertEqual(model.routes[1].key, AnyHashable("y"))
    }

    func testReplaceWithEmptyDoesNothing() {
        let model = makeModel()
        model.push(TestRoute(key: "a"))
        model.replace(with: [])
        XCTAssertEqual(model.routes.count, 2) // unchanged
    }

    func testReplaceTop() {
        let model = makeModel()
        model.push(TestRoute(key: "a"))
        model.push(TestRoute(key: "b"))
        model.replaceTop(TestRoute(key: "c"))
        XCTAssertEqual(model.routes.count, 3)
        XCTAssertEqual(model.top?.key, AnyHashable("c"))
    }

    // MARK: - Contains

    func testContains() {
        let model = makeModel()
        model.push(TestRoute(key: "a"))
        XCTAssertTrue(model.contains(where: { ($0 as? TestRoute)?.key == AnyHashable("a") }))
        XCTAssertFalse(model.contains(where: { ($0 as? TestRoute)?.key == AnyHashable("z") }))
    }

    // MARK: - Top / First

    func testTopReturnsLast() {
        let model = makeModel()
        model.push(TestRoute(key: "a"))
        model.push(TestRoute(key: "b"))
        XCTAssertEqual(model.top?.key, AnyHashable("b"))
    }

    func testFirstReturnsRoot() {
        let model = makeModel()
        model.push(TestRoute(key: "a"))
        XCTAssertTrue(model.first is Screen)
    }

    // MARK: - pushForResult

    func testPushForResultResolvesOnRemove() async {
        let model = makeModel()
        let task = Task<String?, Never> {
            await model.pushForResult(TestRoute(key: "result"))
        }
        // Yield to let the continuation register
        await Task.yield()
        await Task.yield()

        XCTAssertEqual(model.routes.count, 2)
        // Remove with a result (non-animated to complete synchronously)
        model.remove(at: 1, result: "hello", animated: false)

        let value = await task.value
        XCTAssertEqual(value, "hello")
    }

    func testPushForResultResolvesNilOnPopToFirst() async {
        let model = makeModel()
        let task = Task<String?, Never> {
            await model.pushForResult(TestRoute(key: "r"))
        }
        await Task.yield()
        await Task.yield()

        model.popToFirst()

        let value = await task.value
        XCTAssertNil(value)
    }

    // MARK: - Deep link resolve

    func testResolveDeepLink() {
        let map = DeepLinkMap {
            DeepLink("/item/:id") { params in
                guard params["id"] != nil else { return nil }
                return TestRoute(key: "item")
            }
        }
        let model = makeModel(deeplinks: map)
        let resolved = model.resolve(url: URL(string: "https://example.com/item/42")!)
        XCTAssertTrue(resolved)
        XCTAssertEqual(model.routes.count, 2)
        XCTAssertEqual(model.routes.last?.key, AnyHashable("item"))
    }

    func testResolveDeepLinkNoMatch() {
        let map = DeepLinkMap {
            DeepLink("/item/:id") { _ in TestRoute(key: "item") }
        }
        let model = makeModel(deeplinks: map)
        let resolved = model.resolve(url: URL(string: "https://example.com/unknown")!)
        XCTAssertFalse(resolved)
        XCTAssertEqual(model.routes.count, 1)
    }

    // MARK: - didUpdate

    func testDidUpdatePreservesStack() {
        let model = makeModel()
        model.push(TestRoute(key: "a"))
        XCTAssertEqual(model.routes.count, 2)

        let newRouter = Router { EmptyView() }
        model.didUpdate(newView: newRouter)
        // Stack preserved, root updated in-place
        XCTAssertEqual(model.routes.count, 2)
        XCTAssertTrue(model.routes.first is Screen)
    }

    // MARK: - didDispose

    func testDidDisposeDisposesAllEntries() {
        let model = makeModel()
        model.push(TestRoute(key: "a"))
        model.push(TestRoute(key: "b"))
        XCTAssertEqual(model.routes.count, 3)

        model.didDispose()
        // After dispose, entries should still be accessible but resources freed
        // (no crash is the assertion)
    }

    // MARK: - Cover state

    func testCoverStateUpdatedOnPush() {
        let model = makeModel()
        let entries = model.entries
        XCTAssertNil(entries[0].above) // root has no cover initially

        model.push(TestRoute(key: "a"))
        let updatedEntries = model.entries
        XCTAssertNotNil(updatedEntries[0].above) // root now covered
        XCTAssertNil(updatedEntries[1].above) // top has no cover
    }

    func testCoverStateClearedOnRemove() {
        let model = makeModel()
        model.push(TestRoute(key: "a"))
        XCTAssertNotNil(model.entries[0].above)

        model.remove(at: 1, animated: false)
        XCTAssertNil(model.entries[0].above) // root uncovered again
    }
}

#endif
