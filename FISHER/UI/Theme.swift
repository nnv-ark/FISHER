import SwiftUI
import AppKit
import CoreText

/// The masthead is set in a Fraktur that macOS does not ship, so the app
/// carries its own copy (UnifrakturMaguntia, SIL Open Font License — the
/// licence travels with it in Resources) and registers it at launch.
/// Xcode will not write ATSApplicationFontsPath from a build setting, so
/// this is done in code rather than in the Info.plist.
enum BundledFonts {
    static func register() {
        guard let urls = Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) else { return }
        for url in urls {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}

/// Newsprint. Warm paper, a Didone masthead, Times for the reading, and
/// grotesque capitals for the furniture — the way a paper is actually set.
enum Paper {

    // MARK: type

    private static func pick(_ names: [String]) -> String? {
        let families = Set(NSFontManager.shared.availableFontFamilies)
        let fonts = Set(NSFontManager.shared.availableFonts)
        return names.first { families.contains($0) || fonts.contains($0) }
    }

    static let subheadFace  = pick(["Bodoni 72", "Didot", "Big Caslon", "Baskerville"])
    static let textFace     = pick(["Times New Roman", "Times", "Hoefler Text", "Georgia"])
    static let labelFace    = pick(["Helvetica Neue", "Helvetica", "Arial"])

    static func masthead(_ size: CGFloat) -> Font {
        let wanted = Defaults.mastheadFace.fontName
        if NSFont(name: wanted, size: size) != nil { return Font.custom(wanted, size: size) }
        if let fallback = pick(["Bodoni 72", "Didot", "Big Caslon"]) { return Font.custom(fallback, size: size) }
        return .system(size: size, weight: .heavy, design: .serif)
    }
    static func subhead(_ size: CGFloat) -> Font {
        subheadFace.map { Font.custom($0, size: size).weight(.bold) }
            ?? .system(size: size, weight: .bold, design: .serif)
    }
    static func head(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        textFace.map { Font.custom($0, size: size).weight(weight) }
            ?? .system(size: size, weight: weight, design: .serif)
    }
    static func body(_ size: CGFloat) -> Font {
        textFace.map { Font.custom($0, size: size) } ?? .system(size: size, design: .serif)
    }
    static func label(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        labelFace.map { Font.custom($0, size: size).weight(weight) }
            ?? .system(size: size, weight: weight)
    }

    /// Older call sites.
    static func serif(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font { head(size, weight) }

    static func nsBody(_ size: CGFloat) -> NSFont {
        textFace.flatMap { NSFont(name: $0, size: size) } ?? NSFont.systemFont(ofSize: size)
    }

    // MARK: ink and paper

    private static func grey(_ v: Int) -> NSColor {
        NSColor(srgbRed: CGFloat(v) / 255, green: CGFloat(v) / 255, blue: CGFloat(v) / 255, alpha: 1)
    }

    /// Fixed, not dynamic. A paper is white in the morning whatever the
    /// system appearance is set to, and the window is forced light to match.
    static let sheet  = Color(nsColor: grey(255))
    static let ink    = Color(nsColor: grey(0))
    static let ink2   = Color(nsColor: grey(51))
    static let ink3   = Color(nsColor: grey(110))
    static let rule   = Color(nsColor: grey(180))
    /// There is no second colour. A newspaper is ink on paper.
    static let accent = Color(nsColor: grey(0))
    static let sea    = Color(nsColor: grey(68))

    static var nsInk: NSColor {
        grey(0)
    }
}

/// Justified, hyphenated body text with a raised initial capital — the two
/// things that make a block of type read as newspaper rather than as a web page.
struct NewsText: NSViewRepresentable {
    let string: String
    var size: CGFloat = 15
    var initialCap: Bool = false

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField(wrappingLabelWithString: string)
        field.isEditable = false
        field.isSelectable = true
        field.drawsBackground = false
        field.isBordered = false
        field.lineBreakMode = .byWordWrapping
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        field.attributedStringValue = attributed()
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSTextField, context: Context) -> CGSize? {
        let width = proposal.width ?? 600
        nsView.preferredMaxLayoutWidth = width
        nsView.attributedStringValue = attributed()
        return CGSize(width: width, height: nsView.intrinsicContentSize.height)
    }

