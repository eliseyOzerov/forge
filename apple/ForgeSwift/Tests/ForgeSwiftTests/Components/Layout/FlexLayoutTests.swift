#if canImport(UIKit)
import Testing
import UIKit
@testable import ForgeSwift

///public var axis: Axis = .horizontal
///public var spacing: Double = 8
///public var lineSpacing: Double = 8
///public var alignment: Alignment = .center
///public var spread: Spread? = nil
///public var wrap: Bool = false
///public var crossFill: CrossFill = .sibling

@Suite("Flex Layout")
struct FlexLayoutTests {

    @Suite("1 child")
    struct SingleChild {

        @Suite("Row") @MainActor
        struct Row {
            let flex: FlexView

            init() {
                flex = FlexView()
                flex.style = FlexStyle(axis: .horizontal)
            }

            @Test(arguments: [
                (Frame(.fit(), .fix(20)),    0.0, 20.0),
                (Frame(.fix(30), .fix(20)), 30.0, 20.0),
                (Frame(.fill(), .fix(20)), 100.0, 20.0),
                (Frame(.flex(1), .fix(20)), 100.0, 20.0),
            ])
            func mainExtent(sizing: Frame, w: Double, h: Double) {
                let box = BoxView()
                box.sizing = sizing
                flex.addSubview(box)

                let size = flex.sizeThatFits(CGSize(width: 100, height: 100))
                #expect(Double(size.width) == w)
                #expect(Double(size.height) == h)

                flex.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
                flex.layoutSubviews()
                #expect(Double(box.frame.origin.x) == 0)
                #expect(Double(box.frame.origin.y) == 0)
                #expect(Double(box.frame.size.width) == w)
                #expect(Double(box.frame.size.height) == h)
            }

            @Test(arguments: [
                (Frame(.fix(30), .fit()),    0.0),
                (Frame(.fix(30), .fix(20)), 20.0),
                (Frame(.fix(30), .fill()),   0.0),
                (Frame(.fix(30), .flex(1)),  0.0),
            ])
            func crossExtent(sizing: Frame, h: Double) {
                let box = BoxView()
                box.sizing = sizing
                flex.addSubview(box)

                let size = flex.sizeThatFits(CGSize(width: 100, height: 100))
                #expect(Double(size.width) == 30)
                #expect(Double(size.height) == h)

                flex.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
                flex.layoutSubviews()
                #expect(Double(box.frame.origin.x) == 0)
                #expect(Double(box.frame.size.width) == 30)
                #expect(Double(box.frame.size.height) == h)
            }
        }

        @Suite("Column") @MainActor
        struct Column {
            let flex: FlexView

            init() {
                flex = FlexView()
                flex.style = FlexStyle(axis: .vertical)
            }

            @Test(arguments: [
                (Frame(.fix(30), .fit()),      30.0,   0.0),
                (Frame(.fix(30), .fix(20)),    30.0,  20.0),
                (Frame(.fix(30), .fill()),     30.0, 100.0),
                (Frame(.fix(30), .flex(1)),    30.0, 100.0),
            ])
            func mainExtent(sizing: Frame, w: Double, h: Double) {
                let box = BoxView()
                box.sizing = sizing
                flex.addSubview(box)

                let size = flex.sizeThatFits(CGSize(width: 100, height: 100))
                #expect(Double(size.width) == w)
                #expect(Double(size.height) == h)

                flex.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
                flex.layoutSubviews()
                #expect(Double(box.frame.origin.x) == 0)
                #expect(Double(box.frame.origin.y) == 0)
                #expect(Double(box.frame.size.width) == w)
                #expect(Double(box.frame.size.height) == h)
            }

            @Test(arguments: [
                (Frame(.fit(), .fix(20)),    0.0),
                (Frame(.fix(30), .fix(20)), 30.0),
                (Frame(.fill(), .fix(20)),   0.0),
                (Frame(.flex(1), .fix(20)),  0.0),
            ])
            func crossExtent(sizing: Frame, w: Double) {
                let box = BoxView()
                box.sizing = sizing
                flex.addSubview(box)

                let size = flex.sizeThatFits(CGSize(width: 100, height: 100))
                #expect(Double(size.width) == w)
                #expect(Double(size.height) == 20)

                flex.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
                flex.layoutSubviews()
                #expect(Double(box.frame.origin.y) == 0)
                #expect(Double(box.frame.size.width) == w)
                #expect(Double(box.frame.size.height) == 20)
            }
        }
    }

    @Suite("2 children")
    struct TwoChildren {

        @Suite("Row") @MainActor
        struct Row {
            let flex: FlexView

