import SwiftUI
import AppKit

@main
struct FISHERApp: App {
    @StateObject private var store = Store()
    @State private var scheduler: Scheduler?

    init() {
        BundledFonts.register()
        // A daily paper must survive between readings: without this, macOS
        // auto-terminates the app once it sits idle and occluded (observed as
        // a clean "Termination complete" ~40 s after a background launch),
        // and the next morning's edition never prints.
        ProcessInfo.processInfo.disableAutomaticTermination("daily sweep scheduled")
    }

    var body: some Scene {
        Window("Wish Fisher", id: "paper") {
            MainWindow()
                .environmentObject(store)
                .preferredColorScheme(.light)
                .frame(minWidth: 860, minHeight: 620)
                .onAppear {
                    Notifier.requestPermission()
                    Task { await store.refreshRegistry() }
                    let s = Scheduler(store: store)
                    s.start()
                    scheduler = s
                }
                .onReceive(NotificationCenter.default.publisher(for: .fisherRescheduleNeeded)) { _ in
                    scheduler?.schedule()
                }
        }
        .defaultSize(width: 1040, height: 760)
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandMenu("Edition") {
                Button("Check Now") {
                    Task { await store.sweep(reason: "menu") }
                }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(store.isSweeping || store.wishes.isEmpty)

                Divider()

                Button("Print Edition…") {
                    NSApp.sendAction(Selector(("print:")), to: nil, from: nil)
                }
                .keyboardShortcut("p", modifiers: .command)

                Button("Reveal Archive in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([Store.folder])
                }
            }
        }

        Settings {
            SettingsView()
                .environmentObject(store)
                .preferredColorScheme(.light)
        }
    }
}
