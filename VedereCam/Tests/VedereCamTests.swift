import XCTest
import CoreImage
@testable import VedereCam

final class VedereCamTests: XCTestCase {
    func testLookSidecarRoundTrip() throws {
        let look = Look.builtIn[1]
        let decoded = try JSONDecoder().decode(Look.self, from: JSONEncoder().encode(look))
        XCTAssertEqual(look, decoded)
    }

    func testCubeParsing() throws {
        var text = "LUT_3D_SIZE 2\n"
        for b in 0..<2 { for g in 0..<2 { for r in 0..<2 { text += "\(r) \(g) \(b)\n" } } }
        let lut = try CubeLUT(text: text)
        XCTAssertEqual(lut.dimension, 2)
        XCTAssertEqual(lut.data.count, 2 * 2 * 2 * 4 * MemoryLayout<Float>.size)
    }

    func testInvalidCubeThrows() {
        XCTAssertThrowsError(try CubeLUT(text: "LUT_3D_SIZE 2\n0 0 0\n"))
    }

    func testSaturationZeroProducesGray() throws {
        let red = CIImage(color: CIColor(red: 1, green: 0, blue: 0)).cropped(to: CGRect(x: 0, y: 0, width: 4, height: 4))
        var look = Look.neutral; look.saturation = 0
        let out = LookEngine.shared.render(red, look: look)
        var px = [UInt8](repeating: 0, count: 4)
        LookEngine.shared.context.render(out, toBitmap: &px, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                                         format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB))
        XCTAssertEqual(Int(px[0]), Int(px[1]), accuracy: 3)
        XCTAssertEqual(Int(px[1]), Int(px[2]), accuracy: 3)
    }
}
