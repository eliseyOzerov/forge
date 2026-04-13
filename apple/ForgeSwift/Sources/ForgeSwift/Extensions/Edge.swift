//
//  Edge.swift
//  UIKitPlayground
//
//  Created by Elisey Ozerov on 1. 8. 25.
//

/// Check out SwiftUI's Edge.Set
enum Edge: Int8, CaseIterable {
    case top, bottom, leading, trailing
    
    struct Set: OptionSet {
        public typealias Element = Edge.Set
        
        let rawValue: Int8
        
        init(rawValue: Int8) {
            self.rawValue = rawValue
        }
        
        // Basic values
        
        static let top = Set(rawValue: 1 << 0)
        static let bottom = Set(rawValue: 1 << 1)
        static let leading = Set(rawValue: 1 << 2)
        static let trailing = Set(rawValue: 1 << 3)
        
        // Basic combos
        
        static let all: Set = [.top, .bottom, .leading, .trailing]
        static let horizontal: Set = [.leading, .trailing]
        static let vertical: Set = [.top, .bottom]
        
        // Corners
        
        static let topTrailing: Set = [.top, .trailing]
        static let topLeading: Set = [.top, .leading]
        static let bottomTrailing: Set = [.bottom, .trailing]
        static let bottomLeading: Set = [.bottom, .leading]
        
        // U-shape
        
        static let topCorners: Set = [.top, .horizontal]
        static let bottomCorners: Set = [.bottom, .horizontal]
        static let leadingCorners: Set = [.leading, .vertical]
        static let trailingCorners: Set = [.trailing, .vertical]
    }
}
