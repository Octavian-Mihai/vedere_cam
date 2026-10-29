import SwiftUI
import UniformTypeIdentifiers

struct LookEditor: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var importingLUT = false
    @State private var importingLook = false
    @State private var shareURL: URL?
    @State private var message: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Look") {
                    TextField("Name", text: bind(\.name))
                    slider("Exposure (EV)", bind(\.exposure), -2...2)
                    slider("Contrast", bind(\.contrast), 0.5...1.5)
                    slider("Saturation", bind(\.saturation), 0...2)
                    slider("Warmth", bind(\.temperatureShift), -1500...1500)
                }
                Section("Texture") {
                    slider("Sharpness", bind(\.sharpness), 0...2)
                    slider("Grain", bind(\.grain), 0...1)
                    slider("Grain size", bind(\.grainSize), 0.5...3)
                }
                Section("LUT") {
                    Text(model.selectedLook.lutFilename ?? "None")
                    Button("Import .cube LUT") { importingLUT = true }
                    if model.selectedLook.lutFilename != nil {
                        slider("Intensity", bind(\.lutIntensity), 0...1)
                        Button("Remove LUT", role: .destructive) { model.selectedLook.lutFilename = nil }
                    }
                }
                Section("Manage") {
                    Button("Duplicate as new look") {
                        var copy = model.selectedLook; copy.id = UUID(); copy.name += " copy"; model.addLook(copy)
                    }
                    Button("Export look file") { exportLook() }
                    Button("Import look file") { importingLook = true }
                }
                if let message { Section { Text(message).font(.footnote) } }
            }
            .navigationTitle("Edit look")
            .toolbar { Button("Done") { dismiss() } }
            .fileImporter(isPresented: $importingLUT, allowedContentTypes: [UTType(filenameExtension: "cube") ?? .data]) { result in
                handle(result) { url in
                    model.selectedLook.lutFilename = try Storage.importLUT(url)
                }
            }
            .fileImporter(isPresented: $importingLook, allowedContentTypes: [.json]) { result in
                handle(result) { url in model.addLook(try Storage.importLook(url)) }
            }
            .sheet(item: $shareURL) { url in ShareSheet(items: [url]) }
        }
    }

    private func bind<T>(_ keyPath: WritableKeyPath<Look, T>) -> Binding<T> {
        Binding(get: { model.selectedLook[keyPath: keyPath] },
                set: { var l = model.selectedLook; l[keyPath: keyPath] = $0; model.selectedLook = l })
    }

    private func slider(_ title: String, _ value: Binding<Double>, _ range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading) {
            Text("\(title): \(value.wrappedValue, specifier: "%.2f")").font(.caption)
            Slider(value: value, in: range)
        }
    }

    private func handle(_ result: Result<URL, Error>, _ action: (URL) throws -> Void) {
        do { try action(try result.get()); message = nil } catch { message = "Import failed: \(error.localizedDescription)" }
    }

    private func exportLook() {
        do { shareURL = try Storage.exportLook(model.selectedLook) } catch { message = error.localizedDescription }
    }
}

extension URL: Identifiable { public var id: String { absoluteString } }

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: items, applicationActivities: nil) }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
