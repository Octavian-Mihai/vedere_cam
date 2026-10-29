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

    static let builtIn: [Look] = [
        .neutral,
        Look(name: "Film Warm", contrast: 1.08, saturation: 1.1, temperatureShift: 400, grain: 0.35, grainSize: 1.2),
        Look(name: "Crisp", contrast: 1.15, saturation: 1.05, sharpness: 0.8),
        Look(name: "Mono Grain", contrast: 1.2, saturation: 0, grain: 0.5, grainSize: 1.5),
        Look(name: "Soft Fade", exposure: 0.2, contrast: 0.88, saturation: 0.9, grain: 0.15)
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
