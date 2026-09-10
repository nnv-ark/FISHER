import Foundation

/// One pass over the world. At a sweep a day this is the whole engine:
/// read every enabled source for every wish, fold the results into what we
/// already know, and set today's paper.
extension Store {

    func sweep(reason: String) async {
        guard !isSweeping else { return }
        isSweeping = true
        sweepNote = "Reading \(adapters.filter(\.enabled).count) sources…"
        defer { isSweeping = false; sweepNote = "" }

        let activeWishes = wishes.filter(\.isActive)
        let activeAdapters = adapters.filter(\.enabled)
        guard !activeWishes.isEmpty, !activeAdapters.isEmpty else {
            sweepNote = activeWishes.isEmpty ? "No wishes yet." : "No sources enabled."
            return
        }

        let userAgent = Defaults.userAgent
        sweepNote = "Checking exchange rates…"
        await Rates.refreshIfStale(userAgent: userAgent)
        var seenThisPass = Set<String>()
        var fresh: [Listing] = []
        var sourcesRead = 0
        var missed: [String] = []

        for adapter in activeAdapters {
            var readAnything = false
            var attempts = 0
            var failures = 0
            for wish in activeWishes where adapter.carries(wish) {
                for query in wish.queries(language: adapter.lang) {
                for page in 1...(adapter.isFixedPage ? 1 : adapter.pageCount) {
                guard let url = adapter.url(for: query, page: page) else { continue }
                sweepNote = "Reading \(adapter.name) for \(wish.displayName)…"
                do {
                    attempts += 1
                    let data: Data
                    if adapter.needsBrowser {
                        data = try await BrowserFetcher.shared.html(for: url, userAgent: userAgent)
                    } else {
                        let response = try await Fetcher.shared.get(url, throttle: adapter.throttle, userAgent: userAgent)
                        guard (200..<300).contains(response.status) else { failures += 1; continue }
                        data = response.data
                    }
                    let found = SiteReader.read(data: data, adapter: adapter, ad: wish, pageURL: url)
                    if found.isEmpty { break }
                    readAnything = true

                    for var listing in found {
                        listing.score = Matcher.score(listing, against: wish)
                        // A boat vertical only carries boats, so anything from
                        // one is the thing; elsewhere the ad has to say so.
                        listing.likelyTheThing = (adapter.concepts?.isEmpty == false)
                            || Matcher.namesCategory(listing, wish)
                        guard listing.score > 0 else { continue }
                        guard !seenThisPass.contains(listing.dedupKey) else { continue }
                        seenThisPass.insert(listing.dedupKey)

                        if var known = listings[listing.id] {
                            let priceMoved = known.price != listing.price
                            known.lastSeen = Date()
                            known.lastMissing = nil
                            known.isGone = false
                            known.score = listing.score
                            known.title = listing.title
                            known.imageURL = listing.imageURL ?? known.imageURL
                            known.likelyTheThing = known.likelyTheThing ?? false || (listing.likelyTheThing ?? false)
                            if priceMoved, let p = listing.price {
                                known.price = p
                                known.priceHistory.append(PricePoint(date: Date(), price: p))
                                fresh.append(known)          // a price drop is news
                            }
                            listings[known.id] = known
                        } else {
                            listings[listing.id] = listing
                            fresh.append(listing)            // genuinely new
                        }
                    }
                } catch {
                    failures += 1
                    continue
                }
                }
                if adapter.isFixedPage { break }
                }
            }
            // Asked, and every answer was an error — say so in the paper.
            // A source that answered but listed nothing is a quiet market,
            // not a failure.
            if readAnything { sourcesRead += 1 }
            else if attempts > 0, failures == attempts { missed.append(adapter.name) }
        }

        // Anything we knew about and did not see today is on its way out.
        var gone: [Listing] = []
        for (key, var listing) in listings where !listing.isGone {
            let sawToday = seenThisPass.contains(listing.dedupKey) || Calendar.current.isDateInToday(listing.lastSeen)
            if sawToday { continue }
            if listing.lastMissing == nil {
                listing.lastMissing = Date()
            } else if Date().timeIntervalSince(listing.lastMissing!) > 86_400 * 2 {
                listing.isGone = true
                gone.append(listing)
            }
            listings[key] = listing
        }

        let stillOut = listings.values
            .filter { !$0.isGone && $0.daysListed > 7 && $0.score >= 0.5 }
            .sorted { $0.daysListed > $1.daysListed }

        let history = Array(listings.values)
        let issueNumber = (editions.last?.id ?? 0) + 1
        var names: [UUID: String] = [:]
        for wish in wishes { names[wish.id] = wish.displayName }
        let edition = Editor.compose(issueNumber: issueNumber,
                                     fresh: fresh,
                                     history: history,
                                     gone: gone,
                                     stillOut: Array(stillOut),
                                     sourcesRead: sourcesRead,
                                     missedSources: missed,
                                     adName: { id in id.flatMap { names[$0] } ?? "Wanted" })

        editions.append(edition)
        selectedIssue = edition.id
        lastSweep = Date()
        for index in wishes.indices { wishes[index].lastSweep = Date() }
        save()
        Notifier.announce(edition)
    }

    /// Settings ▸ Sources ▸ Test. Points one adapter at one live page and
    /// reports exactly what came back, which is the only honest way to keep
    /// selectors alive.
    func probe(_ adapter: Adapter, query: String) async -> AdapterProbe {
        let url = adapter.url(for: query.isEmpty ? (wishes.first?.query(language: adapter.lang) ?? "boat") : query)
        guard let url else {
            return AdapterProbe(adapter: adapter, url: nil, httpStatus: nil, found: 0, withImages: 0, samples: [], error: "The search URL is not valid.")
        }
        do {
            let data: Data
            let status: Int
            if adapter.needsBrowser {
                data = try await BrowserFetcher.shared.html(for: url, userAgent: Defaults.userAgent)
                status = 200
            } else {
                let response = try await Fetcher.shared.get(url, throttle: 0, userAgent: Defaults.userAgent)
                data = response.data
                status = response.status
            }
            let found = SiteReader.read(data: data, adapter: adapter, ad: nil, pageURL: url)
            return AdapterProbe(adapter: adapter,
                                url: url,
                                httpStatus: status,
                                found: found.count,
                                withImages: found.filter { $0.imageURL != nil }.count,
                                samples: Array(found.prefix(3)),
                                error: nil)
        } catch {
            return AdapterProbe(adapter: adapter, url: url, httpStatus: nil, found: 0, withImages: 0, samples: [], error: error.localizedDescription)
        }
    }
}
