import AppKit
import CoreText
import SwiftUI

/// Design tokens, measured from Granola's Mac app (2026-10-16). Fonts are
/// the OFL faces Granola itself falls back to: Inter for UI text and IBM
/// Plex Serif for titles (its own faces are proprietary and not shipped).
enum G {
    enum Colors {
        static let background = dyn(light: 0xF7F7F2, dark: 0x292929)
        static let sidebar = dyn(light: 0xF2F2EC, dark: 0x212121)
        /// Cards, the ask bar, the transcript panel, menus.
        static let surface = dyn(light: 0xFFFFFF, dark: 0x363635)
        static let surfaceRaised = dyn(light: 0xECECE6, dark: 0x434341)
        static let surfaceHover = dyn(light: 0xEEEEE8, dark: 0x323231)
        static let tile = dyn(light: 0xE6E6DF, dark: 0x4A4A47)
        static let border = dyn(light: 0xE2E0D4, dark: 0x444443)
        static let textPrimary = dyn(light: 0x292929, dark: 0xFCFCF8)
        static let textSecondary = dyn(light: 0x72726E, dark: 0x9E9E99)
        static let textTertiary = dyn(light: 0xACADA8, dark: 0x818179)
        /// Generated text in enhanced notes (your own lines stay textPrimary).
        static let generated = dyn(light: 0x72726E, dark: 0xB0B0AB)
        static let accent = dyn(light: 0x5B6F00, dark: 0xB2C248)
        static let accentSoft = dyn(light: 0xEEF2D6, dark: 0x3B4020)
        static let recording = dyn(light: 0xBD4A30, dark: 0xE95D3D)
        static let meBubble = dyn(light: 0xE4E4DC, dark: 0x292929)
        static let themBubble = dyn(light: 0xF2F2EC, dark: 0x4F4F4C)
        static let button = dyn(light: 0x292929, dark: 0xFCFCF8)
        static let audio = dyn(light: 0x5E9A00, dark: 0x74BD00)
        static let onButton = dyn(light: 0xFFFFFF, dark: 0x292929)
    }

    enum Fonts {
        static func ui(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font { Font.custom(sans, size: size).weight(weight) }
        static func serif(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font { Font.custom(serifName, size: size).weight(weight) }
        static let body = ui(14)
        static let secondary = ui(13)
        static let meta = ui(12)
        static let title = serif(30)
        static let display = serif(26)

        static let sans = "Inter"
        static let serifName = "IBM Plex Serif"

        /// Register the bundled TTFs once at launch (process scope).
        static func register() {
            let bundle = Bundle.module
            for name in ["Inter", "IBMPlexSerif-Regular", "IBMPlexSerif-Medium"] {
                guard let url = bundle.url(forResource: name, withExtension: "ttf", subdirectory: "Fonts") else { continue }
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }

        static func nsUI(_ size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
            let base = NSFont(name: sans, size: size) ?? .systemFont(ofSize: size)
            let d = base.fontDescriptor.addingAttributes([.traits: [NSFontDescriptor.TraitKey.weight: weight]])
            return NSFont(descriptor: d, size: size) ?? base
        }
    }

    enum Radius { static let sm: CGFloat = 6; static let md: CGFloat = 8; static let lg: CGFloat = 12; static let xl: CGFloat = 16 }
    enum Motion { static let gentle = Animation.easeOut(duration: 0.18) }

    static func dyn(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { ap in
            ap.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(hex: dark) : NSColor(hex: light)
        })
    }
}

extension NSColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
    }
}

extension View {
    /// Pointer cursor + a minimum hit target for anything clickable.
    func clickable(minSize: CGFloat = 24) -> some View {
        self.frame(minWidth: minSize, minHeight: minSize).contentShape(Rectangle())
            .onHover { inside in if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
    }
}

enum Mark {
    /// The tombstone-with-X mark as a menu-bar template image (18pt).
    static func menuBarImage() -> NSImage {
        let img = NSImage(size: NSSize(width: 18, height: 18), flipped: true) { r in
            let u = r.width / 32
            func p(_ x: CGFloat, _ y: CGFloat) -> NSPoint { NSPoint(x: x * u, y: y * u) }
            NSColor.black.setFill()
            let stone = NSBezierPath()
            stone.move(to: p(8, 24)); stone.line(to: p(8, 13.5))
            stone.appendArc(withCenter: p(16, 13.5), radius: 8 * u, startAngle: 180, endAngle: 0, clockwise: false)
            stone.line(to: p(24, 24)); stone.close()
            stone.fill()
            NSBezierPath(roundedRect: NSRect(x: 5 * u, y: 23 * u, width: 22 * u, height: 4.5 * u), xRadius: 1.6 * u, yRadius: 1.6 * u).fill()
            // Knock the X out of the stone.
            NSGraphicsContext.current?.compositingOperation = .clear
            let x = NSBezierPath(); x.lineWidth = 2.6 * u; x.lineCapStyle = .round
            x.move(to: p(12.2, 11.8)); x.line(to: p(19.8, 19.4))
            x.move(to: p(19.8, 11.8)); x.line(to: p(12.2, 19.4))
            x.stroke()
            return true
        }
        img.isTemplate = true
        return img
    }
}
