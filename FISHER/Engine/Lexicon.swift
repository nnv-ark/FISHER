import Foundation

/// What a thing is called in the languages the classifieds are written in.
///
/// A wish has two kinds of word in it. "Grinde" is a name — it is the same in
/// every country and must never be translated or dropped. "sailboat" is a
/// category — it is "sejlbåd" in Denmark and "segelbåt" in Sweden, and sending
/// the English word to a Danish site finds nothing.
///
/// So names are what we search with, categories are what we recognise by, and
/// the wish may be written in any of these languages.
enum Lexicon {

    static let concepts: [String: [String: [String]]] = [
        "sailboat": [
            "en": ["sailboat", "sailing boat", "sail boat", "sailing yacht", "sloop"],
            "da": ["sejlbåd", "sejlbåde", "sejlskib"],
            "sv": ["segelbåt", "segelbåtar"],
            "no": ["seilbåt", "seilbåter"],
            "nl": ["zeilboot", "zeilboten", "zeiljacht"],
            "de": ["Segelboot", "Segelyacht", "Segelschiff"],
            "is": ["seglbátur", "seglbát", "seglbáti", "seglbáts", "seglskúta", "skúta"],
            "fr": ["voilier"], "it": ["barca a vela"], "es": ["velero"], "fi": ["purjevene"]
        ],
        "boat": [
            "en": ["boat", "yacht"], "da": ["båd", "både"], "sv": ["båt", "båtar"],
            "no": ["båt", "båter"], "nl": ["boot", "boten"], "de": ["Boot", "Yacht"],
            "is": ["bátur", "skip"], "fr": ["bateau"], "it": ["barca"], "es": ["barco"], "fi": ["vene"]
        ],
        "motorboat": [
            "en": ["motorboat", "motor boat"], "da": ["motorbåd"], "sv": ["motorbåt"],
            "no": ["motorbåt"], "nl": ["motorboot"], "de": ["Motorboot"],
            "is": ["vélbátur"], "fr": ["bateau à moteur"], "fi": ["moottorivene"]
        ],
        "dinghy": [
            "en": ["dinghy", "tender"], "da": ["jolle", "gummibåd"], "sv": ["jolle"],
            "no": ["jolle"], "nl": ["sloep", "bijboot"], "de": ["Jolle", "Beiboot"],
            "is": ["skekta", "léttbátur"]
        ],
        "sail": [
            "en": ["sail", "sails", "mainsail", "genoa", "jib"],
            "da": ["sejl", "storsejl", "forsejl"], "sv": ["segel", "storsegel"],
            "no": ["seil", "storseil"], "nl": ["zeil", "grootzeil", "fok"],
            "de": ["Segel", "Großsegel", "Fock"], "is": ["segl", "stórsegl"]
        ],
        "engine": [
            "en": ["engine", "outboard", "inboard"], "da": ["motor", "påhængsmotor"],
            "sv": ["motor", "utombordare"], "no": ["motor", "påhengsmotor"],
            "nl": ["motor", "buitenboordmotor"], "de": ["Motor", "Außenborder"],
            "is": ["vél", "utanborðsmótor"], "fr": ["moteur"], "fi": ["moottori"]
        ],
        "trailer": [
            "en": ["trailer"], "da": ["trailer", "bådtrailer"], "sv": ["släpvagn", "båttrailer"],
            "no": ["tilhenger", "båthenger"], "nl": ["aanhanger", "boottrailer"],
            "de": ["Anhänger", "Bootstrailer"], "is": ["kerra", "vagn"]
        ],
        "bicycle": [
            "en": ["bicycle", "bike", "pushbike"], "da": ["cykel"], "sv": ["cykel"],
            "no": ["sykkel"], "nl": ["fiets"], "de": ["Fahrrad", "Rad"],
            "is": ["reiðhjól", "hjól"], "fr": ["vélo", "bicyclette"], "es": ["bicicleta"], "fi": ["polkupyörä"]
        ],
        "car": [
            "en": ["car"], "da": ["bil"], "sv": ["bil"], "no": ["bil"], "nl": ["auto"],
            "de": ["Auto", "Wagen"], "is": ["bíll", "bifreið"], "fr": ["voiture"],
            "it": ["auto"], "es": ["coche"], "fi": ["auto"]
        ],
        "camera": [
            "en": ["camera"], "da": ["kamera"], "sv": ["kamera"], "no": ["kamera"],
            "nl": ["camera", "fototoestel"], "de": ["Kamera", "Fotoapparat"],
            "is": ["myndavél"], "fr": ["appareil photo"], "es": ["cámara"], "fi": ["kamera"]
        ],
        "lens": [
            "en": ["lens", "objective"], "da": ["objektiv"], "sv": ["objektiv"],
            "no": ["objektiv"], "nl": ["objectief", "lens"], "de": ["Objektiv"],
            "is": ["linsa", "aðdráttarlinsa"]
        ],
        "guitar": [
            "en": ["guitar"], "da": ["guitar"], "sv": ["gitarr"], "no": ["gitar"],
            "nl": ["gitaar"], "de": ["Gitarre"], "is": ["gítar"], "fr": ["guitare"], "es": ["guitarra"]
        ],
        "amplifier": [
            "en": ["amplifier", "amp"], "da": ["forstærker"], "sv": ["förstärkare"],
            "no": ["forsterker"], "nl": ["versterker"], "de": ["Verstärker"],
            "is": ["magnari"], "fr": ["amplificateur"]
        ],
        "speaker": [
            "en": ["speaker", "speakers", "loudspeaker"], "da": ["højttaler"],
            "sv": ["högtalare"], "no": ["høyttaler"], "nl": ["luidspreker"],
            "de": ["Lautsprecher"], "is": ["hátalari"]
        ],
        "synthesizer": [
            "en": ["synthesizer", "synth", "keyboard"], "da": ["synthesizer", "keyboard"],
            "sv": ["synt", "synthesizer"], "no": ["synth"], "nl": ["synthesizer"],
            "de": ["Synthesizer"], "is": ["hljóðgervill"]
        ],
        "piano": [
            "en": ["piano", "upright piano", "grand piano"], "da": ["klaver", "flygel"],
            "sv": ["piano", "flygel"], "no": ["piano", "flygel"], "nl": ["piano", "vleugel"],
            "de": ["Klavier", "Flügel"], "is": ["píanó", "flygill"]
        ],
        "turntable": [
            "en": ["turntable", "record player"], "da": ["pladespiller"],
            "sv": ["skivspelare"], "no": ["platespiller"], "nl": ["platenspeler"],
            "de": ["Plattenspieler"], "is": ["plötuspilari"]
        ],
        "watch": [
            "en": ["watch", "wristwatch"], "da": ["ur", "armbåndsur"], "sv": ["klocka", "armbandsur"],
            "no": ["klokke"], "nl": ["horloge"], "de": ["Uhr", "Armbanduhr"],
            "is": ["úr", "armbandsúr"], "fr": ["montre"], "es": ["reloj"]
        ],
        "computer": [
            "en": ["computer", "laptop", "macbook", "notebook"], "da": ["computer", "bærbar"],
            "sv": ["dator", "bärbar"], "no": ["datamaskin", "bærbar"], "nl": ["laptop", "computer"],
            "de": ["Computer", "Notebook"], "is": ["tölva", "fartölva"]
        ],
        "tent": [
            "en": ["tent"], "da": ["telt"], "sv": ["tält"], "no": ["telt"],
            "nl": ["tent"], "de": ["Zelt"], "is": ["tjald"]
        ],
        "kayak": [
            "en": ["kayak", "canoe"], "da": ["kajak", "kano"], "sv": ["kajak", "kanot"],
            "no": ["kajakk", "kano"], "nl": ["kajak", "kano"], "de": ["Kajak", "Kanu"],
            "is": ["kajak", "kanó"]
        ]
    ]

