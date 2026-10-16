import AppKit
import SwiftUI

struct IconButton: View {
    let symbol: String
    var help: String = ""
    var size: CGFloat = 14
    var color: Color = G.Colors.textSecondary
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: size, weight: .regular))
                .foregroundStyle(hover ? G.Colors.textPrimary : color)
                .frame(width: 28, height: 28)
                .background(RoundedRectangle(cornerRadius: G.Radius.sm).fill(hover ? G.Colors.surfaceHover : .clear))
        }
        .buttonStyle(.plain).help(help).accessibilityLabel(help.isEmpty ? symbol : help)
        .onHover { hover = $0 }
    }
}

/// Rounded outline pill, Granola's secondary button ("New note", "Add to folder").
struct PillButton<Label: View>: View {
    @ViewBuilder let label: () -> Label
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            label()
                .font(G.Fonts.ui(13.5, .medium))
                .foregroundStyle(G.Colors.textPrimary)
                .padding(.horizontal, 12).frame(height: 30)
                .background(Capsule().fill(hover ? G.Colors.surfaceHover : Color.clear))
                .overlay(Capsule().strokeBorder(G.Colors.border, lineWidth: 1))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}

/// Small rounded chip used for suggestions ("Write follow up email").
struct SuggestionChip: View {
    let title: String
    var symbol = "pencil.and.scribble"
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: symbol).font(.system(size: 12))
                Text(title).font(G.Fonts.ui(13.5, .medium)).lineLimit(1)
            }
            .foregroundStyle(G.Colors.textPrimary)
            .padding(.horizontal, 12).frame(height: 32)
            .background(Capsule().fill(hover ? G.Colors.tile : G.Colors.surfaceRaised))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}

/// Animated bars: live levels while recording, a still glyph otherwise.
struct Waveform: View {
    var level: Float
    var active: Bool
    var color: Color = G.Colors.textPrimary
    var bars = 3
    @State private var phase = 0.0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 20, paused: !active)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            HStack(spacing: 2.5) {
                ForEach(0..<bars, id: \.self) { i in
                    let base: [CGFloat] = [0.55, 1.0, 0.7, 0.9, 0.5]
                    let wobble = active ? CGFloat(0.35 + 0.65 * abs(sin(t * 7 + Double(i) * 1.7))) : 1
                    let amp = active ? max(0.25, min(1, CGFloat(level) * 1.6 + 0.2)) : 1
                    Capsule().fill(color)
                        .frame(width: 2.6, height: 16 * base[i % base.count] * (active ? wobble * amp : 1))
                }
            }
            .frame(height: 18)
        }
    }
}

/// Initial-letter avatar tile ("H"), or a document glyph.
struct NoteTile: View {
    let note: Note
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7).fill(tileColor)
            if let a = note.attendees.first {
                Text(String(a.name.prefix(1)).uppercased()).font(G.Fonts.serif(17, .medium)).foregroundStyle(.white.opacity(0.92))
            } else {
                Image(systemName: "doc").font(.system(size: 14)).foregroundStyle(G.Colors.textSecondary)
            }
        }
        .frame(width: 34, height: 34)
    }

    private var tileColor: Color {
        guard let a = note.attendees.first else { return G.Colors.tile }
        let palette: [UInt32] = [0x8A5A2B, 0x3E6B48, 0x4A5F8C, 0x7B4A7A, 0x8C4A4A, 0x5C6B2E]
        let h = abs(a.name.unicodeScalars.reduce(0) { $0 &* 31 &+ Int($1.value) })
        return Color(nsColor: NSColor(hex: palette[h % palette.count]))
    }
}

