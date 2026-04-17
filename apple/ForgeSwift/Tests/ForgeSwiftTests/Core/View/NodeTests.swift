#if canImport(UIKit)
import XCTest
@testable import ForgeSwift

// MARK: - Test Views

struct TestLeaf: LeafView {
    let label: String
    func makeRenderer() -> Renderer { TestLeafRenderer(label: label) }
}

final class TestLeafRenderer: Renderer {
    private weak var uiLabel: UILabel?
    var label: String {
        didSet {
            guard label != oldValue, let uiLabel else { return }
            uiLabel.text = label
        }
    }
    init(label: String) { self.label = label }
    func update(from view: any View) {
        guard let leaf = view as? TestLeaf else { return }
        label = leaf.label
    }
    func mount() -> PlatformView {
        let l = UILabel(); self.uiLabel = l; l.text = label; return l
    }
}

struct TestComposed: BuiltView {
    let child: any View
    func build(context: ViewContext) -> any View { child }
}

struct TestModel: ModelView {
    let value: String
    func model(context: ViewContext) -> TestViewModel { TestViewModel(context: context) }
    func builder(model: TestViewModel) -> TestBuilder { TestBuilder(model: model) }
}

final class TestViewModel: ViewModel<TestModel> {
    var initCalled = false
    var updateCalled = false
    var unmountCalled = false
    var lastOldValue: String?

    override func didInit(view: TestModel) {
        super.didInit(view: view)
        initCalled = true
    }
    override func didUpdate(newView: TestModel) {
        // self.view is still the previous value at this point;
        // super.didUpdate assigns newView to self.view.
        updateCalled = true
        lastOldValue = view.value
        super.didUpdate(newView: newView)
    }
    override func didDispose() { unmountCalled = true }
}

final class TestBuilder: ViewBuilder<TestViewModel> {
    override func build(context: ViewContext) -> any View {
        TestLeaf(label: model.view.value)
    }
}

struct TestContainer: ContainerView {
    let children: [any View]
    func makeRenderer() -> ContainerRenderer { TestContainerRenderer() }
}

final class TestContainerRenderer: ContainerRenderer {
    func mount() -> PlatformView { UIView() }
    func insert(_ platformView: PlatformView, at index: Int, into container: PlatformView) {
        container.insertSubview(platformView, at: index)
    }
    func remove(_ platformView: PlatformView, from container: PlatformView) {
        platformView.removeFromSuperview()
    }
    func move(_ platformView: PlatformView, to index: Int, in container: PlatformView) {
        platformView.removeFromSuperview()
        container.insertSubview(platformView, at: index)
    }
    func index(of platformView: PlatformView, in container: PlatformView) -> Int? {
        container.subviews.firstIndex(of: platformView)
    }
}

// MARK: - Tests

@MainActor
final class NodeTests: XCTestCase {

    // MARK: - Inflate

    func testInflateLeaf() {
        let node = Node.inflate(TestLeaf(label: "hello"))
        XCTAssertTrue(node is LeafNode)
        XCTAssertNotNil(node.platformView)
        XCTAssertEqual((node.platformView as? UILabel)?.text, "hello")
    }

    func testInflateComposed() {
        let node = Node.inflate(TestComposed(child: TestLeaf(label: "inner")))
        XCTAssertTrue(node is BuiltNode)
        XCTAssertNotNil(node.platformView)
        let built = node as! BuiltNode
        XCTAssertNotNil(built.child)
        XCTAssertTrue(built.child is LeafNode)
    }

    func testInflateModelView() {
        let node = Node.inflate(TestModel(value: "test"))
        XCTAssertTrue(node is ModelNode)
        let modelNode = node as! ModelNode
        XCTAssertNotNil(modelNode.model)
        let model = modelNode.model as! TestViewModel
        XCTAssertTrue(model.initCalled)
    }