    /// Words that carry no search value in any of these languages.
    static let stopwords: Set<String> = [
        "a", "an", "the", "for", "with", "and", "or", "of", "my", "some", "any", "one",
        "en", "et", "ett", "de", "den", "det", "der", "die", "das", "ein", "eine",
        "het", "een", "un", "une", "il", "la", "el", "los", "las",
        "good", "nice", "used", "old", "new", "cheap", "condition", "working", "sale",
        "til", "salg", "salu", "koop", "verkauf", "sölu"
    ]

    /// "under €25,000" in every language the wish might be written in.
    static let ceilingWords = [
        "under", "below", "max", "maximum", "less than", "up to", "no more than",
        "onder", "unter", "bis", "hoechstens", "undir", "innan", "alle",
        "moins de", "menos de", "meno di", "maks", "maks."
    ]

    /// "I wish for", however it is said.
    static let leadIns = [
        "i wish for", "i want", "i am looking for", "looking for", "i seek", "wanted",
        "jeg ønsker mig", "jeg ønsker", "jeg vil have", "jeg leder efter", "jeg søger",
        "jag önskar", "jag söker", "jag vill ha",
        "ik wens", "ik zoek", "ik wil", "ich wünsche mir", "ich suche", "ich möchte",
        "ég óska eftir", "ég leita að", "ég vil", "mig vantar",
        "je cherche", "busco", "cerco"
    ]

    /// "anywhere in", "í", "bij".
    static let placeWords = [
        "anywhere in", "somewhere in", "near", "around", "in", "at",
        "i", "på", "ved", "nær", "omkring",
        "bij", "in der nähe von", "í", "á", "nálægt", "près de", "cerca de"
    ]

    /// Money words that are never the name of a thing.
    static let currencyWords: Set<String> = [
        "kr", "kr.", "kroner", "kronor", "krónur", "króna", "euro", "eur", "evrur",
        "usd", "gbp", "dkk", "sek", "nok", "isk", "dollars", "pounds", "euros"
    ]

    private static let index: [String: String] = {
        var map: [String: String] = [:]
        for (concept, byLanguage) in concepts {
            for (_, words) in byLanguage {
                for word in words { map[fold(word)] = concept }
            }
        }
        return map
    }()

    static func fold(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Which concept, if any, a word belongs to — in any of the languages.
    static func concept(for word: String) -> String? {
        let key = fold(word)
        if let hit = index[key] { return hit }
        if key.hasSuffix("s"), let hit = index[String(key.dropLast())] { return hit }
        if key.hasSuffix("er"), let hit = index[String(key.dropLast(2))] { return hit }
        guard key.count >= 5 else { return nil }
        for (word, concept) in index where word.count >= 5 {
            if word.hasPrefix(key) || key.hasPrefix(word) { return concept }
        }
        return nil
    }

    /// What to type into this site's search box for a concept.
    static func words(_ concept: String, language: String) -> [String] {
        guard let byLanguage = concepts[concept] else { return [] }
        return byLanguage[language] ?? byLanguage["en"] ?? []
    }

    /// Every word, in every language, that means this concept. Used for
    /// recognising a listing whatever tongue it is written in.
    static func allWords(_ concept: String) -> [String] {
        (concepts[concept] ?? [:]).values.flatMap { $0 }
    }
}