            init() {
                flex = FlexView()
                flex.style = FlexStyle(axis: .horizontal, spacing: 0, alignment: .topLeft, spread: .packed)
                flex.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
            }

            @Test(arguments: [
                // fix + fix
                (Frame.fixed(30, 20), Frame.fixed(40, 25), 30.0, 20.0, 40.0, 25.0),
                // fix + flex
                (Frame.fixed(30, 20), Frame(.flex(1), .fix(25)), 30.0, 20.0, 70.0, 25.0),
                // flex + flex (1:3)
                (Frame(.flex(1), .fix(20)), Frame(.flex(3), .fix(25)), 25.0, 20.0, 75.0, 25.0),
                // fix + fill-cross
                (Frame.fixed(30, 40), Frame(.fix(40), .fill()), 30.0, 40.0, 40.0, 40.0),
            ])
            func frames(s1: Frame, s2: Frame, w1: Double, h1: Double, w2: Double, h2: Double) {
                let box1 = BoxView(); box1.sizing = s1
                let box2 = BoxView(); box2.sizing = s2
                flex.addSubview(box1)
                flex.addSubview(box2)
                flex.layoutSubviews()

                #expect(Double(box1.frame.origin.x) == 0)
                #expect(Double(box1.frame.origin.y) == 0)
                #expect(Double(box1.frame.size.width) == w1)
                #expect(Double(box1.frame.size.height) == h1)

                #expect(Double(box2.frame.origin.x) == w1)
                #expect(Double(box2.frame.origin.y) == 0)
                #expect(Double(box2.frame.size.width) == w2)
                #expect(Double(box2.frame.size.height) == h2)
            }
        }

        @Suite("Column") @MainActor
        struct Column {
            let flex: FlexView

            init() {
                flex = FlexView()
                flex.style = FlexStyle(axis: .vertical, spacing: 0, alignment: .topLeft, spread: .packed)
                flex.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
            }

            @Test(arguments: [
                // fix + fix
                (Frame.fixed(30, 20), Frame.fixed(25, 40), 30.0, 20.0, 25.0, 40.0),
                // fix + flex
                (Frame.fixed(30, 20), Frame(.fix(25), .flex(1)), 30.0, 20.0, 25.0, 80.0),
                // flex + flex (1:3)
                (Frame(.fix(30), .flex(1)), Frame(.fix(25), .flex(3)), 30.0, 25.0, 25.0, 75.0),
                // fix + fill-cross
                (Frame.fixed(30, 40), Frame(.fill(), .fix(20)), 30.0, 40.0, 30.0, 20.0),
            ])
            func frames(s1: Frame, s2: Frame, w1: Double, h1: Double, w2: Double, h2: Double) {
                let box1 = BoxView(); box1.sizing = s1
                let box2 = BoxView(); box2.sizing = s2
                flex.addSubview(box1)
                flex.addSubview(box2)
                flex.layoutSubviews()

                #expect(Double(box1.frame.origin.x) == 0)
                #expect(Double(box1.frame.origin.y) == 0)
                #expect(Double(box1.frame.size.width) == w1)
                #expect(Double(box1.frame.size.height) == h1)

                #expect(Double(box2.frame.origin.x) == 0)
                #expect(Double(box2.frame.origin.y) == h1)
                #expect(Double(box2.frame.size.width) == w2)
                #expect(Double(box2.frame.size.height) == h2)
            }
        }
    }
    // MARK: - Spacing

    @Suite("Spacing") @MainActor
    struct SpacingTests {
        let flex: FlexView

        init() {
            flex = FlexView()
            flex.style = FlexStyle(axis: .horizontal, alignment: .topLeft, spread: .packed)
            flex.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        }

        // Two 30x20 fixed children, varying spacing → x2 = 30 + spacing
        @Test(arguments: [
            (0.0,  30.0),
            (10.0, 40.0),
            (20.0, 50.0),
        ])
        func gap(spacing: Double, x2: Double) {
            flex.style.spacing = spacing
            let box1 = BoxView(); box1.sizing = .fixed(30, 20)
            let box2 = BoxView(); box2.sizing = .fixed(30, 20)
            flex.addSubview(box1)
            flex.addSubview(box2)
            flex.layoutSubviews()

            #expect(Double(box1.frame.origin.x) == 0)
            #expect(Double(box2.frame.origin.x) == x2)
        }
    }

    // MARK: - Alignment

    @Suite("Alignment") @MainActor
    struct AlignmentTests {

