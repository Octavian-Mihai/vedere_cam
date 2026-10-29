import Foundation
import CoreImage
import Photos
import UIKit

/// One captured/imported photo in the library. The original (if kept) is never modified.
struct PhotoRecord: Identifiable, Hashable, Equatable {
    let id: String          // base filename, e.g. IMG_20261029_101500
    var rawURL: URL?
    var renderedURL: URL?
    var sidecarURL: URL?
    var thumbnailSource: URL? { renderedURL ?? rawURL }
}

enum Storage {
    static var library: URL { directory("Library") }
    static var lutDirectory: URL { directory("LUTs") }
    static var looksDirectory: URL { directory("Looks") }

    private static func directory(_ name: String) -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = docs.appendingPathComponent(name, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func newID() -> String {
        let f = DateFormatter(); f.dateFormat = "yyyyMMdd_HHmmss_SSS"
        return "IMG_" + f.string(from: Date())
    }

    // MARK: Saving

    /// Writes the requested outputs for one shot. `rawData` is the DNG bytes (nil if RAW unavailable).
    static func save(id: String, rawData: Data?, rendered: CIImage?, look: Look, options: OutputOptions) throws {
        let fm = FileManager.default
        if options.saveRAW, let rawData {
            try rawData.write(to: library.appendingPathComponent(id + ".dng"), options: .atomic)
        }
        if options.saveRendered, let rendered {
            let ext = options.renderedFormat == .heic ? "heic" : "jpg"
            let url = library.appendingPathComponent("\(id).\(ext)")
            try write(rendered, to: url, format: options.renderedFormat)
            if options.saveToPhotos { saveToPhotos(url) }
        }
        if options.saveSidecar {
            let data = try JSONEncoder().encode(look)
            try data.write(to: library.appendingPathComponent(id + ".look.json"), options: .atomic)
        }
        _ = fm
    }

    static func write(_ image: CIImage, to url: URL, format: OutputOptions.RenderedFormat) throws {
        let ctx = LookEngine.shared.context
        let cs = CGColorSpace(name: CGColorSpace.displayP3)!
        switch format {
        case .heic: try ctx.writeHEIFRepresentation(of: image, to: url, format: .RGBA8, colorSpace: cs)
        case .jpeg: try ctx.writeJPEGRepresentation(of: image, to: url, colorSpace: cs)
        }
    }

    static func saveToPhotos(_ url: URL) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else { return }
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: url)
            }
        }
    }

    // MARK: Listing

    static func loadRecords() -> [PhotoRecord] {
        let files = (try? FileManager.default.contentsOfDirectory(at: library, includingPropertiesForKeys: nil)) ?? []
        var map: [String: PhotoRecord] = [:]
        for url in files {
            var name = url.lastPathComponent
            let ext = url.pathExtension.lowercased()
            if name.hasSuffix(".look.json") { name = String(name.dropLast(".look.json".count)) }
            else { name = url.deletingPathExtension().lastPathComponent }
            var rec = map[name] ?? PhotoRecord(id: name)
            switch ext {
            case "dng": rec.rawURL = url
            case "heic", "jpg", "jpeg", "png": rec.renderedURL = url
            case "json": rec.sidecarURL = url
            default: break
            }
            map[name] = rec
        }
        return map.values.sorted { $0.id > $1.id }
    }

    static func loadLook(for record: PhotoRecord) -> Look? {
        guard let url = record.sidecarURL, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Look.self, from: data)
    }

    static func delete(_ record: PhotoRecord, includingOriginal: Bool) {
        let fm = FileManager.default
        if let u = record.renderedURL { try? fm.removeItem(at: u) }
        if let u = record.sidecarURL { try? fm.removeItem(at: u) }
        if includingOriginal, let u = record.rawURL { try? fm.removeItem(at: u) }
    }

    // MARK: Re-render (non-destructive: writes a new derived file, never touches the original)

    @discardableResult
    static func rerender(_ record: PhotoRecord, look: Look, format: OutputOptions.RenderedFormat) throws -> String? {
        guard let source = record.rawURL ?? record.renderedURL else { return nil }
        let base: CIImage?
        if source.pathExtension.lowercased() == "dng" {
            base = CIRAWFilter(imageURL: source)?.outputImage
        } else {
            base = CIImage(contentsOf: source)
        }
        guard let base else { return nil }
        let id = newID()
        let out = LookEngine.shared.render(base, look: look)
        try save(id: id, rawData: nil, rendered: out, look: look,
                 options: OutputOptions(saveRAW: false, saveRendered: true, saveSidecar: true, renderedFormat: format))
        return id
    }

    // MARK: Import

    /// Copies an external file into the library under a fresh ID.
    static func importFile(_ url: URL) throws {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let ext = url.pathExtension.lowercased()
        let dest = library.appendingPathComponent(newID() + "." + ext)
        try FileManager.default.copyItem(at: url, to: dest)
    }

    static func importLUT(_ url: URL) throws -> String {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        _ = try CubeLUT(url: url) // validate
        let dest = lutDirectory.appendingPathComponent(url.lastPathComponent)
        try? FileManager.default.removeItem(at: dest)
        try FileManager.default.copyItem(at: url, to: dest)
        return url.lastPathComponent
    }

    static func exportLook(_ look: Look) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(look.name + ".look.json")
        try JSONEncoder().encode(look).write(to: url, options: .atomic)
        return url
    }

    static func importLook(_ url: URL) throws -> Look {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        var look = try JSONDecoder().decode(Look.self, from: Data(contentsOf: url))
        look.id = UUID()
        return look
    }

    static func usedBytes() -> Int64 {
        let files = (try? FileManager.default.contentsOfDirectory(at: library, includingPropertiesForKeys: [.fileSizeKey])) ?? []
        return files.reduce(0) { $0 + Int64((try? $1.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) }
    }
}
