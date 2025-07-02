import Foundation
import CoreGraphics

// MARK: - CGRect Extensions for iOS-style Frame Layout

extension CGRect {
    // MARK: - Convenience Initializers
    
    public init(x: CGFloat, y: CGFloat, size: CGSize) {
        self.init(origin: CGPoint(x: x, y: y), size: size)
    }
    
    public init(center: CGPoint, size: CGSize) {
        self.init(
            x: center.x - size.width / 2,
            y: center.y - size.height / 2,
            width: size.width,
            height: size.height
        )
    }
    
    // MARK: - Frame Properties
    
    public var x: CGFloat {
        get { origin.x }
        set { origin.x = newValue }
    }
    
    public var y: CGFloat {
        get { origin.y }
        set { origin.y = newValue }
    }
    
    public var center: CGPoint {
        get { CGPoint(x: midX, y: midY) }
        set {
            origin.x = newValue.x - size.width / 2
            origin.y = newValue.y - size.height / 2
        }
    }
    
    public var top: CGFloat {
        get { minY }
        set { origin.y = newValue }
    }
    
    public var bottom: CGFloat {
        get { maxY }
        set { origin.y = newValue - size.height }
    }
    
    public var left: CGFloat {
        get { minX }
        set { origin.x = newValue }
    }
    
    public var right: CGFloat {
        get { maxX }
        set { origin.x = newValue - size.width }
    }
    
    // MARK: - Frame Manipulation
    
    public func inset(by insets: EdgeInsets) -> CGRect {
        CGRect(
            x: origin.x + insets.left,
            y: origin.y + insets.top,
            width: size.width - insets.left - insets.right,
            height: size.height - insets.top - insets.bottom
        )
    }
    
    public func offset(by point: CGPoint) -> CGRect {
        CGRect(
            x: origin.x + point.x,
            y: origin.y + point.y,
            width: size.width,
            height: size.height
        )
    }
}

// MARK: - EdgeInsets

public struct EdgeInsets: Sendable {
    public var top: CGFloat
    public var left: CGFloat
    public var bottom: CGFloat
    public var right: CGFloat
    
    public init(top: CGFloat = 0, left: CGFloat = 0, bottom: CGFloat = 0, right: CGFloat = 0) {
        self.top = top
        self.left = left
        self.bottom = bottom
        self.right = right
    }
    
    public static func all(_ value: CGFloat) -> EdgeInsets {
        EdgeInsets(top: value, left: value, bottom: value, right: value)
    }
    
    public static func horizontal(_ value: CGFloat) -> EdgeInsets {
        EdgeInsets(top: 0, left: value, bottom: 0, right: value)
    }
    
    public static func vertical(_ value: CGFloat) -> EdgeInsets {
        EdgeInsets(top: value, left: 0, bottom: value, right: 0)
    }
}