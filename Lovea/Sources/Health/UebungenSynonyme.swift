import Foundation

/// Was ein Suchwort bedeutet: Wörter, die im Namen stehen dürfen (deutsch, englisch, Umgangssprache),
/// und Zielmuskeln des Katalogs, die es ebenfalls erfüllen. Alles normalisiert (`UebungsKatalog.normal`).
struct SuchBegriff: Sendable {
    let woerter: [String]
    let muskeln: Set<String>
    /// Gilt nur für `woerter`: Treffer muss einen dieser Zielmuskeln oder Körperteile haben (leer = egal).
    let nur: Set<String>

    init(_ woerter: [String], muskeln: [String] = [], nur: [String] = []) {
        self.woerter = woerter.map(UebungsKatalog.normal)
        self.muskeln = Set(muskeln.map(UebungsKatalog.normal))
        self.nur = Set(nur.map(UebungsKatalog.normal))
    }
}

/// Synonym-Tabelle und Muskel-Zuordnung der Übungssuche. Die Schlüssel sind das, was jemand tippt
/// ("upper chest", "obere Brust", "Po", "KH"); rechts steht, wonach im Katalog gesucht wird.
// ponytail: feste Tabelle statt Wörterbuch aus Daten; neue Begriffe hier eintragen, Test dazu in UebungsSucheTests.
enum UebungenSynonyme {
    /// Schlüssel (normalisiert, ein bis drei Wörter) -> Bedeutung.
    static let begriffe: [String: SuchBegriff] = {
        var tabelle: [String: SuchBegriff] = [:]
        for (schluessel, begriff) in liste {
            for s in schluessel { tabelle[UebungsKatalog.normal(s)] = begriff }
        }
        return tabelle
    }()

    static let laengsterSchluessel: Int = begriffe.keys.map { $0.split(separator: " ").count }.max() ?? 1

