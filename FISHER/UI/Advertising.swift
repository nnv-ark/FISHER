import SwiftUI

/// The free edition carries advertising, the way a free paper always has.
/// The bought one prints none — that is the whole difference, and it is worth
/// making the boxes look like real newspaper advertising rather than banners:
/// ruled, small, set in the same ink, sitting either side of the flag the way
/// they have since the 1930s.
enum Advertising {
    static func isPro() -> Bool { Defaults.isPro }
}

/// The little boxed advertisements that flank a masthead. Papers call them ears.
struct AdEar: View {
    let lines: [String]
    var body: some View {
        VStack(spacing: 3) {
            Text("Advertisement")
                .font(Paper.label(6.5))
                .tracking(0.9)
                .textCase(.uppercase)
                .foregroundStyle(Paper.ink3)
            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                Text(line)
                    .font(index == 0 ? Paper.head(12) : Paper.body(9.5))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Paper.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 8)
        .frame(width: 128, height: 84)
        .overlay(Rectangle().strokeBorder(Paper.ink, lineWidth: 1))
    }
}

/// A single ruled strip across the page.
struct AdBanner: View {
    let headline: String
    let message: String

    var body: some View {
        VStack(spacing: 0) {
            Text("Advertisement")
                .font(Paper.label(6.5))
                .tracking(1)
                .textCase(.uppercase)
                .foregroundStyle(Paper.ink3)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 3)
            VStack(spacing: 3) {
                Text(headline)
                    .font(Paper.head(17))
                    .foregroundStyle(Paper.ink)
                Text(message)
                    .font(Paper.body(11.5))
                    .foregroundStyle(Paper.ink2)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .overlay(Rectangle().strokeBorder(Paper.ink, lineWidth: 1))
        }
        .padding(.top, 14)
    }
}
