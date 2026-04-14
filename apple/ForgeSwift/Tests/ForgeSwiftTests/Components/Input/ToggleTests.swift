#if canImport(UIKit)
import XCTest
import UIKit
@testable import ForgeSwift

@MainActor
final class ToggleTests: XCTestCase {

    // MARK: - Helpers

    private func makeModel(isOn: Bool = false) -> ToggleModel {
        let binding = Binding(isOn)
        let toggle = Toggle.checkbox(value: binding)
        let model = ToggleModel()
        model.handleDidInit(toggle)
        return model
    }

    // MARK: - Curve

    func testCurveLinear() {
        XCTAssertEqual(Curve.linear(0.5), 0.5, accuracy: 0.001)
        XCTAssertEqual(Curve.linear(0), 0, accuracy: 0.001)
        XCTAssertEqual(Curve.linear(1), 1, accuracy: 0.001)
    }

    func testCurveEaseInOut() {
        XCTAssertEqual(Curve.easeInOut(0), 0, accuracy: 0.001)
        XCTAssertEqual(Curve.easeInOut(1), 1, accuracy: 0.001)
        XCTAssertEqual(Curve.easeInOut(0.5), 0.5, accuracy: 0.01)
        // Ease in starts slow
        XCTAssertLessThan(Curve.easeInOut(0.25), 0.25)
    }

    func testCurveOvershoot() {
        XCTAssertEqual(Curve.overshoot(0), 0, accuracy: 0.01)
        XCTAssertEqual(Curve.overshoot(1), 1, accuracy: 0.01)
        // Overshoots past 1
        XCTAssertGreaterThan(Curve.overshoot(0.8), 1.0)
    }

    func testCurveBounce() {
        XCTAssertEqual(Curve.bounce(0), 0, accuracy: 0.001)
        XCTAssertEqual(Curve.bounce(1), 1, accuracy: 0.001)
        XCTAssertGreaterThan(Curve.bounce(0.5), 0)
    }

    // MARK: - Bezier

    func testBezierLinear() {
        let c = Curve.bezier(0, 0, 1, 1) // linear
        XCTAssertEqual(c(0), 0, accuracy: 0.01)
        XCTAssertEqual(c(0.5), 0.5, accuracy: 0.05)
        XCTAssertEqual(c(1), 1, accuracy: 0.01)
    }

    func testBezierEaseInOut() {
        let c = Curve.bezier(0.42, 0, 0.58, 1) // CSS ease-in-out
        XCTAssertEqual(c(0), 0, accuracy: 0.01)
        XCTAssertEqual(c(1), 1, accuracy: 0.01)
        // Should be slower at start
        XCTAssertLessThan(c(0.25), 0.25)
    }

    // MARK: - Keyframes

    func testKeyframesTwoStops() {
        let c = Curve.keyframes([(0, 0), (1, 1)], curve: .linear)
        XCTAssertEqual(c(0), 0, accuracy: 0.001)
        XCTAssertEqual(c(0.5), 0.5, accuracy: 0.001)
        XCTAssertEqual(c(1), 1, accuracy: 0.001)
    }

    func testKeyframesOvershootSettle() {
        let c = Curve.keyframes([
            (0, 0), (0.6, 1.1), (0.8, 0.95), (1.0, 1.0)
        ], curve: .linear)
        XCTAssertEqual(c(0), 0, accuracy: 0.001)
        XCTAssertEqual(c(0.6), 1.1, accuracy: 0.001)
        XCTAssertEqual(c(1.0), 1.0, accuracy: 0.001)
        // At 0.7 (between 0.6→0.8), should be between 1.1 and 0.95
        let mid = c(0.7)
        XCTAssertLessThan(mid, 1.1)
        XCTAssertGreaterThan(mid, 0.95)
    }

    func testKeyframesPerSegmentCurves() {
        let c = Curve.keyframes([
            (0, 0), (0.5, 1), (1.0, 0)
        ], curves: [.easeIn, .easeOut])
        XCTAssertEqual(c(0), 0, accuracy: 0.001)
        XCTAssertEqual(c(0.5), 1, accuracy: 0.001)
        XCTAssertEqual(c(1), 0, accuracy: 0.001)
    }

    func testKeyframesHoldBeyondStops() {
        let c = Curve.keyframes([(0.2, 5), (0.8, 10)], curve: .linear)
        XCTAssertEqual(c(0), 5, accuracy: 0.001)   // hold first value
        XCTAssertEqual(c(1), 10, accuracy: 0.001)  // hold last value
    }

    // MARK: - Animation

    func testAnimationDefaults() {
        let a = Animation.default
        XCTAssertEqual(a.duration, 0.2)
        XCTAssertEqual(a.delay, 0)
    }

    func testAnimationNone() {
        XCTAssertEqual(Animation.none.duration, 0)
    }

