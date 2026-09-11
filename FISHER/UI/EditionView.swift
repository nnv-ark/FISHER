import SwiftUI
import AppKit

struct EditionView: View {
    @EnvironmentObject var store: Store
    @AppStorage(PrefKey.pro) private var isPro = false
    @AppStorage(PrefKey.frequency) private var frequency = Frequency.daily.rawValue
    let edition: Edition?

    private var cadence: Frequency { Frequency(rawValue: frequency) ?? .daily }
    private var paperName: String { "Wish Fisher — \(cadence.editionName)" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let edition {
                    if edition.isQuiet {
                        masthead(edition)
                        quiet(edition)
                    } else {
                        pages(edition)
                    }
                    colophon(edition)
                } else {
                    firstMorning
                }
            }
            .frame(maxWidth: 760, alignment: .leading)
            .padding(.horizontal, 38)
            .padding(.top, 24)
            .padding(.bottom, 52)
            .frame(maxWidth: .infinity)
        }
        .background(Paper.sheet)
        .tint(Paper.ink)
    }

    // MARK: the flag

    private func masthead(_ edition: Edition) -> some View {
        VStack(spacing: 0) {
            Rectangle().fill(Paper.ink).frame(height: 0.75)

            HStack(alignment: .center, spacing: 12) {
                if !isPro {
                    AdEar(lines: ["Wish Fisher Pro", "No advertisements.", "Not one, ever."])
                }
                Text("Wish Fisher — \(cadence.editionName)")
                    .font(Paper.masthead(46))
                    .foregroundStyle(Paper.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .frame(maxWidth: .infinity)
                if !isPro {
                    AdEar(lines: ["This space", "is for sale", "nnv.is"])
                }
            }
            .padding(.vertical, 10)

            DoubleRule()

            HStack(spacing: 0) {
                Text("Vol. I · No. \(edition.id)")
                Spacer(minLength: 10)
                Text(edition.dayLine.uppercased())
                Spacer(minLength: 10)
                Text(edition.readLine)
            }
            .font(Paper.label(9))
            .tracking(1.1)
            .textCase(.uppercase)
            .foregroundStyle(Paper.ink2)
            .monospacedDigit()
            .padding(.vertical, 6)

            if let missed = edition.missedSources, !missed.isEmpty {
                Text("Could not read: \(missed.joined(separator: ", "))")
                    .font(Paper.label(8))
                    .tracking(0.8)
                    .textCase(.uppercase)
                    .foregroundStyle(Paper.ink3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 5)
            }

            Rectangle().fill(Paper.ink).frame(height: 0.75)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: the paper, page by page

    /// One wish owns the front page. The others take a page each, in the order
    /// they stand in the sidebar — so the thing you care most about is what you
    /// see when the paper lands, and the rest is a turn of the page away.
    private func grouped(_ edition: Edition) -> [(flag: String, items: [Edition.Item])] {
        var all: [Edition.Item] = []
        if let lead = edition.lead { all.append(lead) }
        all += edition.seconds

        var byFlag: [String: [Edition.Item]] = [:]
        for item in all { byFlag[item.flag, default: []].append(item) }

        let order = store.wishes.map(\.displayName)
        return byFlag.keys
            .sorted { a, b in
                let ia = order.firstIndex(of: a) ?? Int.max
                let ib = order.firstIndex(of: b) ?? Int.max
                return ia == ib ? a < b : ia < ib
            }
            .map { flag in
                (flag, byFlag[flag]!.sorted { $0.listing.score > $1.listing.score })
            }
    }

    private func pages(_ edition: Edition) -> some View {
        let groups = grouped(edition)
        let hasTail = !edition.brief.isEmpty || !edition.obituaries.isEmpty || !edition.stillOut.isEmpty
        return VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(groups.enumerated()), id: \.offset) { index, group in
                if index == 0 {
                    masthead(edition)
                    if !isPro {
                        AdBanner(headline: "Read the paper without the advertising",
                                 message: "Wish Fisher Pro removes every advertisement from every edition. Settings ▸ General.")
                    }
                } else {
                    PageBreak(number: index + 1, paper: paperName, date: edition.shortDayLine)
                }
                section(group.flag, group.items, front: index == 0)
            }
            if hasTail {
                if groups.count > 1 {
                    PageBreak(number: groups.count + 1, paper: paperName, date: edition.shortDayLine)
                }
                if !edition.brief.isEmpty { briefs(edition) }
                closing(edition)
            }
        }
    }

    private func section(_ flag: String, _ items: [Edition.Item], front: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let lead = items.first {
                leadStory(lead, front: front)
            }
            let rest = Array(items.dropFirst())
            if !rest.isEmpty {
                Rectangle().fill(Paper.ink).frame(height: 1).padding(.top, 22)
                twoColumns(rest)
            }
        }
    }

    private func leadStory(_ item: Edition.Item, front: Bool) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            SectionFlag(text: item.flag).padding(.top, front ? 20 : 6)

            Text(item.headline)
                .font(Paper.head(front ? 36 : 28))
                .lineSpacing(-2)
                .tracking(-0.3)
                .foregroundStyle(Paper.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text(item.dek)
                .font(Paper.body(front ? 17 : 15).italic())
                .foregroundStyle(Paper.ink2)
                .fixedSize(horizontal: false, vertical: true)

            Rectangle().fill(Paper.rule).frame(height: 0.75).padding(.vertical, 2)

            picture(item.listing, tall: front)
            caption(item.listing)

            ForEach(Array(item.body.enumerated()), id: \.offset) { index, paragraph in
                NewsText(string: paragraph, size: 15, initialCap: index == 0 && front)
            }

            sourceLine(item.listing)
            actions(item.listing)

            if let market = item.market {
                MarketTable(market: market, subject: item.flag)
            }
        }
    }

    private func twoColumns(_ items: [Edition.Item]) -> some View {
        let half = (items.count + 1) / 2
        let left = Array(items.prefix(half))
        let right = Array(items.dropFirst(half))
        return HStack(alignment: .top, spacing: 22) {
            column(left)
            if !right.isEmpty {
                Rectangle().fill(Paper.rule).frame(width: 0.75)
                column(right)
            }
        }
        .padding(.top, 16)
    }

    private func column(_ items: [Edition.Item]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(items) { item in
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.headline)
                        .font(Paper.head(19))
                        .lineSpacing(-1)
                        .foregroundStyle(Paper.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    NewsText(string: item.dek, size: 13.5)
                    sourceLine(item.listing)
                    actions(item.listing)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func briefs(_ edition: Edition) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle().fill(Paper.ink).frame(height: 1).padding(.bottom, 8)
            SectionFlag(text: "In brief").padding(.bottom, 6)
            ForEach(edition.brief) { line in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(line.sourceName.uppercased())
                        .font(Paper.label(8.5))
                        .tracking(1)
                        .foregroundStyle(Paper.ink3)
                        .frame(width: 92, alignment: .leading)
                    Text(line.text)
                        .font(Paper.body(13.5))
                        .foregroundStyle(Paper.ink)
                    Spacer(minLength: 8)
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(line.amount)
                            .font(Paper.body(13.5))
                            .monospacedDigit()
                            .foregroundStyle(Paper.ink)
                        if let also = briefConversion(line) {
                            Text(also)
                                .font(Paper.label(8.5))
                                .tracking(0.4)
                                .monospacedDigit()
                                .foregroundStyle(Paper.ink3)
                        }
                    }
                }
                .padding(.vertical, 5)
                .overlay(alignment: .bottom) { Rectangle().fill(Paper.rule).frame(height: 0.5) }
                .contentShape(Rectangle())
                .onTapGesture { NSWorkspace.shared.open(line.url) }
            }
        }
        .padding(.top, 26)
    }

    /// The in-brief column shows what was asked, and beneath it what that is
    /// in the currency you think in.
    private func briefConversion(_ line: Edition.BriefLine) -> String? {
        guard let listing = store.listings[line.id] else { return nil }
        return Money.alsoInCompact(listing.price, listing.currency)
    }

    // MARK: pictures — always black and white, as they print

    @ViewBuilder
    private func picture(_ listing: Listing, tall: Bool) -> some View {
        Group {
            if let url = listing.imageURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    case .failure:
                        BoatMark()
                    default:
                        ZStack { Paper.ink.opacity(0.04); ProgressView().controlSize(.small) }
                    }
                }
            } else {
                BoatMark()
            }
        }
        .frame(height: tall ? 270 : 190)
        .frame(maxWidth: .infinity)
        .clipped()
        .grayscale(1)
        .contrast(1.06)
        .overlay(Rectangle().strokeBorder(Paper.ink.opacity(0.35), lineWidth: 0.75))
    }

    private func caption(_ listing: Listing) -> some View {
        Text(captionText(listing))
            .font(Paper.body(11.5).italic())
            .foregroundStyle(Paper.ink2)
            .padding(.top, -2)
    }

    private func captionText(_ listing: Listing) -> String {
        let where_ = listing.place.isEmpty ? "" : "\(listing.place). "
        return "\(where_)From the seller's photographs on \(listing.source)."
    }

    private func sourceLine(_ listing: Listing) -> some View {
        Text(sourceText(listing))
            .font(Paper.label(8.5, .semibold))
            .tracking(1)
            .textCase(.uppercase)
            .foregroundStyle(Paper.ink3)
            .monospacedDigit()
    }

    private func sourceText(_ listing: Listing) -> String {
        var parts: [String] = []
        if let also = Money.alsoIn(listing.price, listing.currency) { parts.append(also) }
        parts.append(listing.source)
        if listing.daysListed > 0 { parts.append("listed \(listing.daysListed) day\(listing.daysListed == 1 ? "" : "s") ago") }
        if !listing.place.isEmpty { parts.append(listing.place) }
        if let drop = listing.priceDrop { parts.append("down \(Money.format(drop, listing.currency))") }
        return parts.joined(separator: " · ")
    }

    /// Drag the story itself anywhere — Safari, Mail, the Desktop — and the
    /// listing goes with it.
    private func actions(_ listing: Listing) -> some View {
        HStack(spacing: 8) {
            Button("Open on \(listing.source)") { NSWorkspace.shared.open(listing.url) }
            Text("or drag this story out")
                .font(Paper.label(8.5))
                .tracking(0.8)
                .textCase(.uppercase)
                .foregroundStyle(Paper.ink3)
        }
        .controlSize(.small)
        .padding(.top, 2)
        .draggable(listing.url)
    }

    // MARK: a quiet morning

    private func quiet(_ edition: Edition) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(spacing: 10) {
                Text("No news today.")
                    .font(Paper.head(30, .regular))
                    .foregroundStyle(Paper.ink)
                Rectangle().fill(Paper.rule).frame(width: 56, height: 0.75)
                Text("\(edition.readLine). Nothing new against your \(store.wishes.count) wish\(store.wishes.count == 1 ? "" : "es").")
                    .font(Paper.body(14.5))
                    .foregroundStyle(Paper.ink2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 330)
                if let missed = edition.missedSources, !missed.isEmpty {
                    Text("Could not read: \(missed.joined(separator: ", ")).")
                        .font(Paper.body(12))
                        .foregroundStyle(Paper.ink3)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 330)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 58)

            closing(edition)
        }
    }

    @ViewBuilder
    private func closing(_ edition: Edition) -> some View {
        if !edition.stillOut.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                SectionFlag(text: "Still out there").padding(.bottom, 3)
                ForEach(Array(edition.stillOut.enumerated()), id: \.offset) { _, line in
                    Text(line).font(Paper.body(13).italic()).foregroundStyle(Paper.ink2)
                }
            }
            .padding(.top, 24)
        }
        if !edition.obituaries.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                SectionFlag(text: "Obituaries").padding(.bottom, 3)
                ForEach(Array(edition.obituaries.enumerated()), id: \.offset) { _, line in
                    Text(line).font(Paper.body(13).italic()).foregroundStyle(Paper.ink2)
                }
            }
            .padding(.top, 24)
        }
    }

    private func colophon(_ edition: Edition) -> some View {
        HStack {
            Text(edition.printedLine)
            Spacer()
            Text(nextLine)
        }
        .font(Paper.label(8.5, .semibold))
        .tracking(1)
        .textCase(.uppercase)
        .foregroundStyle(Paper.ink3)
        .padding(.top, 28)
        .overlay(alignment: .top) { Rectangle().fill(Paper.rule).frame(height: 0.75) }
    }

    private var nextLine: String {
        switch cadence {
        case .hourly:     return "Next edition within the hour"
        case .twiceDaily: return "Next edition in twelve hours"
        case .daily:      return "Next edition tomorrow"
        case .weekly:     return "Next edition in a week"
        case .monthly:    return "Next edition next month"
        case .manual:     return "Next edition when you ask"
        }
    }

    // MARK: nothing yet

    private var firstMorning: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle().fill(Paper.ink).frame(height: 0.75)
            Text("Wish Fisher — \(cadence.editionName)")
                .font(Paper.masthead(46))
                .foregroundStyle(Paper.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            DoubleRule()

            Text("No editions yet.")
                .font(Paper.head(26, .regular))
                .padding(.top, 46)
                .padding(.bottom, 10)

            Text("Make a wish in the first column — one sentence, in your own words. Wish Fisher reads the past straight away, then brings a paper each morning.")
                .font(Paper.body(15))
                .foregroundStyle(Paper.ink2)
                .frame(maxWidth: 430, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(Paper.ink)
    }
}

/// The running head that turns the page.
struct PageBreak: View {
    let number: Int
    let paper: String
    let date: String

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 34)
            Rectangle().fill(Paper.ink).frame(height: 2)
            HStack {
                Text("Page \(number)")
                Spacer()
                Text("\(paper) · \(date)")
            }
            .font(Paper.label(8.5))
            .tracking(1.2)
            .textCase(.uppercase)
            .foregroundStyle(Paper.ink2)
            .monospacedDigit()
            .padding(.vertical, 5)
            Rectangle().fill(Paper.ink).frame(height: 0.75)
            Spacer().frame(height: 6)
        }
    }
}
