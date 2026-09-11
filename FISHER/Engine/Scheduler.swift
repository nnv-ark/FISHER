import Foundation

/// Once a day, at night. No daemon, no server: the system runs this when it
/// suits, and if the Mac was asleep at four it happens at the next wake.
@MainActor
final class Scheduler {
    private var activity: NSBackgroundActivityScheduler?
    private weak var store: Store?

    init(store: Store) {
        self.store = store
    }

    func start() {
        schedule()
        catchUpIfNeeded()
    }

    func schedule() {
        activity?.invalidate()
        let frequency = Defaults.frequency
        guard frequency != .manual else { activity = nil; return }

        let scheduler = NSBackgroundActivityScheduler(identifier: "is.nnv.wishfisher.sweep")
        scheduler.repeats = true
        scheduler.interval = frequency.interval
        scheduler.tolerance = min(frequency.interval * 0.5, 3 * 3600)
        scheduler.qualityOfService = .background
        scheduler.schedule { [weak self] completion in
            Task { @MainActor in
                await self?.store?.sweep(reason: "scheduled")
                completion(.finished)
            }
        }
        activity = scheduler
    }

    /// The catch-up sweep. A missed night is a delay, never a gap.
    private func catchUpIfNeeded() {
        guard let store else { return }
        let frequency = Defaults.frequency
        guard frequency != .manual else { return }
        let last = store.lastSweep ?? store.editions.last?.printedAt
        let due = last.map { Date().timeIntervalSince($0) > frequency.interval } ?? true
        guard due, !store.wishes.isEmpty else { return }
        Task { await store.sweep(reason: "catch-up") }
    }
}
