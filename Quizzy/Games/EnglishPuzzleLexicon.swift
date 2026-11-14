#if os(iOS)
import Foundation

/// Authored offline English vocabulary. Deliberately curated rather than a full dictionary.
/// Content versions are namespaced so Spanish saved games keep their original identities.
enum EnglishPuzzleLexicon {
    static let cluePairs: [(String, String)] = [
        ("BALL", "Round object used in many sports"), ("WALL", "Vertical side of a room"), ("CALL", "To telephone someone"), ("AREA", "Amount of space inside a shape"),
        ("LEAD", "To guide someone"), ("LADY", "An adult woman"),
        ("APPLE", "Fruit that grows in an orchard"), ("BEACH", "Sandy shore beside the sea"),
        ("BREAD", "Food baked from dough"), ("CHAIR", "A seat for one person"),
        ("CLOUD", "A mass of water droplets in the sky"), ("DREAM", "Story experienced while asleep"),
        ("EARTH", "Our home planet"), ("FIELD", "Open land used for crops"),
        ("GRAPE", "Small fruit that grows in bunches"), ("HEART", "Organ that pumps blood"),
        ("HOUSE", "A building where people live"), ("LIGHT", "What lets us see"),
        ("MOUSE", "Small rodent with a long tail"), ("NIGHT", "Time between sunset and sunrise"),
        ("OCEAN", "A vast body of salt water"), ("PAPER", "Material used for writing"),
        ("PLANT", "Living thing with roots and leaves"), ("RIVER", "Natural stream of water"),
        ("SHEEP", "Farm animal raised for wool"), ("SMILE", "Happy expression of the mouth"),
        ("STONE", "Small piece of rock"), ("TABLE", "Furniture with a flat top"),
        ("TIGER", "Large striped cat"), ("TRAIN", "Vehicle that travels on rails"),
        ("WATER", "Liquid we drink"), ("WHEEL", "Round part that turns on an axle"),
        ("WORLD", "The planet and everyone on it"), ("WRITE", "Put words on a page"),
        ("TREE", "Tall plant with a woody trunk"), ("STAR", "Bright point in the night sky"),
        ("MOON", "Earth's natural satellite"), ("BOOK", "Pages bound together for reading"),
        ("DOOR", "A moving panel at an entrance"), ("FISH", "Animal that breathes through gills"),
        ("BIRD", "Animal with feathers"), ("RAIN", "Water falling from clouds"),
        ("SNOW", "Frozen flakes falling from clouds"), ("WIND", "Moving air"),
        ("FIRE", "Heat and light produced by burning"), ("ROAD", "Route used by vehicles"),
        ("HAND", "Body part with fingers"), ("HOME", "The place where someone lives"),
        ("TIME", "What clocks measure"), ("GAME", "Activity played for fun"),
        ("GOLD", "Precious yellow metal"), ("BLUE", "Color of a clear daytime sky"),
        ("GREEN", "Color of healthy grass"), ("SWEET", "Tasting like sugar"),
        ("PLANE", "Aircraft with wings"), ("PLANET", "World that orbits a star"),
        ("PLATE", "Flat dish used to serve food"), ("PANEL", "Flat section of a surface"),
        ("PETAL", "Colored part of a flower"), ("LEAPT", "Jumped through the air"),
        ("LEANT", "Rested at an angle"), ("PALE", "Having little color"),
        ("LATE", "After the expected time"), ("TALE", "A story"),
        ("TAPE", "Narrow strip used for sticking things"), ("LANE", "Narrow road"),
        ("LEAN", "To tilt to one side"), ("NEAT", "Tidy and well arranged"),
        ("PANE", "Single sheet of window glass"), ("PEAL", "Loud ringing of bells"),
        ("LEAP", "To jump"), ("ANT", "Small insect that lives in a colony"),
        ("APE", "Primate without a tail"), ("ATE", "Consumed a meal"),
        ("EAT", "Consume food"), ("LAP", "One trip around a running track"),
        ("LET", "Allow"), ("NET", "Mesh used to catch things"),
        ("PAN", "Container used for cooking"), ("PAT", "A gentle tap"),
        ("PEA", "Small round green vegetable"), ("PEN", "Tool used to write with ink"),
        ("PET", "Animal kept as a companion"), ("TAN", "Light brown color"),
        ("TAP", "A light touch"), ("TEA", "Drink made by steeping leaves"),
        ("TEN", "Number after nine")
    ]
    static let clues: [NaturalClue] = cluePairs.map { NaturalClue(word: $0.0, clue: $0.1) }
    static let answers = cluePairs.map(\.0).filter { $0.count == 5 }
    // Additional authored everyday guesses. Validation is intentionally broader
    // than the answer bank, so a reasonable Wordle probe is not rejected.
    static let everydayWords = """
    ABOUT ABOVE ABUSE ACTOR ACUTE ADMIT ADOPT ADULT AFTER AGAIN AGENT AGREE AHEAD ALARM ALBUM ALERT ALIKE ALIVE ALLOW ALONE ALONG ALTER AMONG ANGER ANGLE ANGRY APART APPLY ARGUE ARISE ASIDE ASSET AUDIO AVOID AWAKE AWARD AWARE BADLY BASIC BASIS BEGIN BEGUN BELOW BENCH BIRTH BLACK BLAME BLANK BLIND BLOCK BLOOD BOARD BOOST BOUND BRAIN BRAND BRASS BRAVE BREAK BREED BRICK BRIEF BRING BROAD BROKE BROWN BUILD BUILT BUYER CABLE CARRY CATCH CAUSE CHAIN CHALK CHARM CHART CHASE CHEAP CHECK CHEST CHIEF CHILD CHOSE CIVIL CLAIM CLASS CLEAN CLEAR CLERK CLICK CLIMB CLOCK CLOSE COACH COAST COLOR COULD COUNT COURT COVER CRACK CRAFT CRASH CREAM CRIME CROSS CROWD CROWN CURVE CYCLE DAILY DANCE DATED DEALT DEATH DEBUT DELAY DEPTH DOING DOUBT DOZEN DRAFT DRAIN DRAWN DRESS DRINK DRIVE DROVE DYING EAGER EARLY EIGHT ELDER ELECT EMPTY ENEMY ENJOY ENTER ENTRY EQUAL ERROR EVENT EVERY EXACT EXIST EXTRA FAITH FALSE FAULT FEWER FIBER FIFTH FIFTY FIGHT FINAL FIRST FIXED FLAME FLASH FLEET FLOOR FLUID FOCUS FORCE FORTH FORTY FORUM FOUND FRAME FRESH FRONT FRUIT FULLY FUNNY GIANT GIVEN GLASS GLOBE GOING GRACE GRADE GRAND GRANT GRASS GREAT GREEN GROSS GROUP GROWN GUARD GUESS GUEST GUIDE HAPPY HEAVY HENCE HORSE HOTEL HUMAN IDEAL IMAGE INDEX INNER INPUT ISSUE JOINT JUDGE KNIFE KNOCK KNOWN LABEL LARGE LASER LATER LAUGH LAYER LEARN LEAST LEAVE LEGAL LEVEL LIMIT LOCAL LOOSE LUCKY LUNCH MAGIC MAJOR MAKER MARCH MATCH MAYBE MAYOR METAL MIGHT MINOR MODEL MONEY MONTH MORAL MOTOR MOUNT MOVIE MUSIC NEEDS NEVER NEWLY NOISE NORTH NOVEL NURSE OCCUR OFFER OFTEN ORDER OTHER OUGHT OUTER OWNER PAINT PANEL PARTY PEACE PHASE PHONE PHOTO PIECE PILOT PITCH PLAIN PLANE PLATE POINT POUND POWER PRESS PRICE PRIDE PRIME PRINT PRIOR PRIZE PROOF PROUD PROVE QUEEN QUICK QUIET QUITE RADIO RAISE RAPID RATIO REACH READY REFER RIGHT RIGID RIVAL ROUGH ROUND ROUTE ROYAL RURAL SCALE SCENE SCOPE SCORE SENSE SERVE SEVEN SHALL SHAPE SHARE SHARP SHEET SHELF SHELL SHIFT SHIRT SHOCK SHOOT SHORT SHOWN SIGHT SINCE SIXTH SKILL SLEEP SLIDE SMALL SMART SMELL SMOKE SOLID SOLVE SORRY SOUND SOUTH SPACE SPARE SPEAK SPEED SPEND SPENT SPLIT SPOKE SPORT STAFF STAGE STAND START STATE STEAM STEEL STILL STOCK STOOD STORE STORM STORY STUDY STUFF STYLE SUGAR SUPER SWEET TAKEN TASTE TEACH TEETH THANK THEIR THEME THERE THESE THICK THING THINK THIRD THOSE THREE THROW TIGHT TIRED TITLE TODAY TOPIC TOTAL TOUCH TOUGH TOWER TRACK TRADE TREAT TREND TRIAL TRIBE TRICK TRIED TRULY TRUST TRUTH TWICE UNDER UNION UNITY UNTIL UPPER UPSET URBAN USAGE USUAL VALUE VIDEO VISIT VITAL VOICE WASTE WATCH WEIGH WEIRD WHERE WHICH WHILE WHITE WHOLE WHOSE WOMAN WOMEN WORRY WORSE WORST WORTH WOULD WOUND WRONG WROTE YIELD YOUNG YOUTH
    """.split(separator: " ").map(String.init)
    static let words = Array(Set(cluePairs.map(\.0) + everydayWords + [
        "UNDERSTAND", "AFTERNOON", "SOMETHING", "SUNFLOWER", "NEWSPAPER",
        "AND", "NO", "ON", "SO", "ME", "LOW", "ER", "PA", "PER", "SOME", "UNDERHAND", "SOMEWHERE",
        "GARDEN", "DANGER", "RANGED", "ANGER", "RANGE", "GRADE", "GRAND", "DEAR", "DARE", "READ", "DEAN", "EARN", "NEAR", "RAGE", "GEAR", "DRAG", "AGED", "AGE", "ARE", "EAR", "ERA", "RAN", "RED", "RAG", "DEN", "END",
        "LISTEN", "SILENT", "ENLIST", "TINSEL", "INLETS", "LENT", "LENS", "LINE", "TILE", "TIES", "NEST", "NETS", "SENT", "TENS", "LIES", "ISLE", "SILT", "SLIT", "LINT", "LIT", "SIT", "SIN", "TIN", "TEN", "SET", "NET", "LET", "LIE", "TIE"
    ])).sorted()
    static let wordSet = Set(words)

