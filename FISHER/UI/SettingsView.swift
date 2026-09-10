import SwiftUI
import ServiceManagement
import UserNotifications
import AppKit

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettings()
                .tabItem { Label("General", systemImage: "gearshape") }
            SourcesSettings()
                .tabItem { Label("Sources", systemImage: "antenna.radiowaves.left.and.right") }
            NotificationSettings()
                .tabItem { Label("Notifications", systemImage: "bell") }
            AdvancedSettings()
                .tabItem { Label("Advanced", systemImage: "wrench.and.screwdriver") }
        }
        .frame(width: 560)
    }
}

// MARK: - General

struct GeneralSettings: View {
    @EnvironmentObject var store: Store
    @AppStorage(PrefKey.frequency) private var frequency = Frequency.daily.rawValue
    @AppStorage(PrefKey.hour) private var hour = 4
    @AppStorage(PrefKey.searchThePast) private var searchThePast = true
    @AppStorage(PrefKey.launchAtLogin) private var launchAtLogin = false
    @AppStorage(PrefKey.pro) private var isPro = false
    @AppStorage(PrefKey.mastheadFont) private var mastheadFont = MastheadFace.pirata.rawValue
    @AppStorage(PrefKey.homeCurrency) private var homeCurrency = ""
    @State private var loginError: String?