    func testAnimationApply() {
        let a = Animation(curve: .linear)
        XCTAssertEqual(a.apply(0.5), 0.5, accuracy: 0.001)
    }

    // MARK: - Track

    func testTrackDefaults() {
        let t = Track()
        XCTAssertEqual(t.from, 0)
        XCTAssertEqual(t.to, 1)
        XCTAssertEqual(t.delay, 0)
        XCTAssertNil(t.curve)
    }

    // MARK: - Motion

    func testMotionInitialValues() {
        let m = Motion(tracks: [Track(from: 5, to: 10), Track(from: 0, to: 100)])
        XCTAssertEqual(m.values, [5, 0])
    }

    func testMotionForwardSetsTarget() {
        let m = Motion(duration: 0.01, curve: .linear, tracks: [Track(from: 0, to: 1)])
        m.forward()
        XCTAssertTrue(m.isRunning)
    }

    func testMotionReverseSetsTarget() {
        let m = Motion(duration: 0.01, curve: .linear, tracks: [Track(from: 0, to: 1)])
        m.target([1]) // jump to end
        m.reverse()
        XCTAssertTrue(m.isRunning)
    }

    func testMotionTickAdvances() {
        let m = Motion(duration: 10, curve: .linear, tracks: [Track(from: 0, to: 100)])
        m.forward()
        // Let some real time pass... tricky in tests.
        // At least verify it doesn't crash and values are still valid.
        m.tick()
        XCTAssertGreaterThanOrEqual(m.values[0], 0)
        XCTAssertLessThanOrEqual(m.values[0], 100)
    }

    func testMotionMultipleTracks() {
        let m = Motion(duration: 10, curve: .linear, tracks: [
            Track(from: 0, to: 1),
            Track(from: 100, to: 0),
            Track(from: 0.5, to: 0.5), // no change
        ])
        m.target([1, 0, 0.5])
        XCTAssertTrue(m.isRunning)
        XCTAssertEqual(m.values.count, 3)
    }

    func testMotionTargetMismatchIgnored() {
        let m = Motion(tracks: [Track(from: 0, to: 1)])
        m.target([1, 2, 3]) // wrong count
        XCTAssertFalse(m.isRunning) // should not start
    }

    // MARK: - Path.lerp

    func testPathLerpAtZero() {
        var a = Path(); a.addRect(Rect(x: 0, y: 0, width: 10, height: 10))
        var b = Path(); b.addRect(Rect(x: 10, y: 10, width: 20, height: 20))
        let result = Path.lerp(from: a, to: b, t: 0, samples: 16)
        let aPoints = a.sample(count: 16)
        let rPoints = result.sample(count: 16)
        guard aPoints.count == rPoints.count else { XCTFail(); return }
        for i in 0..<aPoints.count {
            XCTAssertEqual(aPoints[i].point.x, rPoints[i].point.x, accuracy: 1)
            XCTAssertEqual(aPoints[i].point.y, rPoints[i].point.y, accuracy: 1)
        }
    }

    func testPathLerpMidpoint() {
        var a = Path(); a.addRect(Rect(x: 0, y: 0, width: 10, height: 10))
        var b = Path(); b.addRect(Rect(x: 10, y: 0, width: 10, height: 10))
        let result = Path.lerp(from: a, to: b, t: 0.5, samples: 16)
        let bb = result.boundingBox
        XCTAssertGreaterThan(bb.x, 0)
        XCTAssertLessThan(bb.x, 10)
    }

    // MARK: - ToggleModel

    func testModelDefaultOff() {
        let model = makeModel(isOn: false)
        XCTAssertFalse(model.isOn)
        XCTAssertEqual(model.animationProgress, 0, accuracy: 0.01)
    }

    func testModelDefaultOn() {
        let model = makeModel(isOn: true)
        XCTAssertTrue(model.isOn)
        XCTAssertEqual(model.animationProgress, 1, accuracy: 0.01)
    }

    func testModelPress() {
        let model = makeModel()
        model.handlePress()
        XCTAssertTrue(model.isPressed)
    }

    func testModelReleaseInside() {
        let model = makeModel(isOn: false)
        model.handlePress()
        model.handleRelease(inside: true)
        XCTAssertTrue(model.isOn)
        XCTAssertFalse(model.isPressed)
    }

    func testModelReleaseOutside() {
        let model = makeModel(isOn: false)
        model.handlePress()
        model.handleRelease(inside: false)
        XCTAssertFalse(model.isOn)
    }

    func testModelWithoutPressNoToggle() {
        let model = makeModel(isOn: false)
        model.handleRelease(inside: true)
        XCTAssertFalse(model.isOn)
    }

    func testModelCurrentStateOff() {
        let model = makeModel(isOn: false)
        XCTAssertTrue(model.currentState.contains(.idle))
        XCTAssertFalse(model.currentState.contains(.selected))
    }