/// A plain NSTextView editor: fast, native undo, our font and spacing.
struct PlainTextEditor: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var font: NSFont = G.Fonts.nsUI(15.5)
    var autofocus = false

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSTextView.scrollableTextView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = false
        let tv = scroll.documentView as! NSTextView
        tv.delegate = context.coordinator
        tv.drawsBackground = false
        tv.isRichText = false
        tv.allowsUndo = true
        tv.font = font
        tv.textColor = .labelColor
        tv.textContainerInset = NSSize(width: 0, height: 4)
        tv.textContainer?.lineFragmentPadding = 0
        let p = NSMutableParagraphStyle(); p.lineSpacing = 6; p.paragraphSpacing = 4
        tv.defaultParagraphStyle = p
        tv.typingAttributes = [.font: font, .foregroundColor: NSColor.labelColor, .paragraphStyle: p]
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.string = text
        context.coordinator.placeholderView = context.coordinator.makePlaceholder(in: tv, text: placeholder, font: font)
        context.coordinator.updatePlaceholder(tv)
        if autofocus { DispatchQueue.main.async { tv.window?.makeFirstResponder(tv) } }
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let tv = scroll.documentView as? NSTextView else { return }
        if tv.string != text { tv.string = text; context.coordinator.updatePlaceholder(tv) }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: PlainTextEditor
        var placeholderView: NSTextField?
        init(_ p: PlainTextEditor) { parent = p }

        func textDidChange(_ n: Notification) {
            guard let tv = n.object as? NSTextView else { return }
            parent.text = tv.string
            updatePlaceholder(tv)
        }

        /// Typing "- " or "* " at a line start becomes a bullet; Return
        /// continues the list, Return on an empty bullet ends it.
        func textView(_ tv: NSTextView, doCommandBy sel: Selector) -> Bool {
            guard sel == #selector(NSResponder.insertNewline(_:)) else { return false }
            let ns = tv.string as NSString
            let r = ns.lineRange(for: NSRange(location: tv.selectedRange().location, length: 0))
            let line = ns.substring(with: r).trimmingCharacters(in: .newlines)
            let indent = String(line.prefix { $0 == " " || $0 == "\t" })
            let body = line.dropFirst(indent.count)
            for marker in ["• ", "- ", "* "] where body.hasPrefix(marker) {
                if body.count == marker.count {
                    tv.replaceCharacters(in: NSRange(location: r.location, length: (line as NSString).length), with: "")
                    parent.text = tv.string
                    return true
                }
                tv.insertText("\n" + indent + "• ", replacementRange: tv.selectedRange())
                return true
            }
            return false
        }

        func textView(_ tv: NSTextView, shouldChangeTextIn range: NSRange, replacementString s: String?) -> Bool {
            guard s == " " else { return true }
            let ns = tv.string as NSString
            let r = ns.lineRange(for: NSRange(location: range.location, length: 0))
            let before = ns.substring(with: NSRange(location: r.location, length: range.location - r.location))
            if before.trimmingCharacters(in: .whitespaces) == "-" || before.trimmingCharacters(in: .whitespaces) == "*" {
                let dash = before.firstIndex(where: { $0 == "-" || $0 == "*" })!
                let off = before.distance(from: before.startIndex, to: dash)
                tv.replaceCharacters(in: NSRange(location: r.location + off, length: 1), with: "• ")
                parent.text = tv.string
                return false
            }
            return true
        }

        func makePlaceholder(in tv: NSTextView, text: String, font: NSFont) -> NSTextField {
            let f = NSTextField(labelWithString: text)
            f.font = font; f.textColor = .placeholderTextColor
            f.translatesAutoresizingMaskIntoConstraints = false
            tv.addSubview(f)
            NSLayoutConstraint.activate([f.leadingAnchor.constraint(equalTo: tv.leadingAnchor),
                                         f.topAnchor.constraint(equalTo: tv.topAnchor, constant: 4)])
            return f
        }

        func updatePlaceholder(_ tv: NSTextView) { placeholderView?.isHidden = !tv.string.isEmpty }
    }
}

extension Date {
    var shortTime: String {
        let f = DateFormatter(); f.dateFormat = "h:mm a"; return f.string(from: self)
    }
    var dayHeader: String {
        let f = DateFormatter(); f.dateFormat = "EEE, MMM d"; return f.string(from: self)
    }
}

/// Model answers are Markdown; SwiftUI renders inline styles but not list
/// markers, so turn "- " / "* " / "1. " line starts into bullets first.
func displayMarkdown(_ s: String) -> AttributedString {
    let lines = s.split(separator: "\n", omittingEmptySubsequences: false).map { line -> String in
        let indent = line.prefix { $0 == " " }
        let body = line.dropFirst(indent.count)
        if body.hasPrefix("- ") || body.hasPrefix("* ") { return String(indent) + "• " + body.dropFirst(2) }
        return String(line)
    }
    let joined = lines.joined(separator: "\n")
    return (try? AttributedString(markdown: joined, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(joined)
}

func copyToPasteboard(_ s: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(s, forType: .string)
}