        // Row: 50x20 + 50x40 fills main exactly, so only cross position varies.
        // Line cross = 40. box1 (shorter) is offset by crossAlign * (40-20).
        @Test(arguments: [
            (Alignment.topLeft,    0.0),
            (Alignment.center,     10.0),
            (Alignment.bottomLeft, 20.0),
        ])
        func rowCross(alignment: Alignment, y1: Double) {
            let flex = FlexView()
            flex.style = FlexStyle(axis: .horizontal, spacing: 0, alignment: alignment, spread: .packed)
            flex.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
            let box1 = BoxView(); box1.sizing = .fixed(50, 20)
            let box2 = BoxView(); box2.sizing = .fixed(50, 40)
            flex.addSubview(box1)
            flex.addSubview(box2)
            flex.layoutSubviews()

            #expect(Double(box1.frame.origin.y) == y1)
            #expect(Double(box2.frame.origin.y) == 0)
        }

        // Column: 20x50 + 40x50 fills main exactly, so only cross position varies.
        // Line cross = 40. box1 (narrower) is offset by crossAlign * (40-20).
        @Test(arguments: [
            (Alignment.topLeft,  0.0),
            (Alignment.topCenter, 10.0),
            (Alignment.topRight, 20.0),
        ])
        func columnCross(alignment: Alignment, x1: Double) {
            let flex = FlexView()
            flex.style = FlexStyle(axis: .vertical, spacing: 0, alignment: alignment, spread: .packed)
            flex.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
            let box1 = BoxView(); box1.sizing = .fixed(20, 50)
            let box2 = BoxView(); box2.sizing = .fixed(40, 50)
            flex.addSubview(box1)
            flex.addSubview(box2)
            flex.layoutSubviews()

            #expect(Double(box1.frame.origin.x) == x1)
            #expect(Double(box2.frame.origin.x) == 0)
        }
    }

    // MARK: - Spread

    @Suite("Spread") @MainActor
    struct SpreadTests {

        // Row: two 20x20 children in 100 wide container. Remaining = 60. topLeft alignment.
        @Test(arguments: [
            (Spread.packed,  0.0, 20.0),
            (Spread.between, 0.0, 80.0),
            (Spread.around,  15.0, 65.0),
            (Spread.even,    20.0, 60.0),
        ])
        func row(spread: Spread, x1: Double, x2: Double) {
            let flex = FlexView()
            flex.style = FlexStyle(axis: .horizontal, spacing: 0, alignment: .topLeft, spread: spread)
            flex.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
            let box1 = BoxView(); box1.sizing = .fixed(20, 20)
            let box2 = BoxView(); box2.sizing = .fixed(20, 20)
            flex.addSubview(box1)
            flex.addSubview(box2)
            flex.layoutSubviews()

            #expect(Double(box1.frame.origin.x) == x1)
            #expect(Double(box2.frame.origin.x) == x2)
        }

        // Column: two 20x20 children in 100 tall container. Remaining = 60. topLeft alignment.
        @Test(arguments: [
            (Spread.packed,  0.0, 20.0),
            (Spread.between, 0.0, 80.0),
            (Spread.around,  15.0, 65.0),
            (Spread.even,    20.0, 60.0),
        ])
        func column(spread: Spread, y1: Double, y2: Double) {
            let flex = FlexView()
            flex.style = FlexStyle(axis: .vertical, spacing: 0, alignment: .topLeft, spread: spread)
            flex.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
            let box1 = BoxView(); box1.sizing = .fixed(20, 20)
            let box2 = BoxView(); box2.sizing = .fixed(20, 20)
            flex.addSubview(box1)
            flex.addSubview(box2)
            flex.layoutSubviews()

            #expect(Double(box1.frame.origin.y) == y1)
            #expect(Double(box2.frame.origin.y) == y2)
        }
    }

    // MARK: - CrossFill

    @Suite("CrossFill") @MainActor
    struct CrossFillTests {

        // Row: fixed 30x40 + fill-cross fix(40). Line cross from sibling = 40.
        // .sibling → fill child gets 40. .parent → fill child gets 100.
        @Test(arguments: [
            (CrossFill.sibling, 40.0),
            (CrossFill.parent,  100.0),
        ])
        func row(crossFill: CrossFill, h2: Double) {
            let flex = FlexView()
            flex.style = FlexStyle(axis: .horizontal, spacing: 0, alignment: .topLeft, spread: .packed, crossFill: crossFill)
            flex.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
            let box1 = BoxView(); box1.sizing = .fixed(30, 40)
            let box2 = BoxView(); box2.sizing = Frame(.fix(40), .fill())
            flex.addSubview(box1)
            flex.addSubview(box2)
            flex.layoutSubviews()

            #expect(Double(box1.frame.size.height) == 40)
            #expect(Double(box2.frame.size.height) == h2)
        }