    func testInflateContainer() {
        let node = Node.inflate(TestContainer(children: [
            TestLeaf(label: "a"),
            TestLeaf(label: "b"),
        ]))
        XCTAssertTrue(node is ContainerNode)
        let container = node as! ContainerNode
        XCTAssertEqual(container.childNodes.count, 2)
    }

    // MARK: - Update (Leaf)

    func testLeafUpdatePreservesView() {
        let node = Node.inflate(TestLeaf(label: "before"))
        let originalView = node.platformView
        node.update(from: TestLeaf(label: "after"))
        XCTAssertTrue(node.platformView === originalView)
        XCTAssertEqual((node.platformView as? UILabel)?.text, "after")
    }

    // MARK: - Update (Composed)

    func testComposedUpdateRebuilds() {
        let node = Node.inflate(TestComposed(child: TestLeaf(label: "v1")))
        let built = node as! BuiltNode
        let childBefore = built.child

        node.update(from: TestComposed(child: TestLeaf(label: "v2")))

        // Same type child — updated in place
        XCTAssertTrue(built.child === childBefore)
        XCTAssertEqual((built.child?.platformView as? UILabel)?.text, "v2")
    }

    func testComposedUpdateReplacesChildOnTypeChange() {
        let node = Node.inflate(TestComposed(child: TestLeaf(label: "leaf")))
        let built = node as! BuiltNode
        let childBefore = built.child

        node.update(from: TestComposed(child: TestComposed(child: TestLeaf(label: "nested"))))

        // Different type child — replaced
        XCTAssertFalse(built.child === childBefore)
    }

    // MARK: - ModelView Lifecycle

    func testModelViewDidInit() {
        let node = Node.inflate(TestModel(value: "init"))
        let model = (node as! ModelNode).model as! TestViewModel
        XCTAssertTrue(model.initCalled)
        XCTAssertEqual(model.view.value, "init")
    }

    func testModelViewDidUpdate() {
        let node = Node.inflate(TestModel(value: "v1"))
        let model = (node as! ModelNode).model as! TestViewModel

        node.update(from: TestModel(value: "v2"))

        XCTAssertTrue(model.updateCalled)
        XCTAssertEqual(model.lastOldValue, "v1")
        XCTAssertEqual(model.view.value, "v2")
    }

    func testModelViewModelPreservedOnUpdate() {
        let node = Node.inflate(TestModel(value: "v1"))
        let modelBefore = (node as! ModelNode).model

        node.update(from: TestModel(value: "v2"))

        let modelAfter = (node as! ModelNode).model
        XCTAssertTrue(modelBefore === modelAfter)
    }

    func testModelViewWillUnmount() {
        let node = Node.inflate(TestModel(value: "test"))
        let model = (node as! ModelNode).model as! TestViewModel
        (node as! ModelNode).unmount()
        XCTAssertTrue(model.unmountCalled)
    }

    // MARK: - canUpdate

    func testCanUpdateSameType() {
        let node = Node.inflate(TestLeaf(label: "a"))
        XCTAssertTrue(node.canUpdate(to: TestLeaf(label: "b")))
    }

    func testCanUpdateDifferentType() {
        let node = Node.inflate(TestLeaf(label: "a"))
        XCTAssertFalse(node.canUpdate(to: TestComposed(child: TestLeaf(label: "b"))))
    }

    func testCanUpdateWithIdentity() {
        let node = Node.inflate(TestLeaf(label: "a").id(1))
        XCTAssertTrue(node.canUpdate(to: TestLeaf(label: "b").id(2)))
    }

    // MARK: - Identity

    func testIdentityExtracted() {
        let node = Node.inflate(TestLeaf(label: "a").id(42))
        XCTAssertEqual(node.id, AnyHashable(42))
    }

    func testIdentityNilByDefault() {
        let node = Node.inflate(TestLeaf(label: "a"))
        XCTAssertNil(node.id)
    }

    func testIdentityUpdated() {
        let node = Node.inflate(TestLeaf(label: "a").id(1))
        node.update(from: TestLeaf(label: "b").id(2))
        XCTAssertEqual(node.id, AnyHashable(2))
    }

