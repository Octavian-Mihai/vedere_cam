import CoreImage
import CoreImage.CIFilterBuiltins

/// Applies a Look to an image. The same chain serves live preview and the final capture render,
/// so what you see is what is baked in.
final class LookEngine {
    static let shared = LookEngine()
    let context = CIContext(options: [.workingColorSpace: CGColorSpace(name: CGColorSpace.extendedLinearDisplayP3) as Any])
    private var lutCache: [String: CubeLUT] = [:]
    private var mixCache: [String: Data] = [:]
    private let lock = NSLock()
    private static let cubeSize = 32

    func render(_ input: CIImage, look: Look) -> CIImage {
        let original = input.clampedToExtent()
        var image = original

        // Lightness
        if look.exposure != 0 {
            let f = CIFilter.exposureAdjust(); f.inputImage = image; f.ev = Float(look.exposure)
            image = f.outputImage ?? image
        }
        if look.shadows != 0 || look.highlights != 0 {
            let f = CIFilter.toneCurve(); f.inputImage = image
            f.point0 = CGPoint(x: 0, y: 0)
            f.point1 = CGPoint(x: 0.25, y: 0.25 + look.shadows * 0.1)
            f.point2 = CGPoint(x: 0.5, y: 0.5)
            f.point3 = CGPoint(x: 0.75, y: 0.75 + look.highlights * 0.1)
            f.point4 = CGPoint(x: 1, y: 1)
            image = f.outputImage ?? image
        }

        // Color
        if look.temperatureShift != 0 || look.tint != 0 {
            let f = CIFilter.temperatureAndTint(); f.inputImage = image
            f.neutral = CIVector(x: 6500, y: 0)
            f.targetNeutral = CIVector(x: 6500 - look.temperatureShift, y: look.tint)
            image = f.outputImage ?? image
        }
        if look.contrast != 1 || look.saturation != 1 {
            let f = CIFilter.colorControls(); f.inputImage = image
            f.contrast = Float(look.contrast); f.saturation = Float(look.saturation)
            image = f.outputImage ?? image
        }
        if look.mix.values.contains(where: { !$0.isNeutral }) {
            let f = CIFilter.colorCubeWithColorSpace(); f.inputImage = image
            f.cubeDimension = Float(Self.cubeSize); f.cubeData = mixCube(look.mix)
            f.colorSpace = CGColorSpace(name: CGColorSpace.sRGB)
            image = f.outputImage ?? image
        }

        // LUT
        if let name = look.lutFilename, let lut = loadLUT(name) {
            let f = CIFilter.colorCubeWithColorSpace(); f.inputImage = image
            f.cubeDimension = Float(lut.dimension); f.cubeData = lut.data
            f.colorSpace = CGColorSpace(name: CGColorSpace.sRGB)
            if let out = f.outputImage {
                image = look.lutIntensity >= 1 ? out : mix(image, out, amount: look.lutIntensity)
            }
        }

        // Texture
        if look.sharpness > 0 {
            let f = CIFilter.sharpenLuminance(); f.inputImage = image; f.sharpness = Float(look.sharpness)
            image = f.outputImage ?? image
        }
        if look.grain > 0 { image = addGrain(image, look: look) }

        // Overall strength: blend the finished look back toward the untouched image.
        if look.strength < 1 { image = mix(original, image, amount: max(0, look.strength)) }

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
        lock.lock(); defer { lock.unlock() }
        if let c = lutCache[name] { return c }
        let bundled = Bundle.main.url(forResource: (name as NSString).deletingPathExtension, withExtension: "cube")
        let url = bundled ?? Storage.lutDirectory.appendingPathComponent(name)
        guard let lut = try? CubeLUT(url: url) else { return nil }
        lutCache[name] = lut
        return lut
    }

    // MARK: - Color mix

    /// Builds a 3D color cube that applies the per-color hue/saturation/luminance adjustments.
    /// Cached by parameters, so dragging a slider only rebuilds it when the values change.
    private func mixCube(_ mix: [String: ChannelMix]) -> Data {
        let key = MixColor.allCases.map { c -> String in
            let m = mix[c.rawValue] ?? ChannelMix()
            return "\(m.hue),\(m.saturation),\(m.luminance)"
        }.joined(separator: "|")
        lock.lock()
        if let cached = mixCache[key] { lock.unlock(); return cached }
        lock.unlock()

        let n = Self.cubeSize
        var floats = [Float](repeating: 1, count: n * n * n * 4)
        let active = MixColor.allCases.compactMap { c -> (MixColor, ChannelMix)? in
            guard let m = mix[c.rawValue], !m.isNeutral else { return nil }
            return (c, m)
        }
        var i = 0
        for b in 0..<n { for g in 0..<n { for r in 0..<n {
            let rgb = (Double(r) / Double(n - 1), Double(g) / Double(n - 1), Double(b) / Double(n - 1))
            var (h, s, l) = Self.rgbToHSL(rgb)
            var dh = 0.0, ds = 0.0, dl = 0.0
            for (color, m) in active {
                var d = abs(h - color.centerHue).truncatingRemainder(dividingBy: 360)
                if d > 180 { d = 360 - d }
                var w = max(0, 1 - d / 45)
                w = w * w * (3 - 2 * w)            // smoothstep falloff
                w *= min(1, s * 3)                  // leave near-grays alone
                dh += w * m.hue / 100 * 30
                ds += w * m.saturation / 100
                dl += w * m.luminance / 100 * 0.25
            }
            h = (h + dh + 360).truncatingRemainder(dividingBy: 360)
            s = min(1, max(0, s * (1 + ds)))
            l = min(1, max(0, l + dl))
            let out = Self.hslToRGB((h, s, l))
            floats[i] = Float(out.0); floats[i + 1] = Float(out.1); floats[i + 2] = Float(out.2)
            i += 4
        } } }
        let data = floats.withUnsafeBufferPointer { Data(buffer: $0) }
        lock.lock(); mixCache[key] = data; lock.unlock()
        return data
    }

    private static func rgbToHSL(_ c: (Double, Double, Double)) -> (Double, Double, Double) {
        let (r, g, b) = c
        let mx = max(r, g, b), mn = min(r, g, b)
        let l = (mx + mn) / 2
        let d = mx - mn
        if d == 0 { return (0, 0, l) }
        let s = l > 0.5 ? d / (2 - mx - mn) : d / (mx + mn)
        var h: Double
        if mx == r { h = (g - b) / d + (g < b ? 6 : 0) }
        else if mx == g { h = (b - r) / d + 2 }
        else { h = (r - g) / d + 4 }
        return (h * 60, s, l)
    }

    private static func hslToRGB(_ c: (Double, Double, Double)) -> (Double, Double, Double) {
        let (h, s, l) = c
        if s == 0 { return (l, l, l) }
        let q = l < 0.5 ? l * (1 + s) : l + s - l * s
        let p = 2 * l - q
        func channel(_ t0: Double) -> Double {
            var t = t0.truncatingRemainder(dividingBy: 1); if t < 0 { t += 1 }
            if t < 1.0 / 6 { return p + (q - p) * 6 * t }
            if t < 0.5 { return q }
            if t < 2.0 / 3 { return p + (q - p) * (2.0 / 3 - t) * 6 }
            return p
        }
        let hk = h / 360
        return (channel(hk + 1.0 / 3), channel(hk), channel(hk - 1.0 / 3))
    }
}
