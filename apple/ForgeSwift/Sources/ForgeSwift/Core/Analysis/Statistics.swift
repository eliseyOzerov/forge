import Foundation

/// Statistical operations on numeric sequences.
public enum Statistics {

    // MARK: - Scalar sequences

    public static func mean(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    public static func variance(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let avg = mean(values)
        return values.reduce(0) { $0 + ($1 - avg) * ($1 - avg) } / Double(values.count)
    }

    public static func standardDeviation(_ values: [Double]) -> Double {
        sqrt(variance(values))
    }

    public static func median(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let mid = sorted.count / 2
        return sorted.count.isMultiple(of: 2)
            ? (sorted[mid - 1] + sorted[mid]) / 2
            : sorted[mid]
    }

    public static func range(_ values: [Double]) -> Double {
        guard let lo = values.min(), let hi = values.max() else { return 0 }
        return hi - lo
    }

    // MARK: - Normalization

    /// Min-max normalization to [0, 1].
    public static func normalizeMinMax(_ values: [Double]) -> [Double] {
        guard let lo = values.min(), let hi = values.max(), hi > lo else {
            return [Double](repeating: 0, count: values.count)
        }
        let range = hi - lo
        return values.map { ($0 - lo) / range }
    }

    /// Z-score normalization (subtract mean, divide by std dev).
    public static func normalizeZScore(_ values: [Double]) -> [Double] {
        let avg = mean(values)
        let std = standardDeviation(values)
        guard std > 0 else { return [Double](repeating: 0, count: values.count) }
        return values.map { ($0 - avg) / std }
    }

    // MARK: - Vector statistics

    /// Component-wise mean of a collection of vectors.
    public static func mean<V: Vector>(_ vectors: [V]) -> V {
        guard !vectors.isEmpty else { return V(components: []) }
        let dim = vectors[0].count
        var sums = [Double](repeating: 0, count: dim)
        for v in vectors {
            for (i, c) in v.components.enumerated() { sums[i] += c }
        }
        let n = Double(vectors.count)
        return V(components: sums.map { $0 / n })
    }

    /// Component-wise standard deviation of a collection of vectors.
    public static func standardDeviation<V: Vector>(_ vectors: [V]) -> V {
        guard vectors.count > 1 else { return V(components: [Double](repeating: 0, count: vectors.first?.count ?? 0)) }
        let avg = mean(vectors)
        let dim = avg.count
        var variances = [Double](repeating: 0, count: dim)
        for v in vectors {
            for (i, c) in v.components.enumerated() {
                let diff = c - avg.components[i]
                variances[i] += diff * diff
            }
        }
        let n = Double(vectors.count)
        return V(components: variances.map { sqrt($0 / n) })
    }
}