    // MARK: - Container Reconciliation

    func testContainerInsert() {
        let node = Node.inflate(TestContainer(children: [
            TestLeaf(label: "a"),
        ]))
        let container = node as! ContainerNode
        XCTAssertEqual(container.childNodes.count, 1)
    }

    func testContainerUpdateInPlace() {
        let node = Node.inflate(TestContainer(children: [
            TestLeaf(label: "a"),
            TestLeaf(label: "b"),
        ]))
        let container = node as! ContainerNode
        let childA = container.childNodes[0]
        let childB = container.childNodes[1]

        node.update(from: TestContainer(children: [
            TestLeaf(label: "a2"),
            TestLeaf(label: "b2"),
        ]))

        // Same types — updated in place
        XCTAssertTrue(container.childNodes[0] === childA)
        XCTAssertTrue(container.childNodes[1] === childB)
        XCTAssertEqual((container.childNodes[0].platformView as? UILabel)?.text, "a2")
        XCTAssertEqual((container.childNodes[1].platformView as? UILabel)?.text, "b2")
    }

    func testContainerRemoveChild() {
        let node = Node.inflate(TestContainer(children: [
            TestLeaf(label: "a"),
            TestLeaf(label: "b"),
            TestLeaf(label: "c"),
        ]))
        let container = node as! ContainerNode

        node.update(from: TestContainer(children: [
            TestLeaf(label: "a"),
            TestLeaf(label: "c"),
        ]))

        XCTAssertEqual(container.childNodes.count, 2)
    }

    func testContainerAddChild() {
        let node = Node.inflate(TestContainer(children: [
            TestLeaf(label: "a"),
        ]))
        let container = node as! ContainerNode

        node.update(from: TestContainer(children: [
            TestLeaf(label: "a"),
            TestLeaf(label: "b"),
        ]))

        XCTAssertEqual(container.childNodes.count, 2)
    }

    func testContainerIdBasedReorder() {
        let node = Node.inflate(TestContainer(children: [
            TestLeaf(label: "first").id(1),
            TestLeaf(label: "second").id(2),
        ]))
        let container = node as! ContainerNode
        let nodeForId1 = container.childNodes[0]
        let nodeForId2 = container.childNodes[1]

        node.update(from: TestContainer(children: [
            TestLeaf(label: "second-updated").id(2),
            TestLeaf(label: "first-updated").id(1),
        ]))

        // Nodes should be preserved and reordered
        XCTAssertTrue(container.childNodes[0] === nodeForId2)
        XCTAssertTrue(container.childNodes[1] === nodeForId1)
        XCTAssertEqual((container.childNodes[0].platformView as? UILabel)?.text, "second-updated")
        XCTAssertEqual((container.childNodes[1].platformView as? UILabel)?.text, "first-updated")
    }

    func testContainerEmptyToChildren() {
        let node = Node.inflate(TestContainer(children: []))
        let container = node as! ContainerNode
        XCTAssertEqual(container.childNodes.count, 0)

        node.update(from: TestContainer(children: [TestLeaf(label: "a")]))
        XCTAssertEqual(container.childNodes.count, 1)
    }

    func testContainerChildrenToEmpty() {
        let node = Node.inflate(TestContainer(children: [
            TestLeaf(label: "a"),
            TestLeaf(label: "b"),
        ]))
        let container = node as! ContainerNode

        node.update(from: TestContainer(children: []))
        XCTAssertEqual(container.childNodes.count, 0)
    }

    // MARK: - Resolver

    func testResolverMount() {
        let resolver = Resolver()
        let view = resolver.mount(TestLeaf(label: "root"))
        XCTAssertNotNil(view)
        XCTAssertEqual((view as? UILabel)?.text, "root")
    }

    // MARK: - Observable

    func testObservableWatch() {
        let obs = Observable(0)
        let node = Node.inflate(TestLeaf(label: ""))
        let value = node.watch(obs)
        XCTAssertEqual(value, 0)
    }
}

#endif
