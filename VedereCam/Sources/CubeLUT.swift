import CoreImage
import Foundation

/// Minimal Adobe .cube (3D LUT) parser producing data for CIColorCubeWithColorSpace.
struct CubeLUT {
    let dimension: Int
    let data: Data

    enum ParseError: Error { case invalid }

    init(text: String) throws {
        var size = 0
        var floats: [Float] = []
        for raw in text.split(whereSeparator: \.isNewline) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            if line.hasPrefix("LUT_3D_SIZE") {
                size = Int(line.split(separator: " ").last ?? "") ?? 0
            } else if let first = line.first, first.isNumber || first == "-" || first == "." {
                let parts = line.split(whereSeparator: { $0 == " " || $0 == "\t" }).compactMap { Float($0) }
                guard parts.count == 3 else { throw ParseError.invalid }
                floats += parts + [1]
            }
        }
        guard size >= 2, floats.count == size * size * size * 4 else { throw ParseError.invalid }
        dimension = size
        data = floats.withUnsafeBufferPointer { Data(buffer: $0) }
    }

    init(url: URL) throws {
        try self.init(text: String(contentsOf: url, encoding: .utf8))
    }
}