    private func attributed() -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .justified
        paragraph.lineHeightMultiple = 1.08
        paragraph.hyphenationFactor = 1
        paragraph.firstLineHeadIndent = 0

        let text = NSMutableAttributedString(string: string, attributes: [
            .font: Paper.nsBody(size),
            .foregroundColor: Paper.nsInk,
            .paragraphStyle: paragraph
        ])
        if initialCap, !string.isEmpty {
            text.addAttributes([
                .font: Paper.nsBody(size * 2.6),
                .kern: 1.0
            ], range: NSRange(location: 0, length: 1))
        }
        return text
    }
}

/// Drawn stand-in when a listing has no usable photograph. Ink on paper,
/// like a woodcut in the classifieds.
struct BoatMark: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width, h = size.height
            let cx = w * 0.5

            var hull = Path()
            hull.move(to: CGPoint(x: w * 0.20, y: h * 0.72))
            hull.addQuadCurve(to: CGPoint(x: w * 0.80, y: h * 0.72), control: CGPoint(x: cx, y: h * 0.90))
            hull.addQuadCurve(to: CGPoint(x: w * 0.20, y: h * 0.72), control: CGPoint(x: cx, y: h * 0.80))
            context.fill(hull, with: .color(Paper.ink.opacity(0.88)))

            var main = Path()
            main.move(to: CGPoint(x: cx + w * 0.012, y: h * 0.14))
            main.addQuadCurve(to: CGPoint(x: cx + w * 0.19, y: h * 0.70),
                              control: CGPoint(x: cx + w * 0.16, y: h * 0.44))
            main.addLine(to: CGPoint(x: cx + w * 0.012, y: h * 0.70))
            main.closeSubpath()
            context.stroke(main, with: .color(Paper.ink.opacity(0.8)), lineWidth: 1.2)

            var jib = Path()
            jib.move(to: CGPoint(x: cx - w * 0.012, y: h * 0.20))
            jib.addQuadCurve(to: CGPoint(x: cx - w * 0.20, y: h * 0.70),
                             control: CGPoint(x: cx - w * 0.17, y: h * 0.48))
            jib.addLine(to: CGPoint(x: cx - w * 0.012, y: h * 0.70))
            jib.closeSubpath()
            context.stroke(jib, with: .color(Paper.ink.opacity(0.8)), lineWidth: 1.2)

            var mast = Path()
            mast.move(to: CGPoint(x: cx, y: h * 0.12))
            mast.addLine(to: CGPoint(x: cx, y: h * 0.74))
            context.stroke(mast, with: .color(Paper.ink.opacity(0.88)), lineWidth: 1.4)

            for i in 0..<3 {
                var wave = Path()
                let y = h * (0.84 + Double(i) * 0.05)
                wave.move(to: CGPoint(x: 0, y: y))
                wave.addLine(to: CGPoint(x: w, y: y))
                context.stroke(wave, with: .color(Paper.ink.opacity(0.25)), lineWidth: 0.8)
            }
        }
        .background(Paper.ink.opacity(0.04))
    }
}

struct SectionFlag: View {
    let text: String
    var body: some View {
        HStack(spacing: 8) {
            Text(text.uppercased())
                .font(Paper.label(9.5))
                .tracking(1.6)
                .foregroundStyle(Paper.accent)
            Rectangle().fill(Paper.rule).frame(height: 0.75)
        }
    }
}

/// The double rule a masthead sits on.
struct DoubleRule: View {
    var body: some View {
        VStack(spacing: 2) {
            Rectangle().fill(Paper.ink).frame(height: 2.5)
            Rectangle().fill(Paper.ink).frame(height: 0.75)
        }
    }
}
