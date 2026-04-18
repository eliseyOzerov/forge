#if canImport(UIKit)
import XCTest
@testable import ForgeSwift

// MARK: - Test fixtures

private struct Theme: Equatable {
    let name: String
}

private final class Counter {
    var value: Int
    init(_ value: Int) { self.value = value }
}

/// Records every value seen by a build pass. Lets tests assert on
/// rebuild behavior without poking at Node internals.
private final class BuildLog<T> {
    var values: [T] = []
}

@MainActor
final class ProvidedTests: XCTestCase {

    /// Yield enough times for the dirty-mark Task on the main actor to
    /// run. Node.markDirty schedules rebuild via Task { @MainActor },
    /// so tests must yield before asserting on rebuild side effects.
    private func flushRebuilds() async {
        for _ in 0..<5 { await Task.yield() }
    }

    // MARK: - read

    func testReadFindsAncestorValue() {
        let log = BuildLog<Theme>()
        let tree = Provided(Theme(name: "light")) {
            Buildable { ctx in
                log.values.append(ctx.read(Theme.self))
                return TestLeaf(label: "")
            }
        }
        _ = Node.inflate(tree)
        XCTAssertEqual(log.values, [Theme(name: "light")])
    }

    func testReadFindsNearestAncestor() {
        let log = BuildLog<Theme>()
        let tree = Provided(Theme(name: "outer")) {
            Provided(Theme(name: "inner")) {
                Buildable { ctx in
                    log.values.append(ctx.read(Theme.self))
                    return TestLeaf(label: "")
                }
            }
        }
        _ = Node.inflate(tree)
        XCTAssertEqual(log.values, [Theme(name: "inner")])
    }

    func testReadAcrossDeepTree() {
        let log = BuildLog<Theme>()
        let tree = Provided(Theme(name: "deep")) {
            TestComposed(child:
                TestComposed(child:
                    TestComposed(child:
                        Buildable { ctx in
                            log.values.append(ctx.read(Theme.self))
                            return TestLeaf(label: "")
                        }
                    )
                )
            )
        }
        _ = Node.inflate(tree)
        XCTAssertEqual(log.values, [Theme(name: "deep")])
    }

    // MARK: - rebuild on provider value replacement

    func testConsumerRebuildsWhenProviderValueChanges() async {
        let log = BuildLog<Theme>()
        let consumer = Buildable { ctx in
            log.values.append(ctx.read(Theme.self))
            return TestLeaf(label: "")
        }

        let node = Node.inflate(Provided(Theme(name: "v1")) { consumer })
        XCTAssertEqual(log.values, [Theme(name: "v1")])

        node.update(from: Provided(Theme(name: "v2")) { consumer })
        await flushRebuilds()

        // First rebuild is the sync subtree update from the parent;
        // the slot write also schedules an async rebuild. Either way,
        // the most recent value seen must be v2.
        XCTAssertEqual(log.values.last, Theme(name: "v2"))
        XCTAssertGreaterThanOrEqual(log.values.count, 2)
    }

    // MARK: - watch with observable value

    func testWatchRebuildsOnInPlaceObservableChange() async {
        let store = Observable(Counter(0))
        let log = BuildLog<Int>()
        let tree = Provided(store) {
            Buildable { ctx in
                let s = ctx.watch(Observable<Counter>.self)
                log.values.append(s.value.value)
                return TestLeaf(label: "")
            }
        }
        let node = Node.inflate(tree)
        _ = node  // retained — async rebuild needs the node alive
        XCTAssertEqual(log.values, [0])

        // Mutate-in-place: replace the observable's value with a new
        // Counter holding 1. The provider's slot didn't change (still
        // the same Observable instance), but the value-observable
        // subscription should fire.
        store.value = Counter(1)
        await flushRebuilds()

        XCTAssertEqual(log.values.last, 1)
        XCTAssertGreaterThanOrEqual(log.values.count, 2)
    }

    // MARK: - tryWatch

    func testTryWatchReturnsNilWhenAbsent() {
        let log = BuildLog<Theme?>()
        let tree = Buildable { ctx in
            log.values.append(ctx.tryWatch(Theme.self))
            return TestLeaf(label: "")
        }
        _ = Node.inflate(tree)
        XCTAssertEqual(log.values.count, 1)
        XCTAssertNil(log.values[0])
    }

    func testTryWatchReturnsValueWhenPresent() {
        let log = BuildLog<Theme?>()
        let tree = Provided(Theme(name: "found")) {
            Buildable { ctx in
                log.values.append(ctx.tryWatch(Theme.self))
                return TestLeaf(label: "")
            }
        }
        _ = Node.inflate(tree)
        XCTAssertEqual(log.values, [Theme(name: "found")])
    }

    // MARK: - Variadic

    func testVariadicProvidesMultipleTypes() {
        struct Locale: Equatable { let code: String }
        struct Session: Equatable { let user: String }

        let log = BuildLog<String>()
        let tree = Provided(Theme(name: "dark"), Locale(code: "en"), Session(user: "alice")) {
            Buildable { ctx in
                let theme = ctx.read(Theme.self)
                let locale = ctx.read(Locale.self)
                let session = ctx.read(Session.self)
                log.values.append("\(theme.name)/\(locale.code)/\(session.user)")
                return TestLeaf(label: "")
            }
        }
        _ = Node.inflate(tree)
        XCTAssertEqual(log.values, ["dark/en/alice"])
    }

    // MARK: - Slot install/update mechanics

    func testInstallSlotCreatesThenUpdates() {
        let node = Node.inflate(TestLeaf(label: ""))
        node.installSlot(Theme(name: "first"))
        let slot = node.findSlot(Theme.self)
        XCTAssertNotNil(slot)
        XCTAssertEqual(slot?.observable.value, Theme(name: "first"))

        node.installSlot(Theme(name: "second"))
        // Same slot instance — second install updates the observable
        // rather than replacing it (so existing observers stay attached).
        XCTAssertTrue(node.findSlot(Theme.self) === slot)
        XCTAssertEqual(slot?.observable.value, Theme(name: "second"))
    }

    func testFindSlotWalksParentChain() {
        let parent = Node.inflate(TestLeaf(label: ""))
        let child = Node.inflate(TestLeaf(label: ""), parent: parent)
        parent.installSlot(Theme(name: "from-parent"))

        XCTAssertEqual(child.findSlot(Theme.self)?.observable.value,
                       Theme(name: "from-parent"))
    }

    func testFindSlotReturnsNilWhenNoneInChain() {
        let parent = Node.inflate(TestLeaf(label: ""))
        let child = Node.inflate(TestLeaf(label: ""), parent: parent)
        XCTAssertNil(child.findSlot(Theme.self))
    }
}

#endif
