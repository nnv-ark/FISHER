import Foundation

/// Turns a fetched page into listings, following whatever the adapter says.
/// Three shapes cover nearly everything: server-rendered HTML, schema.org
/// JSON-LD, and the JSON blob a Next.js site ships with the page.
enum SiteReader {

    static func read(data: Data, adapter: Adapter, ad: WantedAd?, pageURL: URL) -> [Listing] {
        switch adapter.kind {
        case .html:     return readHTML(data: data, adapter: adapter, ad: ad, pageURL: pageURL)
        case .jsonld:   return readJSONLD(data: data, adapter: adapter, ad: ad, pageURL: pageURL)
        case .nextdata: return readNextData(data: data, adapter: adapter, ad: ad, pageURL: pageURL)
        }
    }


    // MARK: parsing HTML that was written this decade

    /// macOS's built-in HTML parser is an HTML 4 tidy. It does not know
    /// <article>, <section>, <main> and the rest, and rather than keeping them
    /// it throws the elements away — taking their classes and data attributes
    /// with them. Nearly every classifieds site wraps its listings in one.
    ///
    /// So we hand it HTML it understands: the modern block elements become
    /// <div> and the inline ones <span>, each keeping every attribute it had
    /// plus a data-el recording what it used to be. Parsing from a decoded
    /// string rather than raw bytes also stops it guessing the encoding wrong
    /// and turning "hyndesæt" into "hyndesÃ¦t".
    private static let blockTags = ["article", "section", "nav", "aside", "header",
                                    "footer", "main", "figure", "figcaption", "details",
                                    "summary", "dialog", "hgroup", "picture"]
    private static let inlineTags = ["time", "mark", "output", "meter", "progress"]

    static func document(from data: Data) -> XMLDocument? {
        var html = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .isoLatin1)
            ?? ""
        guard !html.isEmpty else { return nil }