    private static let liste: [([String], SuchBegriff)] = [
        // Geräte
        (["kh", "kurzhantel", "kurzhanteln", "dumbbell", "dumbbells", "db"], SuchBegriff(["kurzhantel"])),
        (["lh", "langhantel", "langhanteln", "barbell", "bb"], SuchBegriff(["langhantel"])),
        (["sz", "ez", "sz stange", "ez bar"], SuchBegriff(["sz stange"])),
        (["kabel", "cable", "seilzug", "kabelzug", "kabelturm"], SuchBegriff(["kabelzug"])),
        (["maschine", "machine", "gerat", "lever"], SuchBegriff(["maschine"])),
        (["smith", "smith machine", "multipresse"], SuchBegriff(["multipresse", "smith"])),
        (["kb", "kettlebell"], SuchBegriff(["kettlebell"])),
        (["bodyweight", "body weight", "eigengewicht", "ohne gerat", "korpergewicht"], SuchBegriff(["korpergewicht"])),

        // Brust
        (["brust", "chest", "pecs", "pec", "pectorals", "brustmuskel", "brustmuskeln"], SuchBegriff(["brust", "chest"], muskeln: ["Brust"])),
        (["obere brust", "upper chest", "oberer brustmuskel", "clavicular"],
         SuchBegriff(["schrag", "incline", "obere brust", "upper chest"], nur: ["Brust"])),
        (["untere brust", "lower chest"], SuchBegriff(["negativ", "decline", "untere brust", "lower chest"], nur: ["Brust"])),
        (["innere brust", "inner chest", "brustmitte"],
         SuchBegriff(["fliegende", "crossover", "butterfly", "pec deck", "innere brust", "inner chest"], nur: ["Brust"])),

        // Arme
        (["bizeps", "biceps", "bicep", "bi", "armbeuger"], SuchBegriff(["bizeps", "biceps", "curl"], muskeln: ["Bizeps"], nur: ["Arme"])),
        (["trizeps", "triceps", "tricep", "tri", "armstrecker"],
         SuchBegriff(["trizeps", "tricep", "pushdown", "skull", "dip", "kickback"], muskeln: ["Trizeps"], nur: ["Arme"])),
        (["unterarme", "unterarm", "forearms", "forearm", "griffkraft"],
         SuchBegriff(["unterarm", "forearm", "handgelenk", "wrist"], muskeln: ["Unterarme"])),

        // Schultern
        (["schulter", "schultern", "shoulder", "shoulders", "delts", "delt", "deltoid", "deltas"],
         SuchBegriff(["schulter", "shoulder", "delt"], muskeln: ["Schultern"])),
        (["hintere schulter", "hintere schultern", "rear delts", "rear delt", "rear deltoid", "reverse delts", "hinterer deltamuskel"],
         SuchBegriff(["reverse", "rear", "hintere schulter", "face pull", "pec deck"], nur: ["Schultern"])),
        (["seitliche schulter", "seitliche schultern", "side delts", "side delt", "lateral delts", "mittlere schulter"],
         SuchBegriff(["seitheben", "lateral raise", "side raise"], nur: ["Schultern"])),
        (["vordere schulter", "vordere schultern", "front delts", "front delt", "anterior delt"],
         SuchBegriff(["frontheben", "front raise", "schulterdrucken", "shoulder press", "overhead press"], nur: ["Schultern"])),

        // Rücken
        (["lats", "latissimus", "latissimus dorsi", "breiter rucken"],
         SuchBegriff(["latzug", "pulldown", "klimmzug", "pull up", "pullover"], muskeln: ["Latissimus"])),
        (["oberer rucken", "upper back", "rhomboids", "rhomboid", "rautenmuskel", "mittlerer rucken"],
         SuchBegriff(["rudern", "row"], muskeln: ["oberer Rücken", "Rautenmuskel"], nur: ["Rücken"])),
        (["rucken", "back"], SuchBegriff(["rucken"])),
        (["trapez", "traps", "trap", "trapezius"], SuchBegriff(["trapez", "shrug"], muskeln: ["Trapez"])),
        (["unterer rucken", "lower back", "ruckenstrecker", "erector spinae", "kreuz"],
         SuchBegriff(["ruckenstrecker", "hyperextension", "back extension", "good morning", "kreuzheben", "deadlift"],
                     muskeln: ["Rückenstrecker", "unterer Rücken"])),

        // Beine und Po
        (["quads", "quad", "quadrizeps", "quadriceps", "vorderer oberschenkel", "oberschenkel vorne"],
         SuchBegriff(["quadrizeps", "quadricep", "kniebeuge", "squat", "beinpresse", "leg press", "beinstrecker", "leg extension",
                      "ausfallschritt", "lunge", "hack"], muskeln: ["Quadrizeps"], nur: ["Beine"])),
        (["oberschenkel", "thigh", "thighs"],
         SuchBegriff(["oberschenkel", "kniebeuge", "squat", "beinpresse", "leg press", "beinstrecker", "leg extension", "beinbeuger", "leg curl",
                      "ausfallschritt", "lunge", "hack"], muskeln: ["Quadrizeps", "Beinbeuger", "Adduktoren", "Abduktoren"], nur: ["Beine"])),
        (["hamstrings", "hamstring", "hintere oberschenkel", "oberschenkel hinten", "beinruckseite"],
         SuchBegriff(["beinbeuger", "hamstring", "leg curl", "rumanisches kreuzheben", "romanian deadlift", "good morning"],
                     muskeln: ["Beinbeuger"], nur: ["Beine"])),
        (["glutes", "glute", "gluteus", "po", "gesass", "hintern", "butt", "popo"],
         SuchBegriff(["glute", "hip thrust", "kickback", "gesassbrucke"], muskeln: ["Po"], nur: ["Beine"])),
        (["waden", "wade", "calves", "calf"], SuchBegriff(["wadenheben", "wadenpresse", "waden", "calf"], muskeln: ["Waden"])),
        (["adduktoren", "adduktor", "adductors", "adductor", "innere oberschenkel", "oberschenkel innen", "innenseite oberschenkel"],
         SuchBegriff(["adduktor", "adduction"], muskeln: ["Adduktoren"])),
        (["abduktoren", "abduktor", "abductors", "abductor", "aussere oberschenkel", "oberschenkel aussen", "aussenseite"],
         SuchBegriff(["abduktor", "abduction"], muskeln: ["Abduktoren"])),

        // Rumpf
        (["bauch", "abs", "bauchmuskeln", "bauchmuskel", "core", "sixpack", "six pack", "rumpf", "bauchpresse"],
         SuchBegriff(["bauch", "crunch", "plank", "sit up"], muskeln: ["Bauch"])),

        // Übungen und Umgangssprache
        (["beinstrecker", "leg extension", "knee extension", "quad extension"], SuchBegriff(["beinstrecker", "leg extension"])),
        (["beinbeuger", "leg curl", "hamstring curl"], SuchBegriff(["beinbeuger", "leg curl"])),
        (["beinpresse", "leg press", "legpress"], SuchBegriff(["beinpresse", "leg press"])),
        (["hackenschmidt", "hack squat", "hacke"], SuchBegriff(["hackenschmidt", "hack"])),
        (["overhead", "uberkopf", "uber kopf"], SuchBegriff(["overhead", "uber kopf", "uberkopf"])),
        (["rudern", "row", "ruderzug"], SuchBegriff(["rudern", "row"])),
        (["kniebeuge", "kniebeugen", "squat", "squats"], SuchBegriff(["kniebeuge", "squat"])),
        (["kreuzheben", "deadlift", "deadlifts"], SuchBegriff(["kreuzheben", "deadlift"])),
        (["bankdrucken", "bench press", "bankdruck"], SuchBegriff(["bankdruck", "bench press"])),
        (["klimmzug", "klimmzuge", "pull up", "pullup", "pull ups", "chin up", "chinup"], SuchBegriff(["klimmzug", "pull up", "chin up"])),
        (["liegestutz", "liegestutze", "push up", "pushup", "push ups"], SuchBegriff(["liegestutz", "push up"])),
        (["latzug", "lat pulldown", "lat pull down", "pulldown"], SuchBegriff(["latzug", "pulldown"])),
        (["seitheben", "seitenheben", "lateral raise", "side raise"], SuchBegriff(["seitheben", "lateral raise"])),
        (["frontheben", "front raise"], SuchBegriff(["frontheben", "front raise"])),
        (["fliegende", "fly", "flys", "flyes", "flies"], SuchBegriff(["fliegende", "fly", "flye"])),
        (["schulterdrucken", "shoulder press", "military press", "ohp", "overhead press"],
         SuchBegriff(["schulterdrucken", "shoulder press", "military press", "uberkopfdrucken", "overhead press"])),
        (["brustpresse", "chest press", "brustdrucken"], SuchBegriff(["brustpresse", "chest press", "brustdrucken"])),
        (["rumanisches kreuzheben", "romanian deadlift", "rdl"], SuchBegriff(["rumanisches kreuzheben", "romanian deadlift"])),
        (["ausfallschritt", "ausfallschritte", "lunge", "lunges"], SuchBegriff(["ausfallschritt", "lunge"])),
        (["wadenheben", "calf raise", "wadenpresse"], SuchBegriff(["wadenheben", "calf raise", "wadenpresse"])),
    ]

