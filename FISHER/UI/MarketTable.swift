import SwiftUI

/// A newspaper prints the market table; it does not tell you a share is cheap
/// and leave you to take its word. This is every comparable thing the app has
/// actually seen, with the figure the story leans on shown in full — including
/// how thin the evidence is.
struct MarketTable: View {
    let market: Edition.Market
    let subject: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle().fill(Paper.ink).frame(height: 1)
            SectionFlag(text: "The market for \(subject)")
                .padding(.top, 7)
                .padding(.bottom, 5)

            Text(preamble)
                .font(Paper.body(12).italic())
                .foregroundStyle(Paper.ink2)
                .padding(.bottom, 6)
                .fixedSize(horizontal: false, vertical: true)

            row("Cheapest", market.cheapest, market.cheapestName)
            row("Middle", market.median, "the median of the \(market.count)")
            row("Dearest", market.dearest, market.dearestName)
            if let subjectPrice = market.subject {
                Rectangle().fill(Paper.rule).frame(height: 0.5)
                row("This one", subjectPrice, standing, emphasised: true)
            }

            Rectangle().fill(Paper.ink).frame(height: 0.75).padding(.top, 4)
            Text("Only what Wish Fisher has read, from the sources it reads, since it first looked. It is not a valuation, and it says nothing about anywhere it cannot see.")
                .font(Paper.body(10.5).italic())
                .foregroundStyle(Paper.ink3)
                .padding(.top, 4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 18)
    }

    private var preamble: String {
        "\(market.count) advertised since \(market.sinceLine), read from "
            + "\(market.sources) source\(market.sources == 1 ? "" : "s"). "
            + "Figures in \(market.currency.uppercased())."
    }

    private var standing: String {
        guard let subjectPrice = market.subject else { return "" }
        if subjectPrice <= market.cheapest { return "the cheapest of them" }
        if subjectPrice >= market.dearest { return "the dearest of them" }
        if subjectPrice == market.median { return "the middle one" }
        return subjectPrice < market.median ? "below the middle" : "above the middle"
    }

    private func row(_ label: String, _ amount: Double, _ note: String, emphasised: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(label.uppercased())
                .font(Paper.label(8.5, emphasised ? .bold : .semibold))
                .tracking(1)
                .foregroundStyle(emphasised ? Paper.ink : Paper.ink3)
                .frame(width: 74, alignment: .leading)
            Text(Money.format(amount.rounded(), market.currency))
                .font(Paper.body(13.5))
                .monospacedDigit()
                .foregroundStyle(Paper.ink)
                .frame(width: 118, alignment: .trailing)
            Text(note)
                .font(Paper.body(12))
                .foregroundStyle(Paper.ink2)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 3)
    }
}
