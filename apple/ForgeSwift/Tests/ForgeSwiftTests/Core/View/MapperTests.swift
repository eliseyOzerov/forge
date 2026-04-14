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

    func testStateOptionSet() {
        var state: State = .idle
        state.insert(.pressed)
        state.insert(.focused)
        XCTAssertTrue(state.contains(.idle))
        XCTAssertTrue(state.contains(.pressed))
        XCTAssertTrue(state.contains(.focused))
        XCTAssertFalse(state.contains(.disabled))
    }

    // MARK: - State Raw Values

    func testStateRawValues() {
        XCTAssertEqual(State.idle.rawValue, 1 << 0)
        XCTAssertEqual(State.pressed.rawValue, 1 << 1)
        XCTAssertEqual(State.disabled.rawValue, 1 << 2)
        XCTAssertEqual(State.focused.rawValue, 1 << 3)
        XCTAssertEqual(State.hovered.rawValue, 1 << 4)
        XCTAssertEqual(State.selected.rawValue, 1 << 5)
    }

    func testStateCombining() {
        let state: State = [.pressed, .focused]
        XCTAssertTrue(state.contains(.pressed))
        XCTAssertTrue(state.contains(.focused))
        XCTAssertFalse(state.contains(.idle))
        XCTAssertFalse(state.contains(.disabled))
    }

    func testStateEmpty() {
        let state = State()
        XCTAssertFalse(state.contains(.idle))
        XCTAssertFalse(state.contains(.pressed))
        XCTAssertEqual(state.rawValue, 0)
    }

    func testStateEquality() {
        let a: State = [.idle, .pressed]
        let b: State = [.pressed, .idle]
        XCTAssertEqual(a, b)
    }

    func testStateHashing() {
        let a: State = [.idle, .pressed]
        let b: State = [.idle, .pressed]
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
