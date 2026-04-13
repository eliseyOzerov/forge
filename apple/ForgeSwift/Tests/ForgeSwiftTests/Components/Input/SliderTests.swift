#if canImport(UIKit)
import XCTest
import UIKit
@testable import ForgeSwift

@MainActor
final class SliderTests: XCTestCase {

    private func makeModel(
        value: Double = 0.5,
        range: ClosedRange<Double> = 0...1,
        states: UIState = .idle
    ) -> SliderModel {
        let binding = Binding(value)
        let slider = Slider(value: binding, range: range, states: states)
        let model = SliderModel()
        model.handleDidInit(slider)
        return model
    }

    // MARK: - Normalized

    func testNormalizedMidpoint() {
        let model = makeModel(value: 0.5, range: 0...1)
        XCTAssertEqual(model.normalized, 0.5, accuracy: 0.001)
    }

    func testNormalizedMin() {
        let model = makeModel(value: 0, range: 0...100)
        XCTAssertEqual(model.normalized, 0, accuracy: 0.001)
    }

    func testNormalizedMax() {
        let model = makeModel(value: 100, range: 0...100)
        XCTAssertEqual(model.normalized, 1, accuracy: 0.001)
    }

    func testNormalizedCustomRange() {
        let model = makeModel(value: 50, range: 0...200)
        XCTAssertEqual(model.normalized, 0.25, accuracy: 0.001)
    }

    // MARK: - Set Normalized

    func testSetNormalizedUpdatesValue() {
        let model = makeModel(value: 0, range: 0...100)
        model.setNormalized(0.5)
        XCTAssertEqual(model.view.value.value, 50, accuracy: 0.1)
    }

    func testSetNormalizedClampsLow() {
        let model = makeModel(value: 50, range: 0...100)
        model.setNormalized(-0.5)
        XCTAssertEqual(model.view.value.value, 0, accuracy: 0.1)
    }

    func testSetNormalizedClampsHigh() {
        let model = makeModel(value: 50, range: 0...100)
        model.setNormalized(1.5)
        XCTAssertEqual(model.view.value.value, 100, accuracy: 0.1)
    }

    // MARK: - State

    func testDefaultNotPressed() {
        let model = makeModel()
        XCTAssertFalse(model.isPressed)
    }

    func testPressSetsPressed() {
        let model = makeModel()
        model.handlePress(at: 0.5)
        XCTAssertTrue(model.isPressed)
    }

    func testReleaseClearsPressed() {
        let model = makeModel()
        model.handlePress(at: 0.5)
        model.handleRelease()
        XCTAssertFalse(model.isPressed)
    }

    func testDisabledBlocksPress() {
        let model = makeModel(states: .disabled)
        model.handlePress(at: 0.5)
        XCTAssertFalse(model.isPressed)
    }

    // MARK: - Drag

    func testDragUpdatesValue() {
        let model = makeModel(value: 0, range: 0...100)
        model.handlePress(at: 0)
        model.handleDrag(at: 0.75)
        XCTAssertEqual(model.view.value.value, 75, accuracy: 0.1)
    }

    func testDragWithoutPressIgnored() {
        let model = makeModel(value: 50, range: 0...100)
        model.handleDrag(at: 0.75)
        XCTAssertEqual(model.view.value.value, 50, accuracy: 0.1)
    }

    // MARK: - Division Snapping

    func testDivisionMagnetSnaps() {
        let trackStyle = TrackStyle(divisions: TrackDivisions(count: 4, magnetStrength: 1.0))
        let style = SliderStyle(track: .constant(trackStyle))
        let binding = Binding(0.0)
        let slider = Slider(value: binding, range: 0...1, style: .constant(style))
        let model = SliderModel()
        model.handleDidInit(slider)
        // Set to 0.26 — with 4 divisions (0, 0.25, 0.5, 0.75, 1.0), snaps to 0.25
        model.setNormalized(0.26)
        XCTAssertEqual(model.view.value.value, 0.25, accuracy: 0.01)
    }

    func testDivisionNoMagnet() {
        let trackStyle = TrackStyle(divisions: TrackDivisions(count: 4, magnetStrength: 0))
        let style = SliderStyle(track: .constant(trackStyle))
        let binding = Binding(0.0)
        let slider = Slider(value: binding, range: 0...1, style: .constant(style))
        let model = SliderModel()
        model.handleDidInit(slider)
        model.setNormalized(0.26)
        XCTAssertEqual(model.view.value.value, 0.26, accuracy: 0.01)
    }

    // MARK: - Style Defaults

    func testSliderStyleDefaults() {
        let style = SliderStyle()
        XCTAssertTrue(style.axis == .horizontal)
        XCTAssertEqual(style.haptic, .light)
    }

    func testTrackStyleDefaults() {
        let track = TrackStyle()
        XCTAssertNil(track.divisions)
        XCTAssertNil(track.mark)
    }

    func testThumbStyleDefaults() {
        let thumb = ThumbStyle()
        XCTAssertNil(thumb.label)
    }

    // MARK: - SliderView

    func testSliderViewAccessibility() {
        let view = SliderView()
        XCTAssertTrue(view.isAccessibilityElement)
        XCTAssertTrue(view.accessibilityTraits.contains(.adjustable))
    }
}

#endif
