import SwiftUI

/// A safe place to work on an adapter. The draft lives only in this tab —
/// nothing is saved, nothing joins a sweep — until you choose to send it to
/// Sources. Start from a blank template or from any existing source, edit
/// the JSON, run it against a live page, iterate.
struct SandboxSettings: View {
    @EnvironmentObject var store: Store
    @State private var draft: String = ""
    @State private var base: String?            // adapter id to start from; nil = template
    @State private var query = ""
    @State private var probe: AdapterProbe?
    @State private var running = false
    @State private var pendingInstall: Adapter?
    @State private var note: String?

    private let template = """
    {
      "id": "my-source",
      "name": "My source",
      "kind": "html",
      "searchURL": "https://example.com/search?q={terms}&page={page}",
      "listingPath": "//article[contains(@class,'listing')]",
      "fields": {
        "title": ".//h2",
        "price": ".//span[contains(@class,'price')]",
        "url": ".//a/@href",
        "image": ".//img/@src"
      },
      "language": "en"
    }
    """

    /// What the current text decodes to, if anything. The Run and
    /// Add-to-Sources buttons key off this — a half-written draft simply
    /// doesn't run.
    private var parsedAdapter: Adapter? {
        guard let data = draft.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(Adapter.self, from: data)
    }

    private var parseProblem: String? {
        guard !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              parsedAdapter == nil else { return nil }
        return "Not a complete adapter yet — an id, a name, a kind and a searchURL are required."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Picker("Start from", selection: $base) {
                    Text("Blank template").tag(nil as String?)
                    Divider()
                    ForEach(store.adapters) { adapter in
                        Text(adapter.name).tag(adapter.id as String?)
                    }
                }
                Button("Load") { loadBase() }
                Spacer()
                Button("Add to Sources…") {
                    if let adapter = parsedAdapter { pendingInstall = adapter }
                }
                .disabled(parsedAdapter == nil)
            }
            .controlSize(.small)

            TextEditor(text: $draft)
                .font(.system(size: 11, design: .monospaced))
                .scrollContentBackground(.hidden)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.25)))

            if let parseProblem {
                Text(parseProblem)
                    .font(.system(size: 10))
                    .foregroundStyle(.red)
            } else if let adapter = parsedAdapter {
                Text("Reads as \(adapter.name) · \(adapter.kind.title)")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                TextField("Test with…", text: $query)
                    .textFieldStyle(.roundedBorder)
                Button(running ? "Reading…" : "Run") { run() }
                    .disabled(running || parsedAdapter == nil)
                if let note {
                    Text(note)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .controlSize(.small)

            Divider()

            results
        }
        .padding(14)
        .frame(width: 640, height: 660)
        .confirmationDialog(
            "Add to Sources?",
            isPresented: Binding(
                get: { pendingInstall != nil },
                set: { if !$0 { pendingInstall = nil } })
        ) {
            Button("Add") { install() }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let adapter = pendingInstall {
                Text(store.adapters.contains(where: { $0.id == adapter.id })
                     ? "“\(adapter.name)” replaces the source with the same id in Settings ▸ Sources."
                     : "“\(adapter.name)” appears in Settings ▸ Sources, shielded from bundled and registry updates.")
            }
        }
    }

    // MARK: results

    @ViewBuilder
    private var results: some View {
        if let probe {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(probe.verdict)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(probe.found > 0 ? Color.primary : Color.red)
                    if let status = probe.httpStatus {
                        Text("HTTP \(status)")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(probe.found) read · \(probe.withImages) with a picture")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                if let url = probe.url {
                    Text(url.absoluteString)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(probe.samples) { sample in
                            HStack(alignment: .top, spacing: 8) {
                                if let image = sample.imageURL {
                                    AsyncImage(url: image) { $0.resizable().aspectRatio(contentMode: .fill) }
                                        placeholder: { Color.secondary.opacity(0.12) }
                                        .frame(width: 52, height: 40)
                                        .clipped()
                                        .cornerRadius(3)
                                }
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(sample.title).font(.system(size: 11.5, weight: .medium)).lineLimit(2)
                                    Text("\(sample.priceText)\(sample.place.isEmpty ? "" : " · " + sample.place)")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        } else {
            VStack(spacing: 4) {
                Text("Nothing runs yet")
                    .font(.system(size: 12, weight: .medium))
                Text("Load a starting point, shape the JSON, press Run. The draft stays here — Sources only hears about it when you say so.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: actions

    private func loadBase() {
        note = nil
        probe = nil
        guard let base,
              let adapter = store.adapters.first(where: { $0.id == base }) else {
            draft = template
            return
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        draft = (try? encoder.encode(adapter)).flatMap { String(data: $0, encoding: .utf8) } ?? ""
    }

    private func run() {
        guard let adapter = parsedAdapter else { return }
        running = true
        note = nil
        let q = query
        Task {
            let result = await store.probe(adapter, query: q, sampleCount: 8)
            await MainActor.run {
                probe = result
                running = false
            }
        }
    }

    private func install() {
        guard let adapter = pendingInstall else { return }
        store.installAdapterFromSandbox(adapter)
        pendingInstall = nil
        note = "“\(adapter.name)” is in Sources now."
    }
}
