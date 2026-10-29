import Foundation

/// A rendering "look": color, tone and texture parameters. Codable so it doubles as the sidecar/export format.
struct Look: Codable, Equatable, Identifiable {
    var id = UUID()
    var name: String
    var exposure: Double = 0          // EV
    var contrast: Double = 1          // 1 = neutral
    var saturation: Double = 1        // 1 = neutral
    var temperatureShift: Double = 0  // Kelvin offset from neutral (6500)
    var sharpness: Double = 0         // 0...2
    var grain: Double = 0             // 0...1
    var grainSize: Double = 1         // 0.5...3
    var lutFilename: String?          // .cube stored in the LUT directory
    var lutIntensity: Double = 1

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
