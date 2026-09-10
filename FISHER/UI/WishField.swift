import SwiftUI

/// The only way in. One sentence; no fields, not even hidden ones.
struct WishField: View {
    @EnvironmentObject var store: Store
    @State private var text = ""
    @State private var draft: WantedAd?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("I wish for…", text: $text)
                .textFieldStyle(.roundedBorder)
                .font(Paper.serif(13.5))
                .onSubmit(interpret)

            if let draft { interpretation(draft) }
        }
    }

    private func interpret() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        draft = WishParser.parse(trimmed)
    }

    private func interpretation(_ ad: WantedAd) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            row("Looking for", ad.terms.joined(separator: ", "))
            row("Ceiling", ad.maxPrice.map { Money.format($0, ad.currency ?? "") } ?? "none set")
            row("Where", ad.places.first ?? "Anywhere")
            if !ad.exclusions.isEmpty { row("Not", ad.exclusions.joined(separator: ", ")) }
            row("Sources", "\(store.adapters.filter(\.enabled).count) · \(Defaults.frequency.title.lowercased())")

            Button("Make the wish") {
                store.addWish(ad)
                draft = nil
                text = ""
                if UserDefaults.standard.bool(forKey: PrefKey.searchThePast) {
                    Task { await store.sweep(reason: "new wish") }
                }
            }
            .controlSize(.small)
            .padding(.top, 2)
        }
        .padding(9)
        .background(Paper.sheet)
        .overlay(Rectangle().fill(Paper.sea).frame(width: 2), alignment: .leading)
        .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Paper.rule, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 5))
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(Paper.ink3)
                .frame(width: 66, alignment: .leading)
            Text(value.isEmpty ? "—" : value)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Paper.ink)
        }
    }
}
