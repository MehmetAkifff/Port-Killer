//
//  PortStatusDot.swift
//

import AppKit
import SwiftUI

/// NSMenu flattens SF Symbol tinting to monochrome; a non-template `NSImage` keeps true colors.
enum PortStatusDotImage {

    static func nsImage(active: Bool, diameterPoints: CGFloat = 10) -> NSImage {
        let img = NSImage(size: NSSize(width: diameterPoints, height: diameterPoints), flipped: false) { rect in
            (active ? NSColor.systemRed : NSColor.tertiaryLabelColor).setFill()
            let inset = diameterPoints * 0.12
            NSBezierPath(ovalIn: rect.insetBy(dx: inset, dy: inset)).fill()
            return true
        }
        img.isTemplate = false
        return img
    }
}

struct PortStatusDot: View {
    var active: Bool
    var displaySize: CGFloat = 8

    var body: some View {
        Image(nsImage: PortStatusDotImage.nsImage(active: active))
            .resizable()
            .interpolation(.high)
            .frame(width: displaySize, height: displaySize)
            .accessibilityLabel(active ? "In use" : "Free")
    }
}