    /// Zusätzliche Suchwörter je Übung (id), für Namen aus dem Studio, die ExerciseDB anders nennt.
    /// Normalisiert beim Laden; die Anzeigenamen und ids bleiben unverändert.
    static let alias: [String: String] = [
        "v3xmPAR": "pec deck butterfly butterfly maschine brustmaschine peck deck pec fly",
        "myfUsKf": "reverse pec deck reverse butterfly rear delt fly maschine hintere schulter",
        "xiHiJcA": "reverse pec deck reverse butterfly rear delt fly maschine hintere schulter",
        "Qa55kX1": "hackenschmidt hackenschmidt kniebeuge hackenschmidt maschine hack squat maschine",
        "gf3ZjB9": "hackenschmidt hackenschmidt kniebeuge hackenschmidt maschine hack squat maschine",
        "qg2PGl6": "hip thrust langhantel hip thrust bank huftheben",
        "qKBpF7I": "hip thrust langhantel huftheben",
        "aWedzZX": "hip thrust bank korpergewicht huftheben",
        "Pjbc0Kt": "hip thrust band huftheben",
        "lv-hip-thrust-kurzhantel": "huftheben",
        "lv-hip-thrust-maschine": "huftheben glute drive",
        "RVwzP10": "latzug breit weiter griff obergriff lat pulldown breiter griff",
        "qdRxqCj": "latzug breit weiter griff obergriff lat stange",
        "4c9BhzB": "latzug eng enger griff v griff close grip",
        "xBYcQHj": "latzug eng enger griff untergriff close grip",
        "rkg41Fb": "latzug eng enger griff paralleler griff",
        "ecpY0rH": "latzug maschine untergriff eng",
        "7F1DVzn": "latzug maschine breit",
        "7I6LNUG": "rudermaschine rowing machine brustgestutztes rudern",
        "IGjKj1v": "rudermaschine rowing machine enger griff",
        "oHsrypV": "adduktorenmaschine innere oberschenkel maschine",
        "CHpahtl": "abduktorenmaschine aussere oberschenkel maschine",
        "2IxROQ1": "trizeps overhead kabel overhead extension french press",
        "1xHyxys": "trizeps overhead kabel overhead extension french press",
        "NN8nSNT": "trizeps overhead kabel overhead extension french press",
        "lv-face-pull": "gesichtszug",
    ].mapValues(UebungsKatalog.normal)
}