    func testModelCurrentStateOn() {
        let model = makeModel(isOn: true)
        XCTAssertTrue(model.currentState.contains(.selected))
    }

    func testModelCurrentStatePressed() {
        let model = makeModel()
        model.handlePress()
        XCTAssertTrue(model.currentState.contains(.pressed))
    }

    // MARK: - Presets

    func testCheckboxPreset() {
        let t = Toggle.checkbox(value: Binding(false))
        let style = t.style(.idle)
        XCTAssertEqual(style.size.width, 24)
        XCTAssertEqual(style.size.height, 24)
    }

    func testRadioPreset() {
        let t = Toggle.radio(value: Binding(false))
        let style = t.style(.idle)
        XCTAssertEqual(style.size.width, 24)
    }

    func testSwitchPreset() {
        let t = Toggle.switch(value: Binding(false))
        let style = t.style(.idle)
        XCTAssertGreaterThan(style.size.width, style.size.height)
    }

    func testHeartPreset() {
        let t = Toggle.heart(value: Binding(false))
        let style = t.style(.idle)
        XCTAssertEqual(style.size.width, 28)
    }

    // MARK: - Haptic per state

    func testHapticOnPress() {
        let t = Toggle.checkbox(value: Binding(false))
        let pressedStyle = t.style(.pressed)
        let idleStyle = t.style(.idle)
        XCTAssertNotEqual(pressedStyle.haptic, .none)
        XCTAssertEqual(idleStyle.haptic, .none)
    }

    // MARK: - States passthrough

    func testDisabledBlocksPress() {
        let binding = Binding(false)
        let toggle = Toggle(value: binding, states: .disabled)
        let model = ToggleModel()
        model.handleDidInit(toggle)
        model.handlePress()
        XCTAssertFalse(model.isPressed)
    }

    func testLoadingBlocksPress() {
        let binding = Binding(false)
        let toggle = Toggle(value: binding, states: .loading)
        let model = ToggleModel()
        model.handleDidInit(toggle)
        model.handlePress()
        XCTAssertFalse(model.isPressed)
    }

    // MARK: - Painters output

    private func painterProducesOutput(_ painter: any TogglePainter, state: State, progress: Double) -> Bool {
        let size = 48
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        let image = renderer.image { ctx in
            let canvas = CGCanvas(ctx.cgContext)
            let bounds = Rect(x: 0, y: 0, width: Double(size), height: Double(size))
            painter.paint(on: canvas, bounds: bounds, state: state, progress: progress)
        }
        guard let cgImage = image.cgImage else { return false }
        var data = [UInt8](repeating: 0, count: cgImage.width * cgImage.height * 4)
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: &data, width: cgImage.width, height: cgImage.height,
                                   bitsPerComponent: 8, bytesPerRow: cgImage.width * 4, space: cs,
                                   bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
        return data.enumerated().contains { $0.offset % 4 == 3 && $0.element > 0 }
    }

    func testCheckboxPainterOff() {
        XCTAssertTrue(painterProducesOutput(CheckboxPainter(), state: .idle, progress: 0))
    }

    func testCheckboxPainterOn() {
        XCTAssertTrue(painterProducesOutput(CheckboxPainter(), state: .selected, progress: 1))
    }

    func testRadioPainterOn() {
        XCTAssertTrue(painterProducesOutput(RadioPainter(), state: .selected, progress: 1))
    }

    func testSwitchPainterOff() {
        XCTAssertTrue(painterProducesOutput(SwitchPainter(), state: .idle, progress: 0))
    }

    func testHeartPainterOn() {
        XCTAssertTrue(painterProducesOutput(HeartPainter(), state: .selected, progress: 1))
    }

    // MARK: - Binding.onChange

    func testBindingOnChange() {
        var changed: Bool?
        let binding = Binding(false).onChange { changed = $0 }
        binding.value = true
        XCTAssertEqual(changed, true)
    }

    // MARK: - ToggleView

    func testToggleViewSize() {
        let view = ToggleView()
        view.toggleSize = Size(32, 32)
        XCTAssertEqual(view.intrinsicContentSize.width, 32)
        XCTAssertEqual(view.intrinsicContentSize.height, 32)
    }

    func testToggleViewAccessibility() {
        let model = makeModel(isOn: true)
        let view = ToggleView()
        view.model = model
        XCTAssertTrue(view.isAccessibilityElement)
        XCTAssertTrue(view.accessibilityTraits.contains(.button))
        XCTAssertEqual(view.accessibilityValue, "on")
    }

    func testToggleViewAccessibilityActivate() {
        let model = makeModel(isOn: false)
        let view = ToggleView()
        view.model = model
        _ = view.accessibilityActivate()
        XCTAssertTrue(model.isOn)
    }
}

#endif
