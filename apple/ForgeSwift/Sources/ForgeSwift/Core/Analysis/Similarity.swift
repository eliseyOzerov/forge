import CoreGraphics

/// Similarity and distance metrics for vectors.
public enum Similarity {

    /// Cosine similarity: dot(a,b) / (|a| * |b|). Range: [-1, 1].
    /// 1 = identical direction, 0 = orthogonal, -1 = opposite.
    public static func cosine<V: Vector>(_ a: V, _ b: V) -> CGFloat {
        let denom = a.length * b.length
        guard denom > 0 else { return 0 }
        return a.dot(b) / denom
    }

    /// Cosine distance: 1 - cosine similarity. Range: [0, 2].
    public static func cosineDistance<V: Vector>(_ a: V, _ b: V) -> CGFloat {
        1 - cosine(a, b)
    }

    /// Euclidean distance (L2 norm of difference).
    public static func euclidean<V: Vector>(_ a: V, _ b: V) -> CGFloat {
        a.distance(to: b)
    }

    /// Squared euclidean distance (avoids sqrt, useful for comparisons).
    public static func euclideanSquared<V: Vector>(_ a: V, _ b: V) -> CGFloat {
        a.distanceSquared(to: b)
    }

    /// Manhattan distance (L1 norm / city-block distance).
    public static func manhattan<V: Vector>(_ a: V, _ b: V) -> CGFloat {
        a.manhattanDistance(to: b)
    }

    /// Chebyshev distance (L∞ norm / chessboard distance).
    public static func chebyshev<V: Vector>(_ a: V, _ b: V) -> CGFloat {
        zip(a.components, b.components).reduce(0) { max($0, abs($1.0 - $1.1)) }
    }

    /// Minkowski distance (generalized Lp norm).
    public static func minkowski<V: Vector>(_ a: V, _ b: V, p: CGFloat) -> CGFloat {
        let sum = zip(a.components, b.components).reduce(CGFloat(0)) { $0 + pow(abs($1.0 - $1.1), p) }
        return pow(sum, 1 / p)
    }

    /// Angular distance: arccos(cosine similarity) / π. Range: [0, 1].
    public static func angular<V: Vector>(_ a: V, _ b: V) -> CGFloat {
        acos(min(1, max(-1, cosine(a, b)))) / .pi
    }
}
