#if canImport(UIKit)
import XCTest
@testable import ForgeSwift

@MainActor
final class DeepLinkTests: XCTestCase {

    // MARK: - match

    func testMatchExactPath() {
        let url = URL(string: "https://example.com/home")!
        let result = DeepLinkMap.match(pattern: "/home", url: url)
        XCTAssertNotNil(result)
        XCTAssertTrue(result!.values.isEmpty)
    }

    func testMatchSingleCapture() {
        let url = URL(string: "https://example.com/profile/42")!
        let result = DeepLinkMap.match(pattern: "/profile/:id", url: url)
        XCTAssertNotNil(result)
        XCTAssertEqual(result!["id"], "42")
    }

    func testMatchMultipleCaptures() {
        let url = URL(string: "https://example.com/user/alice/post/99")!
        let result = DeepLinkMap.match(pattern: "/user/:name/post/:postId", url: url)
        XCTAssertNotNil(result)
        XCTAssertEqual(result!["name"], "alice")
        XCTAssertEqual(result!["postId"], "99")
    }

    func testMatchFailsOnDifferentStaticSegment() {
        let url = URL(string: "https://example.com/settings")!
        let result = DeepLinkMap.match(pattern: "/profile", url: url)
        XCTAssertNil(result)
    }

    func testMatchFailsOnDifferentSegmentCount() {
        let url = URL(string: "https://example.com/a/b/c")!
        let result = DeepLinkMap.match(pattern: "/a/b", url: url)
        XCTAssertNil(result)
    }

    func testMatchFailsOnFewerSegments() {
        let url = URL(string: "https://example.com/a")!
        let result = DeepLinkMap.match(pattern: "/a/b", url: url)
        XCTAssertNil(result)
    }

    func testMatchEmptyPath() {
        let url = URL(string: "https://example.com/")!
        let result = DeepLinkMap.match(pattern: "/", url: url)
        // Both split to empty arrays, count matches
        XCTAssertNotNil(result)
    }

    func testMatchMixedStaticAndCapture() {
        let url = URL(string: "https://example.com/api/v2/users/john")!
        let result = DeepLinkMap.match(pattern: "/api/v2/users/:username", url: url)
        XCTAssertNotNil(result)
        XCTAssertEqual(result!["username"], "john")
    }

    // MARK: - resolve

    func testResolveFirstMatch() {
        let map = DeepLinkMap {
            DeepLink("/profile/:id") { params in
                guard params["id"] != nil else { return nil }
                return Route { EmptyView() }
            }
            DeepLink("/settings") { _ in
                Route { EmptyView() }
            }
        }

        let url = URL(string: "https://example.com/profile/7")!
        let route = map.resolve(url)
        XCTAssertNotNil(route)
    }

    func testResolveSecondMatch() {
        let map = DeepLinkMap {
            DeepLink("/profile/:id") { _ in
                Route { EmptyView() }
            }
            DeepLink("/settings") { _ in
                Route { EmptyView() }
            }
        }

        let url = URL(string: "https://example.com/settings")!
        let route = map.resolve(url)
        XCTAssertNotNil(route)
    }

    func testResolveNoMatch() {
        let map = DeepLinkMap {
            DeepLink("/profile/:id") { _ in
                Route { EmptyView() }
            }
        }

        let url = URL(string: "https://example.com/unknown")!
        let route = map.resolve(url)
        XCTAssertNil(route)
    }

    func testResolveFactoryRejectsReturnsNil() {
        let map = DeepLinkMap {
            DeepLink("/profile/:id") { params in
                // Reject non-numeric ids
                guard let _ = params["id"].flatMap(Int.init) else { return nil }
                return Route { EmptyView() }
            }
        }

        let url = URL(string: "https://example.com/profile/abc")!
        let route = map.resolve(url)
        XCTAssertNil(route)
    }

    func testResolveFactoryRejectsFallsThrough() {
        let map = DeepLinkMap {
            DeepLink("/item/:id") { params in
                // Only accept numeric
                guard let _ = params["id"].flatMap(Int.init) else { return nil }
                return Route(key: "numeric") { EmptyView() }
            }
            DeepLink("/item/:id") { _ in
                // Catch-all
                return Route(key: "catchall") { EmptyView() }
            }
        }

        let url = URL(string: "https://example.com/item/abc")!
        let route = map.resolve(url)
        XCTAssertNotNil(route)
        XCTAssertEqual(route!.key, AnyHashable("catchall"))
    }

    func testResolveEmptyMap() {
        let map = DeepLinkMap()
        let url = URL(string: "https://example.com/anything")!
        XCTAssertNil(map.resolve(url))
    }
}

#endif
