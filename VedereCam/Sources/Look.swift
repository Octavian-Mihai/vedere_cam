import Foundation

/// The colors the Mix tab can adjust independently, with their hue centers in degrees.
enum MixColor: String, CaseIterable, Codable {
    case red, orange, yellow, green, aqua, blue, purple, magenta

    var centerHue: Double {
        switch self {
        case .red: return 0
        case .orange: return 30
        case .yellow: return 60
        case .green: return 120
        case .aqua: return 180
        case .blue: return 240
        case .purple: return 275
        case .magenta: return 320
        }
    }

    var title: String { rawValue.capitalized }
}

/// Per-color adjustment, each in -100...100.
struct ChannelMix: Codable, Equatable {
    var hue = 0.0
    var saturation = 0.0
    var luminance = 0.0

    var isNeutral: Bool { hue == 0 && saturation == 0 && luminance == 0 }
}

/// A rendering "look": color, tone and texture parameters. Codable so it doubles as the sidecar/export format.
struct Look: Codable, Equatable, Identifiable {
    var id = UUID()
    var name: String
    var note: String = ""             // short description shown in the UI
    // Lightness
    var exposure: Double = 0          // EV
    var contrast: Double = 1          // 1 = neutral
    var highlights: Double = 0        // -1...1
    var shadows: Double = 0           // -1...1
    // Color
    var saturation: Double = 1        // 1 = neutral
    var temperatureShift: Double = 0  // Kelvin offset from neutral (6500)
    var tint: Double = 0              // -100...100
    var mix: [String: ChannelMix] = [:] // keyed by MixColor.rawValue
    // Texture
    var sharpness: Double = 0         // 0...2
    var grain: Double = 0             // 0...1
    var grainSize: Double = 1         // 0.5...3
    // LUT and overall strength
    var lutFilename: String?          // .cube in the bundle or the LUT directory
    var lutIntensity: Double = 1
    var strength: Double = 1          // 0 = original image, 1 = full look

    static let neutral = Look(name: "Neutral", note: "No color grade: your RAW developed cleanly. Use the Strength and editor sliders to build your own look.")

    /// Bundled looks from the No Fusion LUT pack. Names come from the pack's file names and the notes are
    /// inspired-by summaries backed by measuring each LUT (contrast, saturation, color cast, lifted blacks).
    static let builtIn: [Look] = [
        .neutral,
        Look(name: "Provia 100F", note: "Closest to true color. Slight warmth, near-full saturation and gentle contrast. A safe all-rounder for landscapes and travel.", lutFilename: "FProvia100F.cube"),
        Look(name: "Fuji 400H", note: "Soft and airy. Lifted shadows and clearly muted, pastel color (about half the saturation) with light skin tones. Good for portraits and overcast days.", lutFilename: "F400H.cube"),
        Look(name: "Fuji Sol 100", note: "Warm, faded and slightly low in contrast, with lifted blacks and bright midtones. A sunny, nostalgic look.", lutFilename: "FSol100.cube"),
        Look(name: "Kodachrome", note: "Classic slide look: warm reds, rich pinkish skin tones, mild fade in the blacks. Works for people and street scenes.", lutFilename: "KCHROME.cube"),
        Look(name: "Ektar 100", note: "The punchiest and the only one with no warm cast: boosted saturation, deeper midtones, soft highlights. Best for vivid landscapes and bright color.", lutFilename: "KEktr100.cube"),
        Look(name: "Gold 200", note: "Strong golden-yellow warmth with the highest contrast of the warm looks. Everyday snapshots and golden-hour light.", lutFilename: "KG200.cube"),
        Look(name: "Gold 200 P1", note: "A paler, dreamier take on Gold: very bright, soft contrast and gently warm. Summery, hazy scenes.", lutFilename: "KG200P1.cube"),
        Look(name: "Portra 160", note: "The softest of the set: muted color, low contrast, lifted blacks. Delicate pastel portraits in good light.", lutFilename: "KP160.cube"),
        Look(name: "Portra 400", note: "Natural, muted pastels with warm, soft skin tones. A versatile portrait and everyday look.", lutFilename: "KP400.cube"),
        Look(name: "Portra 800", note: "Low contrast with a bit more color than Portra 400. Lifted shadows give a moody low-light feel.", lutFilename: "KP800.cube"),
        Look(name: "Agfa Ultra 100", note: "Deepest blacks of the set, fairly contrasty with a warm tone. Punchy retro color.", lutFilename: "AgU100.cube"),
        Look(name: "L100", note: "Clean and lightly warm with near-full saturation and some punch. A neutral everyday grade.", lutFilename: "L100.cube"),
        Look(name: "Opti Clr 100", note: "Restrained color with a slightly green-neutral tint and darker midtones. A clear, documentary feel.", lutFilename: "OptiClr100.cube")
    ]

    func channel(_ color: MixColor) -> ChannelMix { mix[color.rawValue] ?? ChannelMix() }

    mutating func setChannel(_ color: MixColor, _ value: ChannelMix) {
        if value.isNeutral { mix.removeValue(forKey: color.rawValue) } else { mix[color.rawValue] = value }
    }
}

extension Look {
    /// Tolerant decoding so sidecars and look files written by older versions (missing newer fields) still load.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        var l = Look(name: try c.decodeIfPresent(String.self, forKey: .name) ?? "Look")
        l.id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        l.note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
        l.exposure = try c.decodeIfPresent(Double.self, forKey: .exposure) ?? 0
        l.contrast = try c.decodeIfPresent(Double.self, forKey: .contrast) ?? 1
        l.highlights = try c.decodeIfPresent(Double.self, forKey: .highlights) ?? 0
        l.shadows = try c.decodeIfPresent(Double.self, forKey: .shadows) ?? 0
        l.saturation = try c.decodeIfPresent(Double.self, forKey: .saturation) ?? 1
        l.temperatureShift = try c.decodeIfPresent(Double.self, forKey: .temperatureShift) ?? 0
        l.tint = try c.decodeIfPresent(Double.self, forKey: .tint) ?? 0
        l.mix = try c.decodeIfPresent([String: ChannelMix].self, forKey: .mix) ?? [:]
        l.sharpness = try c.decodeIfPresent(Double.self, forKey: .sharpness) ?? 0
        l.grain = try c.decodeIfPresent(Double.self, forKey: .grain) ?? 0
        l.grainSize = try c.decodeIfPresent(Double.self, forKey: .grainSize) ?? 1
        l.lutFilename = try c.decodeIfPresent(String.self, forKey: .lutFilename)
        l.lutIntensity = try c.decodeIfPresent(Double.self, forKey: .lutIntensity) ?? 1
        l.strength = try c.decodeIfPresent(Double.self, forKey: .strength) ?? 1
        self = l
    }
}

/// Which files a capture writes. Lets users trade quality for storage.
struct OutputOptions: Codable, Equatable {
    var saveRAW = true
    var saveRendered = true
    var saveSidecar = true
    var saveToPhotos = false
    var renderedFormat: RenderedFormat = .heic

    enum RenderedFormat: String, Codable, CaseIterable { case heic, jpeg }

    /// Rough per-shot size in MB, for showing in Settings.
    var estimatedMB: Double {
        (saveRAW ? 25 : 0) + (saveRendered ? 3 : 0) + (saveSidecar ? 0.01 : 0)
    }
}