        // Column: fixed 40x30 + fill-cross fix(40). Line cross from sibling = 40.
        // .sibling → fill child gets 40. .parent → fill child gets 100.
        @Test(arguments: [
            (CrossFill.sibling, 40.0),
            (CrossFill.parent,  100.0),
        ])
        func column(crossFill: CrossFill, w2: Double) {
            let flex = FlexView()
            flex.style = FlexStyle(axis: .vertical, spacing: 0, alignment: .topLeft, spread: .packed, crossFill: crossFill)
            flex.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
            let box1 = BoxView(); box1.sizing = .fixed(40, 30)
            let box2 = BoxView(); box2.sizing = Frame(.fill(), .fix(40))
            flex.addSubview(box1)
            flex.addSubview(box2)
            flex.layoutSubviews()

            #expect(Double(box1.frame.size.width) == 40)
            #expect(Double(box2.frame.size.width) == w2)
        }
    }
    // MARK: - Wrap

    @Suite("Wrap") @MainActor
    struct WrapTests {

        // Row: 7 boxes of 30x20 in 100-wide container, spacing=0, lineSpacing=10.
        // Line 1: 30+30+30=90 ≤ 100, +30=120 > 100 → items 0,1,2
        // Line 2: items 3,4,5
        // Line 3: item 6
        @Test func row() {
            let flex = FlexView()
            flex.style = FlexStyle(axis: .horizontal, spacing: 0, lineSpacing: 10, alignment: .topLeft, wrap: true)
            flex.frame = CGRect(x: 0, y: 0, width: 100, height: 200)

            let boxes = (0..<7).map { _ in
                let b = BoxView(); b.sizing = .fixed(30, 20); flex.addSubview(b); return b
            }
            flex.layoutSubviews()

            // Line 1 (y=0)
            #expect(Double(boxes[0].frame.origin.x) == 0)
            #expect(Double(boxes[0].frame.origin.y) == 0)
            #expect(Double(boxes[1].frame.origin.x) == 30)
            #expect(Double(boxes[1].frame.origin.y) == 0)
            #expect(Double(boxes[2].frame.origin.x) == 60)
            #expect(Double(boxes[2].frame.origin.y) == 0)

            // Line 2 (y = 20 + 10 = 30)
            #expect(Double(boxes[3].frame.origin.x) == 0)
            #expect(Double(boxes[3].frame.origin.y) == 30)
            #expect(Double(boxes[4].frame.origin.x) == 30)
            #expect(Double(boxes[4].frame.origin.y) == 30)
            #expect(Double(boxes[5].frame.origin.x) == 60)
            #expect(Double(boxes[5].frame.origin.y) == 30)

            // Line 3 (y = 30 + 20 + 10 = 60)
            #expect(Double(boxes[6].frame.origin.x) == 0)
            #expect(Double(boxes[6].frame.origin.y) == 60)
        }

        // Column: 7 boxes of 20x30 in 100-tall container, spacing=0, lineSpacing=10.
        // Line 1: 30+30+30=90 ≤ 100, +30=120 > 100 → items 0,1,2
        // Line 2: items 3,4,5
        // Line 3: item 6
        @Test func column() {
            let flex = FlexView()
            flex.style = FlexStyle(axis: .vertical, spacing: 0, lineSpacing: 10, alignment: .topLeft, wrap: true)
            flex.frame = CGRect(x: 0, y: 0, width: 200, height: 100)

            let boxes = (0..<7).map { _ in
                let b = BoxView(); b.sizing = .fixed(20, 30); flex.addSubview(b); return b
            }
            flex.layoutSubviews()

            // Line 1 (x=0)
            #expect(Double(boxes[0].frame.origin.x) == 0)
            #expect(Double(boxes[0].frame.origin.y) == 0)
            #expect(Double(boxes[1].frame.origin.x) == 0)
            #expect(Double(boxes[1].frame.origin.y) == 30)
            #expect(Double(boxes[2].frame.origin.x) == 0)
            #expect(Double(boxes[2].frame.origin.y) == 60)

            // Line 2 (x = 20 + 10 = 30)
            #expect(Double(boxes[3].frame.origin.x) == 30)
            #expect(Double(boxes[3].frame.origin.y) == 0)
            #expect(Double(boxes[4].frame.origin.x) == 30)
            #expect(Double(boxes[4].frame.origin.y) == 30)
            #expect(Double(boxes[5].frame.origin.x) == 30)
            #expect(Double(boxes[5].frame.origin.y) == 60)

            // Line 3 (x = 30 + 20 + 10 = 60)
            #expect(Double(boxes[6].frame.origin.x) == 60)
            #expect(Double(boxes[6].frame.origin.y) == 0)
        }
    }
}

#endif
