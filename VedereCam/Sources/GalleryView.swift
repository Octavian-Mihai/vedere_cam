import SwiftUI
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
                        Thumbnail(url: rec.thumbnailSource)
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
            .sheet(item: $selected) { rec in PhotoDetail(record: rec).environmentObject(model) }
            .onAppear { model.reload() }
        }
    }
}

struct Thumbnail: View {
    let url: URL?
    var body: some View {
        Color.gray.opacity(0.2).aspectRatio(1, contentMode: .fit)
            .overlay { if let img = load() { Image(uiImage: img).resizable().scaledToFill() } }
            .clipped()
    }

    private func load() -> UIImage? {
        guard let url else { return nil }
        if url.pathExtension.lowercased() == "dng" {
            guard let ci = CIRAWFilter(imageURL: url)?.outputImage,
                  let cg = LookEngine.shared.context.createCGImage(ci, from: ci.extent) else { return nil }
            return UIImage(cgImage: cg)
        }
        return UIImage(contentsOfFile: url.path)
    }
}

struct PhotoDetail: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let record: PhotoRecord
    @State private var showOriginal = false
    @State private var share: URL?
    @State private var confirmDeleteOriginal = false

    var body: some View {
        NavigationStack {
            VStack {
                Thumbnail(url: showOriginal ? (record.rawURL ?? record.renderedURL) : (record.renderedURL ?? record.rawURL))
                    .aspectRatio(contentMode: .fit)
                if record.rawURL != nil && record.renderedURL != nil {
                    Picker("", selection: $showOriginal) { Text("Rendered").tag(false); Text("Original").tag(true) }
                        .pickerStyle(.segmented).padding()
                }
                Button("Re-render with current look (\(model.selectedLook.name))") {
                    _ = try? Storage.rerender(record, look: model.selectedLook, format: model.options.renderedFormat)
                    model.reload()
                }.buttonStyle(.bordered)
                HStack {
                    Button("Export") { share = (showOriginal ? record.rawURL : record.renderedURL) ?? record.rawURL ?? record.renderedURL }
                    Button("Delete rendered", role: .destructive) { Storage.delete(record, includingOriginal: false); model.reload(); dismiss() }
                    if record.rawURL != nil {
                        Button("Delete original", role: .destructive) { confirmDeleteOriginal = true }
                    }
                }.padding()
            }
            .navigationTitle(record.id).navigationBarTitleDisplayMode(.inline)
            .sheet(item: $share) { ShareSheet(items: [$0]) }
            .confirmationDialog("Delete the original permanently?", isPresented: $confirmDeleteOriginal, titleVisibility: .visible) {
                Button("Delete everything", role: .destructive) { Storage.delete(record, includingOriginal: true); model.reload(); dismiss() }
            }
        }
    }
}
