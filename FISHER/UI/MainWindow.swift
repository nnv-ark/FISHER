import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct MainWindow: View {
    @EnvironmentObject var store: Store
    @AppStorage("showWishes") private var showWishes = true
    @AppStorage("showRetired") private var showRetired = false
    @AppStorage("showIssues") private var showIssues = true
    @State private var dropTarget: UUID?

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 216, ideal: 244, max: 320)
        } detail: {
            EditionView(edition: store.currentEdition)
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Text(store.currentEdition.map { "No. \($0.id)" } ?? "Wish Fisher")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Paper.ink2)
            }
            ToolbarItem {
                Button {
                    Task { await store.sweep(reason: "manual") }
                } label: {
                    if store.isSweeping {
                        ProgressView().controlSize(.small)
                    } else {
                        Label("Check Now", systemImage: "arrow.clockwise")
                    }
                }
                .disabled(store.isSweeping || store.activeWishes.isEmpty)
                .help("Read every source now (⌘R)")
            }
        }
        .navigationTitle("")
    }

    private var sidebar: some View {
        List {
            Section("Make a wish") {
                WishField()
                    .listRowInsets(EdgeInsets(top: 6, leading: 4, bottom: 8, trailing: 4))
            }

            Section("Wishes", isExpanded: $showWishes) {
                if store.activeWishes.isEmpty {
                    Text("Nothing wished for yet.")
                        .font(.system(size: 11))
                        .foregroundStyle(Paper.ink3)
                }
                ForEach(store.activeWishes) { wish in
                    wishRow(wish, first: wish.id == store.activeWishes.first?.id)
                }
            }

            if !store.retiredWishes.isEmpty {
                Section("Put away", isExpanded: $showRetired) {
                    ForEach(store.retiredWishes) { wish in
                        VStack(alignment: .leading, spacing: 1) {
                            Text(wish.displayName)
                                .font(.system(size: 12.5))
                                .foregroundStyle(Paper.ink3)
                            Text(retiredLine(wish))
                                .font(.system(size: 10))
                                .foregroundStyle(Paper.ink3)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .contextMenu {
                            Button("Wish for this again") { store.reviveWish(wish) }
                            Divider()
                            Button("Forget it entirely", role: .destructive) { store.forgetWish(wish) }
                        }
                    }
                }
            }

            Section("Back issues", isExpanded: $showIssues) {
                if store.editions.isEmpty {
                    Text("No editions yet.")
                        .font(.system(size: 11))
                        .foregroundStyle(Paper.ink3)
                }
                ForEach(store.editions.reversed()) { edition in
                    Button {
                        store.selectedIssue = edition.id
                    } label: {
                        HStack {
                            Text("No. \(edition.id) · \(edition.shortDayLine)")
                                .font(.system(size: 12,
                                               weight: store.selectedIssue == edition.id ? .semibold : .regular))
                                .foregroundStyle(edition.isQuiet ? Paper.ink3 : Paper.ink)
                            Spacer()
                            Text(edition.isQuiet ? "—" : "\(edition.newCount)")
                                .font(.system(size: 10))
                                .monospacedDigit()
                                .foregroundStyle(Paper.ink3)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .listStyle(.sidebar)
        // Drop a line of text from anywhere and it becomes a wish.
        .dropDestination(for: String.self) { items, _ in
            guard let text = items.first?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !text.isEmpty, UUID(uuidString: text) == nil else { return false }
            store.addWish(WishParser.parse(text))
            if UserDefaults.standard.bool(forKey: PrefKey.searchThePast) {
                Task { await store.sweep(reason: "dropped wish") }
            }
            return true
        }
        .safeAreaInset(edge: .bottom) {
            if !store.sweepNote.isEmpty {
                Text(store.sweepNote)
                    .font(.system(size: 10))
                    .foregroundStyle(Paper.ink3)
                    .lineLimit(2)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.thinMaterial)
            }
        }
    }

    /// Wishes are dragged into order, and the one at the top owns the front page.
    private func wishRow(_ wish: WantedAd, first: Bool) -> some View {
        HStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 1) {
                Text(wish.displayName).font(.system(size: 12.5, weight: .medium))
                Text(subtitle(wish)).font(.system(size: 10)).foregroundStyle(Paper.ink3)
            }
            Spacer()
            if first {
                Text("front page")
                    .font(.system(size: 8.5, weight: .semibold))
                    .tracking(0.6)
                    .textCase(.uppercase)
                    .foregroundStyle(Paper.ink3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 1)
        .contentShape(Rectangle())
        .overlay(alignment: .top) {
            if dropTarget == wish.id {
                Rectangle().fill(Paper.ink).frame(height: 2)
            }
        }
        .draggable(wish.id.uuidString)
        .dropDestination(for: String.self) { items, _ in
            dropTarget = nil
            guard let dragged = items.first, let id = UUID(uuidString: dragged) else { return false }
            store.moveWish(id: id, before: wish.id)
            return true
        } isTargeted: { inside in
            dropTarget = inside ? wish.id : nil
        }
        .contextMenu {
            Button("Give it the front page") { store.moveWish(id: wish.id, before: store.wishes[0].id) }
            Divider()
            Button("Stop wishing for this") { store.retireWish(wish) }
            Button("Forget it entirely", role: .destructive) { store.forgetWish(wish) }
        }
    }

    private func subtitle(_ wish: WantedAd) -> String {
        var bits: [String] = []
        if let max = wish.maxPrice { bits.append("under \(Money.format(max, wish.currency ?? ""))") }
        if let place = wish.places.first { bits.append(place) }
        if bits.isEmpty {
            bits.append(Defaults.frequency.title)
        }
        return bits.joined(separator: " · ")
    }

    private func retiredLine(_ wish: WantedAd) -> String {
        let kept = store.listings.values.filter { $0.adID == wish.id }.count
        let f = DateFormatter(); f.dateFormat = "d MMM yyyy"
        return "wished \(f.string(from: wish.createdAt)) · \(kept) kept"
    }
}
