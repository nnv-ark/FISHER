import Foundation

enum PrefKey {
    static let frequency   = "frequency"
    static let notify      = "notifyStyle"
    static let userAgent   = "userAgent"
    static let keepIssues  = "keepIssues"
    static let launchAtLogin = "launchAtLogin"
    static let searchThePast = "searchThePast"
    static let pro = "proVersion"
    static let mastheadFont = "mastheadFont"
    static let homeCurrency = "homeCurrency"
}

enum Frequency: String, CaseIterable, Identifiable {
    case hourly, twiceDaily, daily, weekly, monthly, manual
    var id: String { rawValue }
    var title: String {
        switch self {
        case .hourly:     return "Every hour"
        case .twiceDaily: return "Twice a day"
        case .daily:      return "Once a day"
        case .weekly:     return "Once a week"
        case .monthly:    return "Once a month"
        case .manual:     return "Only when I ask"
        }
    }

    /// What it says on the masthead.
    var editionName: String {
        switch self {
        case .hourly:                 return "Hourly"
        case .twiceDaily, .daily:     return "Daily"
        case .weekly:                 return "Weekly"
        case .monthly:                return "Monthly"
        case .manual:                 return "Occasional"
        }
    }
    var interval: TimeInterval {
        switch self {
        case .hourly:     return 3_600
        case .twiceDaily: return 43_200
        case .daily:      return 86_400
        case .weekly:     return 604_800
        case .monthly:    return 2_592_000
        case .manual:     return .greatestFiniteMagnitude
        }
    }
}

/// Faces for the flag. All three travel with the app under the SIL Open Font
/// Licence, because macOS ships no blackletter at all.
enum MastheadFace: String, CaseIterable, Identifiable {
    case pirata, grenze, fraktur, bodoni
    var id: String { rawValue }

    /// The PostScript name, which is what Font.custom actually wants.
    var fontName: String {
        switch self {
        case .pirata:  return "PirataOne-Regular"
        case .grenze:  return "GrenzeGotisch-Regular"
        case .fraktur: return "UnifrakturMaguntia"
        case .bodoni:  return "Bodoni 72"
        }
    }
    var title: String {
        switch self {
        case .pirata:  return "Pirata One — English blackletter"
        case .grenze:  return "Grenze Gotisch — modern gothic"
        case .fraktur: return "UnifrakturMaguntia — German fraktur"
        case .bodoni:  return "Bodoni — no blackletter at all"
        }
    }
}

enum NotifyStyle: String, CaseIterable, Identifiable {
    case summary, everyItem, silent
    var id: String { rawValue }
    var title: String {
        switch self {
        case .summary:   return "One morning summary"
        case .everyItem: return "One for every item"
        case .silent:    return "Don't tell me, I'll look"
        }
    }
}

enum Defaults {
    static let defaultUserAgent = "FISHER/1.0 (personal wanted-ads reader; one visit a day)"

    static func register() {
        UserDefaults.standard.register(defaults: [
            PrefKey.frequency: Frequency.daily.rawValue,
            PrefKey.notify: NotifyStyle.summary.rawValue,
            PrefKey.userAgent: defaultUserAgent,
            PrefKey.keepIssues: 180,
            PrefKey.launchAtLogin: false,
            PrefKey.searchThePast: true,
            PrefKey.pro: false,
            PrefKey.mastheadFont: MastheadFace.pirata.rawValue,
            PrefKey.homeCurrency: Locale.current.currency?.identifier ?? ""
        ])
    }

    static var frequency: Frequency {
        Frequency(rawValue: UserDefaults.standard.string(forKey: PrefKey.frequency) ?? "") ?? .daily
    }
    static var notifyStyle: NotifyStyle {
        NotifyStyle(rawValue: UserDefaults.standard.string(forKey: PrefKey.notify) ?? "") ?? .summary
    }
    static var userAgent: String {
        let s = UserDefaults.standard.string(forKey: PrefKey.userAgent) ?? defaultUserAgent
        return s.isEmpty ? "FISHER/1.0" : s
    }
    /// The bought version carries no advertising.
    static var isPro: Bool { UserDefaults.standard.bool(forKey: PrefKey.pro) }
    /// Empty means prices are shown exactly as advertised and nothing else.
    static var homeCurrency: String {
        (UserDefaults.standard.string(forKey: PrefKey.homeCurrency) ?? "").uppercased()
    }
    static var mastheadFace: MastheadFace {
        MastheadFace(rawValue: UserDefaults.standard.string(forKey: PrefKey.mastheadFont) ?? "") ?? .pirata
    }
}
