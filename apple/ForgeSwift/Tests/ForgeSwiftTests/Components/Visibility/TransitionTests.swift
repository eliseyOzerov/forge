#if canImport(UIKit)
import XCTest
@testable import ForgeSwift

@MainActor
final class TransitionEffectTests: XCTestCase {

    // MARK: - Fade

    func testFadeFromZeroToOne() {
        let effect = Fade()
        var state = TransitionState()
        effect.contribute(to: &state, t: 0)
        XCTAssertEqual(state.alpha, 0, accuracy: 0.001)

        state = TransitionState()
        effect.contribute(to: &state, t: 1)
        XCTAssertEqual(state.alpha, 1, accuracy: 0.001)

        state = TransitionState()
        effect.contribute(to: &state, t: 0.5)
        XCTAssertEqual(state.alpha, 0.5, accuracy: 0.001)
    }

    func testFadeCustomRange() {
        let effect = Fade(from: 0.25, to: 0.75)
        var state = TransitionState()
        effect.contribute(to: &state, t: 0)
        XCTAssertEqual(state.alpha, 0.25, accuracy: 0.001)
        state = TransitionState()
        effect.contribute(to: &state, t: 1)
        XCTAssertEqual(state.alpha, 0.75, accuracy: 0.001)
    }

    // MARK: - Scale

    func testScaleUniform() {
        let effect = Scale(0.9)
        var state = TransitionState()
        effect.contribute(to: &state, t: 0)
        XCTAssertEqual(state.scaleX, 0.9, accuracy: 0.001)
        XCTAssertEqual(state.scaleY, 0.9, accuracy: 0.001)
        state = TransitionState()
        effect.contribute(to: &state, t: 1)
        XCTAssertEqual(state.scaleX, 1.0, accuracy: 0.001)
    }

    func testScaleXY() {
        let effect = Scale.xy(fromX: 0.5, fromY: 2.0)
        var state = TransitionState()
        effect.contribute(to: &state, t: 0)
        XCTAssertEqual(state.scaleX, 0.5, accuracy: 0.001)
        XCTAssertEqual(state.scaleY, 2.0, accuracy: 0.001)
    }

    // MARK: - Slide

    func testSlideY() {
        let effect = Slide(y: 20)
        var state = TransitionState()
        effect.contribute(to: &state, t: 0)
        XCTAssertEqual(state.translationY, 20, accuracy: 0.001)
        state = TransitionState()
        effect.contribute(to: &state, t: 1)
        XCTAssertEqual(state.translationY, 0, accuracy: 0.001)
    }

    // MARK: - Rotate

    func testRotate() {
        let effect = Rotate(.pi)
        var state = TransitionState()
        effect.contribute(to: &state, t: 0)
        XCTAssertEqual(state.rotation, .pi, accuracy: 0.001)
        state = TransitionState()
        effect.contribute(to: &state, t: 1)
        XCTAssertEqual(state.rotation, 0, accuracy: 0.001)
    }

    // MARK: - Composition

    func testEffectsComposeIndependentChannels() {
        let effects: [any TransitionEffect] = [Fade(), Scale(0.9), Slide(y: 20)]
        var state = TransitionState()
        for effect in effects {
            effect.contribute(to: &state, t: 0)
        }
        XCTAssertEqual(state.alpha, 0, accuracy: 0.001)
        XCTAssertEqual(state.scaleX, 0.9, accuracy: 0.001)
        XCTAssertEqual(state.translationY, 20, accuracy: 0.001)

        state = TransitionState()
        for effect in effects {
            effect.contribute(to: &state, t: 1)
        }
        XCTAssertEqual(state.alpha, 1, accuracy: 0.001)
        XCTAssertEqual(state.scaleX, 1, accuracy: 0.001)
        XCTAssertEqual(state.translationY, 0, accuracy: 0.001)
    }

    func testMultipleScalesMultiply() {
        // Two Scale effects compound via multiplication, matching how
        // parent×child scales combine in a transform hierarchy.
        let effects: [any TransitionEffect] = [Scale(0.5, to: 0.5), Scale(2.0, to: 2.0)]
        var state = TransitionState()
        for effect in effects {
            effect.contribute(to: &state, t: 0.5)
        }
        XCTAssertEqual(state.scaleX, 1.0, accuracy: 0.001)  // 0.5 * 2.0
    }
}
#endif
