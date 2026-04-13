import XCTest
@testable import ForgeSwift

final class MapperTests: XCTestCase {

    func testMapperCallAsFunction() {
        let double = Mapper<Int, Int> { $0 * 2 }
        XCTAssertEqual(double(5), 10)
    }

    func testStatePropertyConstant() {
        let prop = StateProperty<String>.constant("hello")
        XCTAssertEqual(prop(.idle), "hello")
        XCTAssertEqual(prop(.pressed), "hello")
    }

    func testStatePropertyReactive() {
        let prop = StateProperty<String> { state in
            state.contains(.pressed) ? "pressed" : "idle"
        }
        XCTAssertEqual(prop(.idle), "idle")
        XCTAssertEqual(prop(.pressed), "pressed")
    }

    func testUIStateOptionSet() {
        var state: UIState = .idle
        state.insert(.pressed)
        state.insert(.focused)
        XCTAssertTrue(state.contains(.idle))
        XCTAssertTrue(state.contains(.pressed))
        XCTAssertTrue(state.contains(.focused))
        XCTAssertFalse(state.contains(.disabled))
    }

    // MARK: - UIState Raw Values

    func testUIStateRawValues() {
        XCTAssertEqual(UIState.idle.rawValue, 1 << 0)
        XCTAssertEqual(UIState.pressed.rawValue, 1 << 1)
        XCTAssertEqual(UIState.disabled.rawValue, 1 << 2)
        XCTAssertEqual(UIState.focused.rawValue, 1 << 3)
        XCTAssertEqual(UIState.hovered.rawValue, 1 << 4)
        XCTAssertEqual(UIState.selected.rawValue, 1 << 5)
    }

    func testUIStateCombining() {
        let state: UIState = [.pressed, .focused]
        XCTAssertTrue(state.contains(.pressed))
        XCTAssertTrue(state.contains(.focused))
        XCTAssertFalse(state.contains(.idle))
        XCTAssertFalse(state.contains(.disabled))
    }

    func testUIStateEmpty() {
        let state = UIState()
        XCTAssertFalse(state.contains(.idle))
        XCTAssertFalse(state.contains(.pressed))
        XCTAssertEqual(state.rawValue, 0)
    }

    func testUIStateEquality() {
        let a: UIState = [.idle, .pressed]
        let b: UIState = [.pressed, .idle]
        XCTAssertEqual(a, b)
    }

    func testUIStateHashing() {
        let a: UIState = [.idle, .pressed]
        let b: UIState = [.idle, .pressed]
        XCTAssertEqual(a.hashValue, b.hashValue)
    }

    // MARK: - StateProperty per-state values

    func testStatePropertyPerStateValues() {
        let prop = StateProperty<Double> { state in
            if state.contains(.disabled) { return 0.5 }
            if state.contains(.pressed) { return 0.8 }
            return 1.0
        }
        XCTAssertEqual(prop(.idle), 1.0)
        XCTAssertEqual(prop(.pressed), 0.8)
        XCTAssertEqual(prop(.disabled), 0.5)
        XCTAssertEqual(prop([.pressed, .disabled]), 0.5)
    }

    // MARK: - Mapper types

    func testMapperStringToInt() {
        let length = Mapper<String, Int> { $0.count }
        XCTAssertEqual(length("hello"), 5)
        XCTAssertEqual(length(""), 0)
    }
}
