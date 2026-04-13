#if canImport(UIKit)
import XCTest
import UIKit
@testable import ForgeSwift

@MainActor
final class UIViewExtensionTests: XCTestCase {

    // MARK: - constrain

    func testConstrainSetsTranslatesOff() {
        let view = UIView()
        XCTAssertTrue(view.translatesAutoresizingMaskIntoConstraints)
        view.constrain {}
        XCTAssertFalse(view.translatesAutoresizingMaskIntoConstraints)
    }

    func testConstrainReturnsSelf() {
        let view = UIView()
        let result = view.constrain {}
        XCTAssertTrue(result === view)
    }

    func testConstrainBoolTrue() {
        let view = UIView()
        view.constrain(true)
        XCTAssertFalse(view.translatesAutoresizingMaskIntoConstraints)
    }

    func testConstrainBoolFalse() {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.constrain(false)
        XCTAssertTrue(view.translatesAutoresizingMaskIntoConstraints)
    }

    // MARK: - pin

    func testPinAllEdges() {
        let parent = UIView(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
        let child = UIView()
        parent.addSubview(child)
        child.pin(to: parent)

        XCTAssertFalse(child.translatesAutoresizingMaskIntoConstraints)
        let constraints = parent.constraints
        XCTAssertEqual(constraints.count, 4)
    }

    func testPinSingleEdge() {
        let parent = UIView(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
        let child = UIView()
        parent.addSubview(child)
        child.pin(.top, to: parent)

        let constraints = parent.constraints
        XCTAssertEqual(constraints.count, 1)
    }

    func testPinTwoEdges() {
        let parent = UIView(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
        let child = UIView()
        parent.addSubview(child)
        child.pin([.top, .leading], to: parent)

        let constraints = parent.constraints
        XCTAssertEqual(constraints.count, 2)
    }

    func testPinWithOffset() {
        let parent = UIView(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
        let child = UIView()
        parent.addSubview(child)
        child.pin(to: parent, offset: 10)

        let constraints = parent.constraints
        // top=10, leading=10, trailing=-10, bottom=-10
        let topC = constraints.first { $0.firstAttribute == .top }
        let trailingC = constraints.first { $0.firstAttribute == .trailing }
        XCTAssertEqual(topC?.constant, 10)
        XCTAssertEqual(trailingC?.constant, -10)
    }

    // MARK: - center

    func testCenterBothAxes() {
        let parent = UIView(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
        let child = UIView()
        parent.addSubview(child)
        child.center(in: parent)

        let constraints = parent.constraints
        XCTAssertEqual(constraints.count, 2)
    }

    func testCenterXOnly() {
        let parent = UIView(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
        let child = UIView()
        parent.addSubview(child)
        child.center(x: true, y: false, in: parent)

        let constraints = parent.constraints
        XCTAssertEqual(constraints.count, 1)
        XCTAssertEqual(constraints.first?.firstAttribute, .centerX)
    }

    func testCenterYOnly() {
        let parent = UIView(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
        let child = UIView()
        parent.addSubview(child)
        child.center(x: false, y: true, in: parent)

        let constraints = parent.constraints
        XCTAssertEqual(constraints.count, 1)
        XCTAssertEqual(constraints.first?.firstAttribute, .centerY)
    }

    // MARK: - NSLayoutDimension

    func testDimensionEqual() {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        let c = view.widthAnchor.equal(100)
        XCTAssertTrue(c.isActive)
        XCTAssertEqual(c.constant, 100)
        XCTAssertEqual(c.priority, .required)
    }

    func testDimensionEqualWithPriority() {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        let c = view.widthAnchor.equal(100, priority: .defaultLow)
        XCTAssertEqual(c.priority, .defaultLow)
    }

    func testDimensionMin() {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        let c = view.heightAnchor.min(50)
        XCTAssertTrue(c.isActive)
        XCTAssertEqual(c.constant, 50)
        XCTAssertEqual(c.relation, .greaterThanOrEqual)
    }

    func testDimensionMax() {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        let c = view.heightAnchor.max(200)
        XCTAssertTrue(c.isActive)
        XCTAssertEqual(c.constant, 200)
        XCTAssertEqual(c.relation, .lessThanOrEqual)
    }

    func testDimensionEqualToDimension() {
        let parent = UIView()
        let child = UIView()
        parent.addSubview(child)
        child.translatesAutoresizingMaskIntoConstraints = false
        let c = child.widthAnchor.equal(parent.widthAnchor)
        XCTAssertTrue(c.isActive)
    }

    func testDimensionEqualToDimensionWithMultiplier() {
        let parent = UIView()
        let child = UIView()
        parent.addSubview(child)
        child.translatesAutoresizingMaskIntoConstraints = false
        let c = child.widthAnchor.equal(parent.widthAnchor, multiplier: 0.5)
        XCTAssertTrue(c.isActive)
        XCTAssertEqual(c.multiplier, 0.5)
    }

    // MARK: - Axis Anchors

    func testXAnchorEqual() {
        let parent = UIView()
        let child = UIView()
        parent.addSubview(child)
        child.translatesAutoresizingMaskIntoConstraints = false
        let c = child.leadingAnchor.equal(parent.leadingAnchor, offset: 16)
        XCTAssertTrue(c.isActive)
        XCTAssertEqual(c.constant, 16)
    }

    func testXAnchorWithPriority() {
        let parent = UIView()
        let child = UIView()
        parent.addSubview(child)
        child.translatesAutoresizingMaskIntoConstraints = false
        let c = child.leadingAnchor.equal(parent.leadingAnchor, priority: .defaultHigh)
        XCTAssertEqual(c.priority, .defaultHigh)
    }

    func testYAnchorEqual() {
        let parent = UIView()
        let child = UIView()
        parent.addSubview(child)
        child.translatesAutoresizingMaskIntoConstraints = false
        let c = child.topAnchor.equal(parent.topAnchor, offset: 8)
        XCTAssertTrue(c.isActive)
        XCTAssertEqual(c.constant, 8)
    }

    func testYAnchorMin() {
        let parent = UIView()
        let child = UIView()
        parent.addSubview(child)
        child.translatesAutoresizingMaskIntoConstraints = false
        let c = child.topAnchor.min(parent.topAnchor, offset: 20)
        XCTAssertEqual(c.relation, .greaterThanOrEqual)
        XCTAssertEqual(c.constant, 20)
    }

    func testYAnchorMax() {
        let parent = UIView()
        let child = UIView()
        parent.addSubview(child)
        child.translatesAutoresizingMaskIntoConstraints = false
        let c = child.bottomAnchor.max(parent.bottomAnchor)
        XCTAssertEqual(c.relation, .lessThanOrEqual)
    }
}

#endif
