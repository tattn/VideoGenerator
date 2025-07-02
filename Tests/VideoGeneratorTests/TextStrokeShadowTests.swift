import Testing
@testable import VideoGenerator
import Foundation
import CoreGraphics
import CoreText
import AVFoundation

@Suite("Text Stroke and Shadow Tests")
struct TextStrokeShadowTests {
    
    @Test("Create text with single stroke")
    func testSingleStroke() throws {
        let stroke = TextStroke(color: CGColor(red: 0, green: 0, blue: 0, alpha: 1), width: 4)
        let textItem = TextMediaItem(
            text: "Test",
            font: CTFont(.system, size: 48),
            color: CGColor(red: 1, green: 1, blue: 1, alpha: 1),
            duration: CMTime(seconds: 3, preferredTimescale: 30),
            strokes: [stroke]
        )
        
        #expect(textItem.strokes.count == 1)
        #expect(textItem.strokes[0].width == 4)
        #expect(textItem.shadow == nil)
    }
    
    @Test("Create text with multiple strokes")
    func testMultipleStrokes() throws {
        let strokes = [
            TextStroke(color: CGColor(red: 1, green: 0, blue: 0, alpha: 1), width: 8),
            TextStroke(color: CGColor(red: 0, green: 1, blue: 0, alpha: 1), width: 6),
            TextStroke(color: CGColor(red: 0, green: 0, blue: 1, alpha: 1), width: 4)
        ]
        
        let textItem = TextMediaItem(
            text: "Rainbow",
            font: CTFont(.system, size: 60),
            color: CGColor(red: 1, green: 1, blue: 1, alpha: 1),
            duration: CMTime(seconds: 3, preferredTimescale: 30),
            strokes: strokes
        )
        
        #expect(textItem.strokes.count == 3)
        #expect(textItem.strokes[0].width == 8)
        #expect(textItem.strokes[1].width == 6)
        #expect(textItem.strokes[2].width == 4)
    }
    
    @Test("Create text with shadow")
    func testShadow() throws {
        let shadow = TextShadow(
            color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.8),
            offset: CGSize(width: 5, height: 5),
            blur: 10
        )
        
        let textItem = TextMediaItem(
            text: "Shadow",
            font: CTFont(.system, size: 48),
            color: CGColor(red: 1, green: 1, blue: 0, alpha: 1),
            duration: CMTime(seconds: 3, preferredTimescale: 30),
            shadow: shadow
        )
        
        #expect(textItem.shadow != nil)
        #expect(textItem.shadow?.offset.width == 5)
        #expect(textItem.shadow?.offset.height == 5)
        #expect(textItem.shadow?.blur == 10)
        #expect(textItem.strokes.isEmpty)
    }
    
    @Test("Create text with both stroke and shadow")
    func testStrokeAndShadow() throws {
        let stroke = TextStroke(color: CGColor(red: 0, green: 0, blue: 0, alpha: 1), width: 3)
        let shadow = TextShadow(
            color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.5),
            offset: CGSize(width: 2, height: 2),
            blur: 5
        )
        
        let textItem = TextMediaItem(
            text: "Both",
            font: CTFont(.system, size: 48),
            color: CGColor(red: 1, green: 1, blue: 1, alpha: 1),
            duration: CMTime(seconds: 3, preferredTimescale: 30),
            strokes: [stroke],
            shadow: shadow
        )
        
        #expect(textItem.strokes.count == 1)
        #expect(textItem.shadow != nil)
    }
    
    @Test("Create clip with MediaItemBuilder")
    func testMediaItemBuilder() throws {
        let strokes = [
            TextStroke(color: CGColor(red: 0, green: 0, blue: 0, alpha: 1), width: 2)
        ]
        let shadow = TextShadow(
            color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.3),
            offset: CGSize(width: 1, height: 1),
            blur: 2
        )
        
        let clip = Clip(
            mediaItem: .text("Builder", font: CTFont(.system, size: 36), color: .init(red: 1, green: 0, blue: 0, alpha: 1), strokes: strokes, shadow: shadow),
            timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 2, preferredTimescale: 30)),
            frame: CGRect(x: 0, y: 0, width: 200, height: 100)
        )
        
        #expect(clip.mediaItem is TextMediaItem)
        guard let textItem = clip.mediaItem as? TextMediaItem else {
            Issue.record("Failed to cast mediaItem to TextMediaItem")
            return
        }
        #expect(textItem.strokes.count == 1)
        #expect(textItem.shadow != nil)
    }
}