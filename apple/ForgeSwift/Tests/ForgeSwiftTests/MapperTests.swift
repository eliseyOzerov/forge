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
}
