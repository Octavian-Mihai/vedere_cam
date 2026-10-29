import CoreImage
import CoreImage.CIFilterBuiltins

/// Applies a Look to an image. The same chain serves live preview and the final capture render,
/// so what you see is what is baked in.
final class LookEngine {
    static let shared = LookEngine()
    let context = CIContext(options: [.workingColorSpace: CGColorSpace(name: CGColorSpace.extendedLinearDisplayP3) as Any])
    private var lutCache: [String: CubeLUT] = [:]

    func render(_ input: CIImage, look: Look) -> CIImage {
        var image = input.clampedToExtent()

        if look.exposure != 0 {
            let f = CIFilter.exposureAdjust(); f.inputImage = image; f.ev = Float(look.exposure)
            image = f.outputImage ?? image
        }
        if look.temperatureShift != 0 {
            let f = CIFilter.temperatureAndTint(); f.inputImage = image
            f.neutral = CIVector(x: 6500, y: 0)
            f.targetNeutral = CIVector(x: 6500 - look.temperatureShift, y: 0)
            image = f.outputImage ?? image
        }
        if look.contrast != 1 || look.saturation != 1 {
            let f = CIFilter.colorControls(); f.inputImage = image
            f.contrast = Float(look.contrast); f.saturation = Float(look.saturation)
            image = f.outputImage ?? image
        }
        if let name = look.lutFilename, let lut = loadLUT(name) {
            let f = CIFilter.colorCubeWithColorSpace(); f.inputImage = image
            f.cubeDimension = Float(lut.dimension); f.cubeData = lut.data
            f.colorSpace = CGColorSpace(name: CGColorSpace.sRGB)
            if let out = f.outputImage {
                image = look.lutIntensity >= 1 ? out : mix(image, out, amount: look.lutIntensity)
            }
        }
        if look.sharpness > 0 {
            let f = CIFilter.sharpenLuminance(); f.inputImage = image; f.sharpness = Float(look.sharpness)
            image = f.outputImage ?? image
        }
        if look.grain > 0 { image = addGrain(image, look: look) }

        return image.cropped(to: input.extent)
    }

    // MARK: - Helpers

    private func addGrain(_ image: CIImage, look: Look) -> CIImage {
        let noise = CIFilter.randomGenerator().outputImage ?? image
        let scale = CGAffineTransform(scaleX: CGFloat(look.grainSize), y: CGFloat(look.grainSize))
        // Center the noise around mid-gray and desaturate, then scale strength.
        let toneNoise = noise.transformed(by: scale)
            .applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: CGFloat(look.grain) * 0.3, y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: CGFloat(look.grain) * 0.3, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: CGFloat(look.grain) * 0.3, w: 0),
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0),
                "inputBiasVector": CIVector(x: 0, y: 0, z: 0, w: 1)
            ])
            .applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0])
        let blend = CIFilter.softLightBlendMode()
        blend.inputImage = toneNoise.cropped(to: image.extent)
        blend.backgroundImage = image
        return blend.outputImage ?? image
    }

    private func mix(_ a: CIImage, _ b: CIImage, amount: Double) -> CIImage {
        let f = CIFilter.dissolveTransition()
        f.inputImage = a; f.targetImage = b; f.time = Float(amount)
        return f.outputImage ?? b
    }

    private func loadLUT(_ name: String) -> CubeLUT? {
        if let c = lutCache[name] { return c }
        guard let lut = try? CubeLUT(url: Storage.lutDirectory.appendingPathComponent(name)) else { return nil }
        lutCache[name] = lut
        return lut
    }
}
