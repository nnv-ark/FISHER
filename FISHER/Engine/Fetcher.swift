import Foundation

/// One request per host at a time, with a pause between them. At one sweep a
/// day this is ordinary human traffic; the throttle is there so a manual
/// "Check now" spree stays polite too.
actor Fetcher {
    static let shared = Fetcher()

    private var lastHit: [String: Date] = [:]
    private let session: URLSession

    init() {
        let c = URLSessionConfiguration.ephemeral
        c.timeoutIntervalForRequest = 25
        c.httpMaximumConnectionsPerHost = 1
        c.requestCachePolicy = .reloadRevalidatingCacheData
        session = URLSession(configuration: c)
    }

    struct Response {
        var data: Data
        var status: Int
        var finalURL: URL
    }

    func get(_ url: URL, throttle: Double, userAgent: String, headers: [String: String] = [:]) async throws -> Response {
        let host = url.host ?? url.absoluteString
        if let last = lastHit[host] {
            let wait = throttle - Date().timeIntervalSince(last)
            if wait > 0 { try await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000)) }
        }
        lastHit[host] = Date()

        var req = URLRequest(url: url)
        req.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        req.setValue("text/html,application/xhtml+xml,application/json;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        req.setValue("en,da;q=0.8,sv;q=0.7,nl;q=0.6,is;q=0.6", forHTTPHeaderField: "Accept-Language")
        // What a real browser sends on a top-level navigation. Sites that
        // sniff for scrapers look here before anything else; a plain
        // URLSession request otherwise stands out.
        req.setValue("document", forHTTPHeaderField: "Sec-Fetch-Dest")
        req.setValue("navigate", forHTTPHeaderField: "Sec-Fetch-Mode")
        req.setValue("?1", forHTTPHeaderField: "Sec-Fetch-User")
        req.setValue("none", forHTTPHeaderField: "Sec-Fetch-Site")
        req.setValue("1", forHTTPHeaderField: "Upgrade-Insecure-Requests")
        // The adapter's own headers win — presentation per source is data.
        for (name, value) in headers { req.setValue(value, forHTTPHeaderField: name) }

        let (data, response) = try await session.data(for: req)
        let http = response as? HTTPURLResponse
        return Response(data: data,
                        status: http?.statusCode ?? 0,
                        finalURL: http?.url ?? url)
    }
}