        for (tags, replacement) in [(blockTags, "div"), (inlineTags, "span")] {
            for tag in tags {
                html = html.replacingOccurrences(
                    of: "<\(tag)(\\s|>)",
                    with: "<\(replacement) data-el=\"\(tag)\"$1",
                    options: [.regularExpression, .caseInsensitive])
                html = html.replacingOccurrences(
                    of: "</\(tag)\\s*>",
                    with: "</\(replacement)>",
                    options: [.regularExpression, .caseInsensitive])
            }
        }
        return try? XMLDocument(xmlString: html, options: [.documentTidyHTML, .nodePreserveCDATA])
    }

    // MARK: HTML / XPath

    private static func readHTML(data: Data, adapter: Adapter, ad: WantedAd?, pageURL: URL) -> [Listing] {
        guard let listingPath = adapter.listingPath,
              let doc = document(from: data),
              let nodes = try? doc.nodes(forXPath: listingPath) else { return [] }

        return nodes.compactMap { node -> Listing? in
            func field(_ key: String) -> String? {
                guard let path = adapter.fields[key],
                      let hits = try? node.nodes(forXPath: path) else { return nil }
                let text = hits.compactMap { $0.stringValue }
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .first { !$0.isEmpty }
                return text
            }
            guard let title = field("title"), !title.isEmpty else { return nil }
            let href = field("url") ?? ""
            guard let url = absolute(href, adapter: adapter, pageURL: pageURL) else { return nil }
            let (price, currency) = PriceParser.parse(field("price"), fallbackCurrency: adapter.defaultCurrency)
            return make(title: title,
                        summary: field("summary") ?? "",
                        price: price, currency: currency,
                        place: field("place") ?? "",
                        url: url,
                        image: absolute(field("image"), adapter: adapter, pageURL: pageURL),
                        adapter: adapter, ad: ad)
        }
    }

    // MARK: JSON-LD

    private static func readJSONLD(data: Data, adapter: Adapter, ad: WantedAd?, pageURL: URL) -> [Listing] {
        guard let doc = document(from: data),
              let scripts = try? doc.nodes(forXPath: "//script[@type='application/ld+json']") else { return [] }

        var out: [Listing] = []
        for script in scripts {
            guard let text = script.stringValue?.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: text) else { continue }
            for product in products(in: json) {
                guard let title = product["name"] as? String, !title.isEmpty else { continue }
                let href = (product["url"] as? String) ?? pageURL.absoluteString
                guard let url = absolute(href, adapter: adapter, pageURL: pageURL) else { continue }

                var priceText: String?
                if let offers = product["offers"] {
                    priceText = JSONWalker.string("price", in: offers) ?? JSONWalker.string("*.price", in: offers)
                }
                let currencyCode = (product["offers"].flatMap { JSONWalker.string("priceCurrency", in: $0) })
                    ?? adapter.defaultCurrency
                let (price, currency) = PriceParser.parse(priceText, fallbackCurrency: currencyCode)

                var summary = (product["description"] as? String) ?? ""
                if let brand = JSONWalker.string("brand.name", in: product), !summary.contains(brand) {
                    summary += " " + brand      // "Grinde Segelbåt/Motorseglare"
                }
                out.append(make(title: title,
                                summary: summary,
                                price: price, currency: currency,
                                place: JSONWalker.string("offers.availableAtOrFrom.address.addressLocality", in: product) ?? "",
                                url: url,
                                image: absolute(JSONWalker.string("image", in: product), adapter: adapter, pageURL: pageURL),
                                adapter: adapter, ad: ad))
            }
        }
        return out
    }

    private static func products(in json: Any) -> [[String: Any]] {
        var found: [[String: Any]] = []
        func walk(_ node: Any) {
            if let array = node as? [Any] { array.forEach(walk); return }
            guard let dict = node as? [String: Any] else { return }
            let type = (dict["@type"] as? String) ?? (dict["@type"] as? [String])?.first ?? ""
            if ["Product", "Vehicle", "Offer", "IndividualProduct", "Boat", "Car"].contains(type),
               dict["name"] is String {
                found.append(dict)
            }
            dict.values.forEach(walk)
        }
        walk(json)
        return found
    }

    // MARK: __NEXT_DATA__ and friends

    private static func readNextData(data: Data, adapter: Adapter, ad: WantedAd?, pageURL: URL) -> [Listing] {
        guard let collectionPath = adapter.collectionPath, let doc = document(from: data) else { return [] }
        var candidates = (try? doc.nodes(forXPath: "//script[@id='__NEXT_DATA__']")) ?? []
        candidates += (try? doc.nodes(forXPath: "//script[@type='application/json']")) ?? []

        var rows: [Any] = []
        for script in candidates {
            guard let text = script.stringValue?.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: text) else { continue }
            let found = JSONWalker.values(collectionPath, in: json)
            if !found.isEmpty { rows = found; break }
        }
        guard !rows.isEmpty else { return [] }

        return rows.compactMap { node -> Listing? in
            func field(_ key: String) -> String? {
                guard let path = adapter.fields[key] else { return nil }
                return JSONWalker.string(path, in: node)
            }
            guard let title = field("title"), !title.isEmpty else { return nil }
            guard let url = absolute(field("url"), adapter: adapter, pageURL: pageURL) else { return nil }
            let (price, currency) = PriceParser.parse(field("price"), fallbackCurrency: adapter.defaultCurrency)
            return make(title: title,
                        summary: field("summary") ?? "",
                        price: price, currency: currency,
                        place: field("place") ?? "",
                        url: url,
                        image: absolute(field("image"), adapter: adapter, pageURL: pageURL),
                        adapter: adapter, ad: ad)
        }
    }

    // MARK: helpers

    private static func make(title: String, summary: String, price: Double?, currency: String,
                             place: String, url: URL, image: URL?, adapter: Adapter, ad: WantedAd?) -> Listing {
        let key = "\(adapter.id)#\(url.absoluteString)"
        var listing = Listing(id: key,
                              adID: ad?.id,
                              title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                              summary: summary.trimmingCharacters(in: .whitespacesAndNewlines),
                              price: price,
                              currency: currency,
                              place: tidyPlace(place),
                              url: url,
                              imageURL: image,
                              source: adapter.name)
        if let p = price {
            let scaled = p / adapter.divisor
            listing.price = scaled
            listing.priceHistory = [PricePoint(date: Date(), price: scaled)]
        }
        return listing
    }

    /// Sites often give a whole breadcrumb — "Germany » Islas Canarias »
    /// Santa Cruz". The town is the useful end of it.
    private static func tidyPlace(_ raw: String) -> String {
        let parts = raw.components(separatedBy: CharacterSet(charactersIn: "»›>|"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let last = parts.last ?? raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return last.replacingOccurrences(of: "/ ", with: "/")
    }

    private static func absolute(_ raw: String?, adapter: Adapter, pageURL: URL) -> URL? {
        guard var s = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { return nil }
        if s.hasPrefix("//") { s = "https:" + s }
        if let u = URL(string: s), u.scheme != nil { return u }
        if let base = adapter.baseURL.flatMap({ URL(string: $0) }) { return URL(string: s, relativeTo: base)?.absoluteURL }
        return URL(string: s, relativeTo: pageURL)?.absoluteURL
    }
}
