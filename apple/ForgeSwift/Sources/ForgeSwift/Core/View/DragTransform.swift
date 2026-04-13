import Foundation

// MARK: - DragTransform

/// Transforms a 2D offset during or after a drag gesture.
/// Used as the `active` (during drag) and `target` (snap on release)
/// parameters of Draggable.
public typealias DragTransform = Mapper<Vec2, Vec2>

// MARK: - Axis

public extension DragTransform {
    /// Lock to horizontal axis (zero out y).
    nonisolated(unsafe) static let horizontal = DragTransform { Vec2($0.x, 0) }

    /// Lock to vertical axis (zero out x).
    nonisolated(unsafe) static let vertical = DragTransform { Vec2(0, $0.y) }
}

// MARK: - Clamp

public extension DragTransform {
    /// Clamp position into a rectangle.
    static func clamp(to rect: Rect) -> DragTransform {
        DragTransform { pos in
            Vec2(
                min(max(pos.x, rect.x), rect.x + rect.width),
                min(max(pos.y, rect.y), rect.y + rect.height)
            )
        }
    }

    /// Clamp position into a circular region.
    static func disc(center: Vec2, radius: Double) -> DragTransform {
        DragTransform { pos in
            let d = pos - center
            if d.lengthSquared <= radius * radius { return pos }
            return center + d.normalized * radius
        }
    }
}

// MARK: - Projection

public extension DragTransform {
    /// Project position onto a line segment from `start` to `end`.
    static func line(from start: Vec2, to end: Vec2) -> DragTransform {
        DragTransform { pos in
            let d = end - start
            let lenSq = d.lengthSquared
            guard lenSq > 0 else { return start }
            let t = min(max((pos - start).dot(d) / lenSq, 0), 1)
            return start + d * t
        }
    }
}

// MARK: - Snap

public extension DragTransform {
    /// Snap to the nearest point in a list. O(n) per call.
    static func snap(to points: [Vec2]) -> DragTransform {
        DragTransform { pos in
            guard !points.isEmpty else { return pos }
            var best = points[0]
            var bestDist = pos.distanceSquared(to: best)
            for p in points.dropFirst() {
                let d = pos.distanceSquared(to: p)
                if d < bestDist { best = p; bestDist = d }
            }
            return best
        }
    }

    /// Snap to the nearest sampled point along a path.
    static func path(_ path: Path, samples: Int = 100) -> DragTransform {
        let points = path.sample(count: samples).map(\.point)
        return snap(to: points)
    }

    /// Snap to a grid with the given cell size.
    static func grid(cellSize: Vec2) -> DragTransform {
        DragTransform { pos in
            Vec2(
                (pos.x / cellSize.x).rounded() * cellSize.x,
                (pos.y / cellSize.y).rounded() * cellSize.y
            )
        }
    }
}

// MARK: - Magnet

public extension DragTransform {
    /// Pull position toward a target transform with configurable strength.
    /// `strength` 0...1 controls how hard the pull is (1 = snap immediately).
    /// `radius` limits the pull range — beyond it, position is unchanged.
    static func magnet(_ target: DragTransform, strength: Double = 0.5, radius: Double? = nil) -> DragTransform {
        DragTransform { pos in
            let snapped = target(pos)
            let dist = pos.distance(to: snapped)
            if let r = radius, dist > r { return pos }
            return pos.lerp(to: snapped, t: strength)
        }
    }
}

// MARK: - Composition

public extension DragTransform {
    /// Chain multiple transforms in sequence.
    static func sequence(_ transforms: [DragTransform]) -> DragTransform {
        DragTransform { pos in
            transforms.reduce(pos) { $1($0) }
        }
    }

    /// Chain transforms using builder syntax.
    static func sequence(@ListBuilder<DragTransform> _ build: () -> [DragTransform]) -> DragTransform {
        sequence(build())
    }

}
