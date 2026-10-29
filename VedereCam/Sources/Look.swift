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

    static let neutral = Look(name: "Neutral")

    /// Bundled looks from the No Fusion LUT pack, grouped by film family.
    static let builtIn: [Look] = [
        .neutral,
        Look(name: "Provia 100F", lutFilename: "FProvia100F.cube"),
        Look(name: "Fuji 400H", lutFilename: "F400H.cube"),
        Look(name: "Fuji Sol 100", lutFilename: "FSol100.cube"),
        Look(name: "Kodachrome", lutFilename: "KCHROME.cube"),
        Look(name: "Ektar 100", lutFilename: "KEktr100.cube"),
        Look(name: "Gold 200", lutFilename: "KG200.cube"),
        Look(name: "Gold 200 P1", lutFilename: "KG200P1.cube"),
        Look(name: "Portra 160", lutFilename: "KP160.cube"),
        Look(name: "Portra 400", lutFilename: "KP400.cube"),
        Look(name: "Portra 800", lutFilename: "KP800.cube"),
        Look(name: "Agfa Ultra 100", lutFilename: "AgU100.cube"),
        Look(name: "L100", lutFilename: "L100.cube"),
        Look(name: "Opti Clr 100", lutFilename: "OptiClr100.cube")
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
