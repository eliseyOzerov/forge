#if canImport(UIKit)
import XCTest
@testable import ForgeSwift

@MainActor
final class SegmentedTests: XCTestCase {

    enum Option: Hashable { case apple, banana, cherry }

    private func makeModel(initial: Option = .apple) -> SegmentedModel<Option> {
        let binding = Binding(initial)
        let view = Segmented<Option>(value: binding, items: [.apple, .banana, .cherry])
        let context = BuildContext(node: BuiltNode())
        let model = SegmentedModel<Option>(context: context)
        model.didInit(view: view)
        return model
    }

    // MARK: - Selection

    func testInitialSelectedIndex() {
        let model = makeModel(initial: .banana)
        XCTAssertEqual(model.selectedIndex, 1)
    }

    func testTapSegmentUpdatesValue() {
        let model = makeModel(initial: .apple)
        model.tapSegment(at: 2)
        XCTAssertEqual(model.view.value.value, .cherry)
    }

    func testTapIgnoredWhenDisabled() {
        let binding = Binding(Option.apple)
        let view = Segmented<Option>(
            value: binding,
            items: [.apple, .banana, .cherry],
            states: .disabled
        )
        let context = BuildContext(node: BuiltNode())
        let model = SegmentedModel<Option>(context: context)
        model.didInit(view: view)
        model.tapSegment(at: 2)
        XCTAssertEqual(model.view.value.value, .apple)
    }

    func testTapOutOfRangeIgnored() {
        let model = makeModel()
        model.tapSegment(at: 99)
        XCTAssertEqual(model.view.value.value, .apple)
    }

    // MARK: - Scrub

    func testScrubUpdatesValueAtMidpointCrossing() {
        let model = makeModel(initial: .apple)
        model.scrubStart()
        model.scrubTo(normalized: 0.6)   // idx ≈ 1.2 → rounds to 1
        XCTAssertEqual(model.view.value.value, .banana)
    }

    func testScrubEndSnapsToSelected() {
        let model = makeModel(initial: .apple)
        model.scrubStart()
        model.scrubTo(normalized: 1.0)
        XCTAssertTrue(model.isPressed)
        model.scrubEnd()
        XCTAssertFalse(model.isPressed)
        XCTAssertEqual(model.view.value.value, .cherry)
    }

    // MARK: - Item state

    func testItemStateIncludesSelectedForCurrentIndex() {
        let model = makeModel(initial: .banana)
        XCTAssertTrue(model.itemState(at: 1).contains(.selected))
        XCTAssertFalse(model.itemState(at: 0).contains(.selected))
        XCTAssertFalse(model.itemState(at: 2).contains(.selected))
    }

    // MARK: - Theme

    func testSegmentedThemeCascadesPrimary() {
        let primary = SegmentedStyle<Option>(animation: Animation(duration: 0.5))
        let theme = SegmentedTheme<Option>(primary: primary)
        XCTAssertEqual(theme.primary.animation.duration, 0.5)
        XCTAssertEqual(theme.secondary.animation.duration, 0.5) // falls back
        XCTAssertEqual(theme.tertiary.animation.duration, 0.5)
    }

    func testSegmentedThemeOverridesLevel() {
        let theme = SegmentedTheme<Option>(
            primary: SegmentedStyle<Option>(animation: Animation(duration: 0.25)),
            secondary: SegmentedStyle<Option>(animation: Animation(duration: 0.5))
        )
        XCTAssertEqual(theme.primary.animation.duration, 0.25)
        XCTAssertEqual(theme.secondary.animation.duration, 0.5)
        XCTAssertEqual(theme.tertiary.animation.duration, 0.5) // secondary cascade
    }
}
#endif
