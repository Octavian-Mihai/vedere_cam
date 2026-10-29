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

    func testBundledLooksHaveLoadableLUTs() throws {
        for look in Look.builtIn {
            guard let name = look.lutFilename else { continue }
            let url = try XCTUnwrap(Bundle.main.url(forResource: (name as NSString).deletingPathExtension, withExtension: "cube"), name)
            XCTAssertEqual(try CubeLUT(url: url).dimension, 32, name)
        }
    }

    private func pixel(_ image: CIImage) -> [UInt8] {
        var px = [UInt8](repeating: 0, count: 4)
        LookEngine.shared.context.render(image, toBitmap: &px, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                                         format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB))
        return px
    }

    func testLegacySidecarWithoutNewFieldsDecodes() throws {
        let json = #"{"name":"Old","exposure":0.5,"contrast":1.1,"saturation":1,"temperatureShift":0,"sharpness":0,"grain":0,"grainSize":1,"lutIntensity":1}"#
        let look = try JSONDecoder().decode(Look.self, from: Data(json.utf8))
        XCTAssertEqual(look.name, "Old")
        XCTAssertEqual(look.strength, 1)
        XCTAssertTrue(look.mix.isEmpty)
    }

    func testStrengthZeroReturnsOriginal() {
        let src = CIImage(color: CIColor(red: 0.8, green: 0.3, blue: 0.2)).cropped(to: CGRect(x: 0, y: 0, width: 4, height: 4))
        var look = Look.neutral; look.saturation = 0; look.strength = 0
        XCTAssertEqual(pixel(LookEngine.shared.render(src, look: look)), pixel(src))
    }

    func testOrangeMixChangesOrangeButNotBlue() {
        let orange = CIImage(color: CIColor(red: 0.9, green: 0.5, blue: 0.1)).cropped(to: CGRect(x: 0, y: 0, width: 4, height: 4))
        let blue = CIImage(color: CIColor(red: 0.1, green: 0.2, blue: 0.9)).cropped(to: CGRect(x: 0, y: 0, width: 4, height: 4))
        var look = Look.neutral
        look.setChannel(.orange, ChannelMix(hue: 0, saturation: -100, luminance: 0))
        XCTAssertNotEqual(pixel(LookEngine.shared.render(orange, look: look)), pixel(orange))
        let b0 = pixel(blue), b1 = pixel(LookEngine.shared.render(blue, look: look))
        for i in 0..<3 { XCTAssertEqual(Int(b0[i]), Int(b1[i]), accuracy: 3) }
    }
}
