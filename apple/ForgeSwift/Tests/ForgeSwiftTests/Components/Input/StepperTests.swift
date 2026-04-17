#if canImport(UIKit)
import XCTest
import UIKit
@testable import ForgeSwift

@MainActor
final class StepperTests: XCTestCase {

    // MARK: - Helpers

    private func makeModel(
        value: Int = 5,
        range: ClosedRange<Int> = 0...10,
        step: Int = 1,
        states: State = .idle
    ) -> StepperModel<Int> {
        let binding = Binding(value)
        let stepper = Stepper(value: binding, range: range, step: step, states: states)
        let context = BuiltNode()
        let model = StepperModel<Int>(context: context)
        model.didInit(view: stepper)
        return model
    }

    // MARK: - Increment / Decrement

    func testIncrement() {
        let model = makeModel(value: 5)
        model.increment()
        XCTAssertEqual(model.currentValue, 6)
    }

    func testDecrement() {
        let model = makeModel(value: 5)
        model.decrement()
        XCTAssertEqual(model.currentValue, 4)
    }

    func testIncrementClampsToMax() {
        let model = makeModel(value: 10, range: 0...10)
        model.increment()
        XCTAssertEqual(model.currentValue, 10)
    }

    func testDecrementClampsToMin() {
        let model = makeModel(value: 0, range: 0...10)
        model.decrement()
        XCTAssertEqual(model.currentValue, 0)
    }

    func testIncrementWithStep() {
        let model = makeModel(value: 5, step: 3)
        model.increment()
        XCTAssertEqual(model.currentValue, 8)
    }

    func testIncrementClampsPastMax() {
        let model = makeModel(value: 9, range: 0...10, step: 3)
        model.increment()
        XCTAssertEqual(model.currentValue, 10)
    }

    // MARK: - atMin / atMax

    func testAtMinTrue() {
        let model = makeModel(value: 0, range: 0...10)
        XCTAssertTrue(model.atMin)
    }

    func testAtMinFalse() {
        let model = makeModel(value: 5, range: 0...10)
        XCTAssertFalse(model.atMin)
    }

    func testAtMaxTrue() {
        let model = makeModel(value: 10, range: 0...10)
        XCTAssertTrue(model.atMax)
    }

    func testAtMaxFalse() {
        let model = makeModel(value: 5, range: 0...10)
        XCTAssertFalse(model.atMax)
    }

    // MARK: - Disabled / Loading

    func testDisabledBlocksIncrement() {
        let model = makeModel(value: 5, states: .disabled)
        model.increment()
        XCTAssertEqual(model.currentValue, 5)
    }

    func testLoadingBlocksDecrement() {
        let model = makeModel(value: 5, states: .loading)
        model.decrement()
        XCTAssertEqual(model.currentValue, 5)
    }

    // MARK: - Drag

    func testDragIncrement() {
        let model = makeModel(value: 5)
        // Default sensitivity = 10, vertical. Negative delta = drag up = increment.
        model.handleDrag(delta: -10)
        XCTAssertEqual(model.currentValue, 6)
    }

    func testDragDecrement() {
        let model = makeModel(value: 5)
        model.handleDrag(delta: 10)
        XCTAssertEqual(model.currentValue, 4)
    }

    func testDragAccumulates() {
        let model = makeModel(value: 5)
        model.handleDrag(delta: -3)
        XCTAssertEqual(model.currentValue, 5) // not enough yet
        model.handleDrag(delta: -7)
        XCTAssertEqual(model.currentValue, 6) // accumulated to 10
    }

    func testDragResets() {
        let model = makeModel(value: 5)
        model.handleDrag(delta: -5)
        model.resetDrag()
        model.handleDrag(delta: -5)
        XCTAssertEqual(model.currentValue, 5) // accumulator was reset
    }

    func testDragClampsToRange() {
        let model = makeModel(value: 10, range: 0...10)
        model.handleDrag(delta: -100)
        XCTAssertEqual(model.currentValue, 10)
    }

    // MARK: - Text Changed

    func testTextChangedParsesValue() {
        let model = makeModel(value: 5)
        model.textChanged("8")
        XCTAssertEqual(model.currentValue, 8)
    }

    func testTextChangedClampsToRange() {
        let model = makeModel(value: 5, range: 0...10)
        model.textChanged("99")
        XCTAssertEqual(model.currentValue, 10)
    }

    func testTextChangedInvalidIgnored() {
        let model = makeModel(value: 5)
        model.textChanged("abc")
        XCTAssertEqual(model.currentValue, 5)
    }

    // MARK: - Display Text

    func testDisplayTextDefault() {
        let model = makeModel(value: 42)
        XCTAssertEqual(model.displayText(), "42")
    }

    func testDisplayTextWithFormatter() {
        let binding = Binding(5)
        let style = StepperStyle<Int>(formatter: TextFormatter { "Value: \($0)" })
        let stepper = Stepper(value: binding, range: 0...10, step: 1, style: .constant(style))
        let context = BuiltNode()
        let model = StepperModel<Int>(context: context)
        model.didInit(view: stepper)
        XCTAssertEqual(model.displayText(), "Value: 5")
    }

    // MARK: - Editing State

    func testSetEditingTrue() {
        let model = makeModel()
        model.setEditing(true)
        XCTAssertTrue(model.isEditing)
        XCTAssertTrue(model.currentState.contains(.focused))
    }

    func testSetEditingFalse() {
        let model = makeModel()
        model.setEditing(true)
        model.setEditing(false)
        XCTAssertFalse(model.isEditing)
    }

    // MARK: - Config Defaults

    func testLongPressConfigDefaults() {
        let c = LongPressConfig.default
        XCTAssertEqual(c.delay, 0.5)
        XCTAssertEqual(c.interval, 0.15)
        XCTAssertEqual(c.acceleration, 0.9)
    }

    func testDragConfigDefaults() {
        let c = DragConfig.default
        XCTAssertEqual(c.sensitivity, 10)
        XCTAssertTrue(c.enabled)
    }

    func testValueTransitionDefaults() {
        let t = ValueTransition.default
        XCTAssertEqual(t.animation.duration, 0.1)
    }

    // MARK: - StepperFieldView

    func testFieldViewAccessibilityTraits() {
        let view = StepperFieldView<Int>()
        XCTAssertTrue(view.accessibilityTraits.contains(.adjustable))
    }

    func testFieldViewIsAccessibilityElement() {
        let view = StepperFieldView<Int>()
        XCTAssertTrue(view.isAccessibilityElement)
    }
}

#endif
