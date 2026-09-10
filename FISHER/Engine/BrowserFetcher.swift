import Foundation
import WebKit

/// Some sites cannot be read with an HTTP request at all. Boat24 refuses
/// anything that isn't a browser — its own home page answers 403 to curl — and
/// YachtBroker draws its listings with script after the page arrives, so the
/// HTML is empty. Both are ordinary in a browser.
///
/// So a source can ask to be read by one: an off-screen WKWebView loads the
/// page, lets the scripts run, and hands back the rendered DOM. Everything
/// downstream is unchanged — it is still just HTML going into SiteReader.
@MainActor
final class BrowserFetcher: NSObject, WKNavigationDelegate {
    static let shared = BrowserFetcher()

    private var web: WKWebView?
    private var pending: CheckedContinuation<String, Error>?
    private var settle: Double = 2.5
    private var busy = false

    enum Failure: LocalizedError {
        case busy, timedOut, navigation(String)
        var errorDescription: String? {
            switch self {
            case .busy: return "the browser is already reading a page"
            case .timedOut: return "the page did not finish loading"
            case .navigation(let why): return why
            }
        }
    }

    func html(for url: URL, userAgent: String, settle: Double = 2.5, timeout: Double = 30) async throws -> Data {
        guard !busy else { throw Failure.busy }
        busy = true
        defer { busy = false }

        self.settle = settle
        let view = makeWebView(userAgent: userAgent)
        web = view

        let text: String = try await withCheckedThrowingContinuation { continuation in
            pending = continuation
            view.load(URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: timeout))
            DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak self] in
                self?.finish(.failure(Failure.timedOut))
            }
        }
        web?.stopLoading()
        web = nil
        return Data(text.utf8)
    }

    private func makeWebView(userAgent: String) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()      // no cookies kept between sweeps
        config.suppressesIncrementalRendering = true
        let view = WKWebView(frame: CGRect(x: 0, y: 0, width: 1280, height: 1400), configuration: config)
        view.navigationDelegate = self
        // A browser has to say it is one, or the sites that check will refuse.
        view.customUserAgent = userAgent.hasPrefix("Mozilla")
            ? userAgent
            : "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15"
        return view
    }

    private func finish(_ result: Result<String, Error>) {
        guard let continuation = pending else { return }
        pending = nil
        continuation.resume(with: result)
    }

    // MARK: WKNavigationDelegate

    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in
            let wait = settle
            try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
            webView.evaluateJavaScript("document.documentElement.outerHTML") { [weak self] value, error in
                Task { @MainActor in
                    if let html = value as? String, !html.isEmpty {
                        self?.finish(.success(html))
                    } else {
                        self?.finish(.failure(Failure.navigation(error?.localizedDescription ?? "the page was empty")))
                    }
                }
            }
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in self.finish(.failure(Failure.navigation(error.localizedDescription))) }
    }

    nonisolated func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in self.finish(.failure(Failure.navigation(error.localizedDescription))) }
    }
}