    static func quartiles(seed: UInt64) -> QuartilePuzzle {
        var groups = [["UN","DER","ST","AND"], ["AF","TER","NO","ON"],
                      ["SO","ME","TH","ING"], ["SU","NF","LOW","ER"], ["NE","WS","PA","PER"]]
        switch seed % 3 {
        case 1: groups[2] = ["SO", "ME", "WH", "ERE"]
        case 2: groups[0] = ["UN", "DER", "HA", "ND"]
        default: break
        }
        let targets = groups.map { $0.joined() }
        var rng = SeededGenerator(seed: seed)
        let tiles = rng.shuffled(groups.flatMap { $0 })
        var solutions = ["1": [String](), "2": [String](), "3": [String](), "4": targets]
        func search(_ prefix: String, _ used: Set<Int>) {
            if !used.isEmpty, wordSet.contains(prefix) { solutions[String(used.count), default: []].append(prefix) }
            guard used.count < 3 else { return }
            for i in tiles.indices where !used.contains(i) { search(prefix + tiles[i], used.union([i])) }
        }
        search("", [])
        for key in solutions.keys { solutions[key] = Array(Set(solutions[key]!)).sorted() }
        let score = 90 + (solutions["1"]!.count) + (solutions["2"]!.count * 2) + (solutions["3"]!.count * 4)
        return QuartilePuzzle(id: "en-q-gen-\(seed)", tiles: tiles,
                              targets: targets, solutions: solutions, maxScore: score)
    }

    /// Fully checked English word square. Rows and columns are all real clued words.
    static func crossword(id: String, variant: UInt64 = 0) -> CrosswordPuzzle {
        let rows = [["BALL", "WALL", "CALL"][Int(variant % 3)], "AREA", "LEAD", "LADY"]
        var solution: [String: String] = [:]
        var entries: [CrossEntry] = []
        for (r, word) in rows.enumerated() {
            for (c, letter) in word.enumerated() { solution["\(r),\(c)"] = String(letter) }
            let clue = cluePairs.first { $0.0 == word }!.1
            entries.append(CrossEntry(word: word, clue: clue, dir: "H", row: r, col: 0, len: 4))
            entries.append(CrossEntry(word: word, clue: clue, dir: "V", row: 0, col: r, len: 4))
        }
        return CrosswordPuzzle(id: id, size: 4, blocks: [], solution: solution, entries: entries, full: true)
    }
}
#endif
