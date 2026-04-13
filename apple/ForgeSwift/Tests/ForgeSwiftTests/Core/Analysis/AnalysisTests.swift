import XCTest
@testable import ForgeSwift

final class AnalysisTests: XCTestCase {

    // MARK: - Similarity

    func testCosineSimilarityIdentical() {
        let a = Vec2(1, 0)
        XCTAssertEqual(Similarity.cosine(a, a), 1, accuracy: 1e-10)
    }

    func testCosineSimilarityOrthogonal() {
        let a = Vec2(1, 0)
        let b = Vec2(0, 1)
        XCTAssertEqual(Similarity.cosine(a, b), 0, accuracy: 1e-10)
    }

    func testCosineSimilarityOpposite() {
        let a = Vec2(1, 0)
        let b = Vec2(-1, 0)
        XCTAssertEqual(Similarity.cosine(a, b), -1, accuracy: 1e-10)
    }

    func testCosineDistance() {
        let a = Vec2(1, 0)
        let b = Vec2(0, 1)
        XCTAssertEqual(Similarity.cosineDistance(a, b), 1, accuracy: 1e-10)
    }

    func testEuclideanDistance() {
        let a = Vec2(0, 0)
        let b = Vec2(3, 4)
        XCTAssertEqual(Similarity.euclidean(a, b), 5, accuracy: 1e-10)
    }

    func testManhattanDistance() {
        let a = Vec2(1, 1)
        let b = Vec2(4, 5)
        XCTAssertEqual(Similarity.manhattan(a, b), 7, accuracy: 1e-10)
    }

    func testChebyshevDistance() {
        let a = Vec2(1, 1)
        let b = Vec2(4, 8)
        XCTAssertEqual(Similarity.chebyshev(a, b), 7, accuracy: 1e-10)
    }

    func testMinkowskiP2IsEuclidean() {
        let a = Vec2(0, 0)
        let b = Vec2(3, 4)
        XCTAssertEqual(Similarity.minkowski(a, b, p: 2), 5, accuracy: 1e-10)
    }

    func testMinkowskiP1IsManhattan() {
        let a = Vec2(1, 1)
        let b = Vec2(4, 5)
        XCTAssertEqual(Similarity.minkowski(a, b, p: 1), 7, accuracy: 1e-10)
    }

    // MARK: - Statistics (Scalar)

    func testMean() {
        XCTAssertEqual(Statistics.mean([2, 4, 6]), 4, accuracy: 1e-10)
    }

    func testMeanEmpty() {
        XCTAssertEqual(Statistics.mean([]), 0)
    }

    func testVariance() {
        let v = Statistics.variance([2, 4, 4, 4, 5, 5, 7, 9])
        XCTAssertEqual(v, 4, accuracy: 1e-10)
    }

    func testStandardDeviation() {
        let sd = Statistics.standardDeviation([2, 4, 4, 4, 5, 5, 7, 9])
        XCTAssertEqual(sd, 2, accuracy: 1e-10)
    }

    func testMedianOdd() {
        XCTAssertEqual(Statistics.median([1, 3, 5]), 3)
    }

    func testMedianEven() {
        XCTAssertEqual(Statistics.median([1, 2, 3, 4]), 2.5)
    }

    func testRange() {
        XCTAssertEqual(Statistics.range([3, 1, 7, 2]), 6)
    }

    func testNormalizeMinMax() {
        let result = Statistics.normalizeMinMax([0, 5, 10])
        XCTAssertEqual(result, [0, 0.5, 1])
    }

    func testNormalizeZScore() {
        let result = Statistics.normalizeZScore([2, 4, 4, 4, 5, 5, 7, 9])
        XCTAssertEqual(result[0], -1.5, accuracy: 1e-10)
    }

    // MARK: - Statistics (Vector)

    func testVectorMean() {
        let vecs = [Vec2(0, 0), Vec2(10, 20)]
        let mean = Statistics.mean(vecs)
        XCTAssertEqual(mean.x, 5, accuracy: 1e-10)
        XCTAssertEqual(mean.y, 10, accuracy: 1e-10)
    }

    func testVectorStandardDeviation() {
        let vecs = [Vec2(0, 0), Vec2(10, 0), Vec2(20, 0)]
        let sd = Statistics.standardDeviation(vecs)
        // mean x = 10, variance = (100+0+100)/3 ≈ 66.67, sd ≈ 8.165
        XCTAssertGreaterThan(sd.x, 0)
        XCTAssertEqual(sd.y, 0, accuracy: 1e-10)
    }

    // MARK: - Similarity: euclideanSquared & angular

    func testEuclideanSquared() {
        let a = Vec2(0, 0)
        let b = Vec2(3, 4)
        let sq = Similarity.euclideanSquared(a, b)
        let eu = Similarity.euclidean(a, b)
        XCTAssertEqual(sq, eu * eu, accuracy: 1e-10)
        XCTAssertEqual(sq, 25, accuracy: 1e-10)
    }

    func testAngularIdentical() {
        let a = Vec2(1, 0)
        XCTAssertEqual(Similarity.angular(a, a), 0, accuracy: 1e-10)
    }

    func testAngularOrthogonal() {
        let a = Vec2(1, 0)
        let b = Vec2(0, 1)
        XCTAssertEqual(Similarity.angular(a, b), 0.5, accuracy: 1e-10)
    }

    func testAngularOpposite() {
        let a = Vec2(1, 0)
        let b = Vec2(-1, 0)
        XCTAssertEqual(Similarity.angular(a, b), 1.0, accuracy: 1e-10)
    }

    // MARK: - Statistics Edge Cases

    func testVarianceEmpty() {
        XCTAssertEqual(Statistics.variance([]), 0)
    }

    func testVarianceSingleElement() {
        XCTAssertEqual(Statistics.variance([5.0]), 0)
    }

    func testMedianEmpty() {
        XCTAssertEqual(Statistics.median([]), 0)
    }

    func testNormalizeMinMaxAllSame() {
        let result = Statistics.normalizeMinMax([3, 3, 3])
        XCTAssertEqual(result, [0, 0, 0])
    }

    func testNormalizeZScoreZeroStdDev() {
        let result = Statistics.normalizeZScore([5, 5, 5])
        XCTAssertEqual(result, [0, 0, 0])
    }
}
