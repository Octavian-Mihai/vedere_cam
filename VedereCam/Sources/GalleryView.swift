import SwiftUI
import ImageIO
import UniformTypeIdentifiers

struct GalleryView: View {
    @EnvironmentObject var model: AppModel
    @State private var importing = false
    @State private var selected: PhotoRecord?

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 2)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(model.records) { rec in
                        PhotoImage(url: rec.thumbnailSource, maxPixel: 300, square: true)
                            .overlay(alignment: .bottomTrailing) {
                                if rec.rawURL != nil { Text("RAW").font(.system(size: 9, weight: .bold)).padding(3).background(.black.opacity(0.6)).foregroundStyle(.white) }
                            }
                            .onTapGesture { selected = rec }
                    }
                }
            }
            .navigationTitle("Gallery")
            .toolbar { Button { importing = true } label: { Image(systemName: "square.and.arrow.down") } }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.image, UTType(filenameExtension: "dng") ?? .image], allowsMultipleSelection: true) { result in
                for url in (try? result.get()) ?? [] { try? Storage.importFile(url) }
                model.reload()
            }
            .sheet(item: $selected) { rec in PhotoDetail(initial: rec).environmentObject(model) }
            .onAppear { model.reload() }
        }
    }
}

/// Downsampled, cached image loading via ImageIO. Avoids decoding full RAW files on the main thread.
enum ImageLoader {
    private static let cache = NSCache<NSString, UIImage>()

    static func key(_ url: URL, _ maxPixel: Int) -> String {
        let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)?.timeIntervalSince1970 ?? 0
        return "\(url.path)|\(date)|\(maxPixel)"
    }

    static func load(_ url: URL, maxPixel: Int) async -> UIImage? {
        let k = key(url, maxPixel) as NSString
        if let hit = cache.object(forKey: k) { return hit }
        let image: UIImage? = await Task.detached(priority: .utility) {
            guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
            let opts: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixel,
                kCGImageSourceCreateThumbnailWithTransform: true
            ]
            return CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary).map { UIImage(cgImage: $0) }
        }.value
        if let image { cache.setObject(image, forKey: k) }
        return image
    }
}

struct PhotoImage: View {
    let url: URL?
    let maxPixel: Int
    let square: Bool
    @State private var image: UIImage?

    var body: some View {
        content
            .task(id: url.map { ImageLoader.key($0, maxPixel) } ?? "") {
                guard let url else { image = nil; return }
                image = await ImageLoader.load(url, maxPixel: maxPixel)
            }
    }

    @ViewBuilder private var content: some View {
        if square {
            Color.gray.opacity(0.2).aspectRatio(1, contentMode: .fit)
                .overlay { if let image { Image(uiImage: image).resizable().scaledToFill() } }
                .clipped()
        } else if let image {
            Image(uiImage: image).resizable().scaledToFit()
        } else {
            Color.gray.opacity(0.2)
        }
    }
}

struct PhotoDetail: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let initial: PhotoRecord
    @State private var showOriginal = false
    @State private var share: URL?
    @State private var confirmDeleteOriginal = false
    @State private var appliedLook: String?
    @State private var message: String?

    private var record: PhotoRecord { model.records.first { $0.id == initial.id } ?? initial }

    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                PhotoImage(url: showOriginal ? (record.rawURL ?? record.renderedURL) : (record.renderedURL ?? record.rawURL),
                           maxPixel: 2400, square: false)
                if record.rawURL != nil && record.renderedURL != nil {
                    Picker("", selection: $showOriginal) { Text("Rendered").tag(false); Text("Original").tag(true) }
                        .pickerStyle(.segmented).padding(.horizontal)
                }
                // One-tap preset picker: re-renders from the original without touching it.
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(model.looks) { look in
                            Button(look.name) { apply(look) }
                                .buttonStyle(.bordered)
                                .tint(look.name == appliedLook ? .yellow : .gray)
                        }
                    }.padding(.horizontal)
                }
                if let message { Text(message).font(.footnote).foregroundStyle(.secondary) }
                HStack {
                    Button("Export") { share = (showOriginal ? record.rawURL : record.renderedURL) ?? record.rawURL ?? record.renderedURL }
                    Button("Delete rendered", role: .destructive) { Storage.delete(record, includingOriginal: false); model.reload(); dismiss() }
                    if record.rawURL != nil {
                        Button("Delete original", role: .destructive) { confirmDeleteOriginal = true }
                    }
                }.padding(.bottom)
            }
            .navigationTitle(record.id).navigationBarTitleDisplayMode(.inline)
            .onAppear { appliedLook = Storage.loadLook(for: record)?.name }
            .sheet(item: $share) { ShareSheet(items: [$0]) }
            .confirmationDialog("Delete the original permanently?", isPresented: $confirmDeleteOriginal, titleVisibility: .visible) {
                Button("Delete everything", role: .destructive) { Storage.delete(record, includingOriginal: true); model.reload(); dismiss() }
            }
        }
    }

    private func apply(_ look: Look) {
        do {
            let hadRAW = record.rawURL != nil
            try Storage.rerender(record, look: look, format: model.options.renderedFormat)
            model.reload()
            appliedLook = look.name
            message = hadRAW ? nil : "Saved as a new copy (no original to re-render from)."
            showOriginal = false
        } catch {
            message = "Couldn't apply look: \(error.localizedDescription)"
        }
    }
}