    var body: some View {
        Form {
            Section {
                Picker("Check", selection: $frequency) {
                    ForEach(Frequency.allCases) { Text($0.title).tag($0.rawValue) }
                }
                Picker("At about", selection: $hour) {
                    ForEach(0..<24, id: \.self) { Text(clock($0)).tag($0) }
                }
                .disabled(frequency == Frequency.hourly.rawValue || frequency == Frequency.manual.rawValue)
            } footer: {
                Text("A used-boat hunt runs for months, so one reading a night is plenty and keeps FISHER's traffic indistinguishable from a person with a coffee. If the Mac is asleep at the appointed hour, the reading happens at the next wake — a delay, never a gap.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section {
                Toggle("Read the past when a wish is made", isOn: $searchThePast)
                Toggle("Keep FISHER running after login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, wants in setLogin(wants) }
                if let loginError {
                    Text(loginError).font(.system(size: 11)).foregroundStyle(.red)
                }
            } footer: {
                Text("Reading the past means a new wish comes back with what is already out there, within a minute, instead of an empty promise to watch.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section {
                Picker("Also show prices in", selection: $homeCurrency) {
                    Text("Don't convert — show as advertised").tag("")
                    Divider()
                    ForEach(Rates.known, id: \.self) { code in
                        Text("\(code)\(currencyName(code))").tag(code)
                    }
                }
            } header: {
                Text("Money")
            } footer: {
                Text(ratesFooter)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section("The flag") {
                Picker("Masthead", selection: $mastheadFont) {
                    ForEach(MastheadFace.allCases) { face in
                        Text(face.title).font(.custom(face.fontName, size: 15)).tag(face.rawValue)
                    }
                }
                .pickerStyle(.inline)
            }

            Section {
                Toggle("Wish Fisher Pro", isOn: $isPro)
            } header: {
                Text("Advertising")
            } footer: {
                Text("The free edition carries advertising on the front page, as a free paper does. Pro prints none — that is the only difference between them. (This switch stands in for the purchase until the store is wired up.)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section("Standing") {
                LabeledContent("Editions printed", value: "\(store.editions.count)")
                LabeledContent("Wishes", value: "\(store.wishes.count)")
                LabeledContent("Listings remembered", value: "\(store.listings.count)")
                LabeledContent("Last reading", value: store.lastSweep.map(relative) ?? "not yet")
            }
        }
        .formStyle(.grouped)
        .onChange(of: frequency) { _, _ in NotificationCenter.default.post(name: .fisherRescheduleNeeded, object: nil) }
    }

    private func currencyName(_ code: String) -> String {
        let name = Locale.current.localizedString(forCurrencyCode: code) ?? ""
        return name.isEmpty ? "" : " — \(name)"
    }

    private var ratesFooter: String {
        let base = "Prices are always shown exactly as the seller advertised them. The converted figure is printed beside it, marked with ≈, so it is never mistaken for the asking price. It also lets a Danish boat be compared with a Swedish one."
        guard let book = Rates.book else {
            return base + " No rates yet — they are fetched with the first reading."
        }
        return base + " Rates from the \(book.source), \(book.date), fetched \(book.age)."
    }

    private func clock(_ h: Int) -> String {
        let suffix = h < 12 ? "a.m." : "p.m."
        let display = h % 12 == 0 ? 12 : h % 12
        return "\(display):00 \(suffix)"
    }

    private func relative(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f.localizedString(for: date, relativeTo: Date())
    }

    private func setLogin(_ wants: Bool) {
        do {
            if wants { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            loginError = nil
        } catch {
            loginError = error.localizedDescription
            launchAtLogin = !wants
        }
    }
}

// MARK: - Sources

struct SourcesSettings: View {
    @EnvironmentObject var store: Store
    @State private var selection: Adapter.ID?
    @State private var probe: AdapterProbe?
    @State private var probing = false
    @State private var testQuery = ""

    private var selected: Adapter? { store.adapters.first { $0.id == selection } }

    var body: some View {
        HSplitView {
            List(selection: $selection) {
                ForEach($store.adapters) { $adapter in
                    HStack(spacing: 8) {
                        Toggle("", isOn: Binding(
                            get: { adapter.enabled },
                            set: { store.setAdapterEnabled(adapter.id, $0) }))
                            .labelsHidden()
                            .controlSize(.mini)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(adapter.name).font(.system(size: 12, weight: .medium))
                            Text(adapter.kind.title).font(.system(size: 10)).foregroundStyle(.secondary)
                        }
                    }
                    .tag(adapter.id)
                }
            }
            .frame(minWidth: 190, maxWidth: 230)

            detail
                .frame(minWidth: 320)
        }
        .frame(height: 430)
        .onChange(of: selection) { _, _ in probe = nil }
        .safeAreaInset(edge: .bottom) {
            HStack {
                Button("Restore bundled sources") { store.restoreBundledAdapters() }
                Spacer()
                Button("Reveal adapters.json") {
                    NSWorkspace.shared.activateFileViewerSelecting([Store.folder.appendingPathComponent("adapters.json")])
                }
            }
            .controlSize(.small)
            .padding(10)
        }
    }

    @ViewBuilder
    private var detail: some View {
        if let adapter = selected, let index = store.adapters.firstIndex(where: { $0.id == adapter.id }) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(adapter.name).font(.system(size: 15, weight: .semibold))
                    if let notes = adapter.notes {
                        Text(notes)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    field("Search URL", text: Binding(
                        get: { store.adapters[index].searchURL },
                        set: { store.adapters[index].searchURL = $0; store.markAdapterEdited(id: adapter.id) }))

                    Picker("Reads", selection: Binding(
                        get: { store.adapters[index].kind },
                        set: { store.adapters[index].kind = $0; store.markAdapterEdited(id: adapter.id) })) {
                            ForEach(Adapter.Kind.allCases) { Text($0.title).tag($0) }
                        }

                    if store.adapters[index].kind == .html {
                        field("Each listing (XPath)", text: Binding(
                            get: { store.adapters[index].listingPath ?? "" },
                            set: { store.adapters[index].listingPath = $0; store.markAdapterEdited(id: adapter.id) }))
                    }
                    if store.adapters[index].kind == .nextdata {
                        field("Listings array (key path)", text: Binding(
                            get: { store.adapters[index].collectionPath ?? "" },
                            set: { store.adapters[index].collectionPath = $0; store.markAdapterEdited(id: adapter.id) }))
                    }

                    ForEach(["title", "price", "place", "url", "image", "summary"], id: \.self) { key in
                        field(key.capitalized, text: Binding(
                            get: { store.adapters[index].fields[key] ?? "" },
                            set: { store.adapters[index].fields[key] = $0; store.markAdapterEdited(id: adapter.id) }))
                    }

                    Divider()

                    HStack(spacing: 8) {
                        TextField("Test with…", text: $testQuery)
                            .textFieldStyle(.roundedBorder)
                        Button(probing ? "Reading…" : "Test") { runProbe(adapter) }
                            .disabled(probing)
                    }
                    .controlSize(.small)

                    if let probe {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(probe.verdict)
                                .font(.system(size: 11.5, weight: .medium))
                                .foregroundStyle(probe.found > 0 ? Color.primary : Color.red)
                            if let status = probe.httpStatus {
                                Text("HTTP \(status) · \(probe.url?.absoluteString ?? "")")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                                    .textSelection(.enabled)
                            }
                            ForEach(probe.samples) { sample in
                                HStack(alignment: .top, spacing: 8) {
                                    if let image = sample.imageURL {
                                        AsyncImage(url: image) { $0.resizable().aspectRatio(contentMode: .fill) }
                                            placeholder: { Color.secondary.opacity(0.12) }
                                            .frame(width: 44, height: 34)
                                            .clipped()
                                    }
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(sample.title).font(.system(size: 11, weight: .medium)).lineLimit(1)
                                        Text("\(sample.priceText)\(sample.place.isEmpty ? "" : " · " + sample.place)")
                                            .font(.system(size: 10)).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        .padding(9)
                        .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 6))
                    }
                }
                .padding(14)
            }
        } else {
            VStack(spacing: 6) {
                Text("Pick a source").font(.system(size: 13, weight: .medium))
                Text("Sources are data, not code. When a site changes its markup you fix it here — or drop in a new adapters.json — without waiting for a new build of FISHER.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func field(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.7)
                .foregroundStyle(.secondary)
            TextField("", text: text)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 11, design: .monospaced))
        }
    }

    private func runProbe(_ adapter: Adapter) {
        probing = true
        Task {
            let result = await store.probe(adapter, query: testQuery)
            await MainActor.run {
                probe = result
                probing = false
            }
        }
    }
}

// MARK: - Notifications

struct NotificationSettings: View {
    @AppStorage(PrefKey.notify) private var notify = NotifyStyle.summary.rawValue
    @State private var status = "unknown"

    var body: some View {
        Form {
            Section {
                Picker("Tell me", selection: $notify) {
                    ForEach(NotifyStyle.allCases) { Text($0.title).tag($0.rawValue) }
                }
            } footer: {
                Text("FISHER speaks seldom, so when it does it talks about the thing rather than about itself: “Grinde 27 surfaces in Svendborg — €19,500”, not “3 new matches”. Marginal finds never interrupt; they wait in the small print of the next edition.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section("Permission") {
                LabeledContent("System setting", value: status)
                HStack {
                    Button("Ask again") { Notifier.requestPermission(); refresh() }
                    Button("Open System Settings") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
                .controlSize(.small)
            }
        }
        .formStyle(.grouped)
        .onAppear(perform: refresh)
    }

    private func refresh() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let text: String
            switch settings.authorizationStatus {
            case .authorized: text = "allowed"
            case .denied: text = "refused"
            case .notDetermined: text = "not asked yet"
            case .provisional: text = "quiet delivery"
            case .ephemeral: text = "temporary"
            @unknown default: text = "unknown"
            }
            DispatchQueue.main.async { status = text }
        }
    }
}

// MARK: - Advanced

struct AdvancedSettings: View {
    @EnvironmentObject var store: Store
    @AppStorage(PrefKey.userAgent) private var userAgent = Defaults.defaultUserAgent
    @AppStorage(PrefKey.keepIssues) private var keepIssues = 180
    @State private var confirmingReset = false

    var body: some View {
        Form {
            Section {
                TextField("User agent", text: $userAgent)
                    .font(.system(size: 11, design: .monospaced))
                Button("Reset to the honest default") { userAgent = Defaults.defaultUserAgent }
                    .controlSize(.small)
            } header: {
                Text("How FISHER introduces itself")
            } footer: {
                Text("The default says plainly what the app is and that it visits once a day. Some sites turn away anything that isn't a browser; if a source keeps coming back empty, that is usually why.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section("Archive") {
                Stepper("Keep \(keepIssues) back issues", value: $keepIssues, in: 30...3650, step: 30)
                Button("Reveal the Wish Fisher folder") {
                    NSWorkspace.shared.activateFileViewerSelecting([Store.folder])
                }
                .controlSize(.small)
            }

            Section {
                Button("Forget every listing and start the archive over", role: .destructive) {
                    confirmingReset = true
                }
                .controlSize(.small)
            } footer: {
                Text("Your wishes are kept, retired ones included. Only the remembered listings and the printed editions go.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .confirmationDialog("Start the archive over?", isPresented: $confirmingReset) {
            Button("Forget them", role: .destructive) {
                store.listings = [:]
                store.editions = []
                store.selectedIssue = nil
                store.save()
            }
            Button("Keep them", role: .cancel) { }
        } message: {
            Text("This cannot be undone.")
        }
    }
}

extension Notification.Name {
    static let fisherRescheduleNeeded = Notification.Name("fisher.reschedule")
}
