import SwiftUI
import UniformTypeIdentifiers

struct LookEditor: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var tab: Tab = .lightness
    @State private var mixColor: MixColor = .orange
    @State private var importingLUT = false
    @State private var importingLook = false
    @State private var shareURL: URL?
    @State private var message: String?

    enum Tab: String, CaseIterable, Identifiable {
        case lightness = "Lightness", color = "Color", mix = "Mix", effects = "Effects"
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: bind(\.name))
                    if !model.selectedLook.note.isEmpty {
                        Text(model.selectedLook.note).font(.footnote).foregroundStyle(.secondary)
                    }
                    slider("Strength", bind(\.strength), 0...1)
                    Picker("", selection: $tab) { ForEach(Tab.allCases) { Text($0.rawValue).tag($0) } }
                        .pickerStyle(.segmented)
                }
                switch tab {
                case .lightness: lightness
                case .color: color
                case .mix: mixTab
                case .effects: effects
                }
                Section("Manage") {
                    Button("Reset look") { resetLook() }
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
                handle(result) { url in model.selectedLook.lutFilename = try Storage.importLUT(url) }
            }
            .fileImporter(isPresented: $importingLook, allowedContentTypes: [.json]) { result in
                handle(result) { url in model.addLook(try Storage.importLook(url)) }
            }
            .sheet(item: $shareURL) { url in ShareSheet(items: [url]) }
        }
    }

    // MARK: Tabs

    @ViewBuilder private var lightness: some View {
        Section("Lightness") {
            slider("Exposure (EV)", bind(\.exposure), -2...2)
            slider("Contrast", bind(\.contrast), 0.5...1.5)
            slider("Highlights", bind(\.highlights), -1...1)
            slider("Shadows", bind(\.shadows), -1...1)
        }
    }

    @ViewBuilder private var color: some View {
        Section("Color") {
            slider("Saturation", bind(\.saturation), 0...2)
            slider("Warmth", bind(\.temperatureShift), -1500...1500)
            slider("Tint", bind(\.tint), -100...100)
        }
    }

    @ViewBuilder private var mixTab: some View {
        Section("Mix") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(MixColor.allCases, id: \.self) { c in
                        Button(c.title) { mixColor = c }
                            .buttonStyle(.bordered)
                            .tint(c == mixColor ? swatch(c) : .gray)
                    }
                }
            }
            slider("Hue", mixBinding(\.hue), -100...100)
            slider("Saturation", mixBinding(\.saturation), -100...100)
            slider("Luminance", mixBinding(\.luminance), -100...100)
            Text("Tip: for flat, greenish skin tones try Orange: Hue −40, Saturation +57.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var effects: some View {
        Section("Texture") {
            slider("Sharpness", bind(\.sharpness), 0...2)
            slider("Grain", bind(\.grain), 0...1)
            slider("Grain size", bind(\.grainSize), 0.5...3)
        }
        Section("LUT") {
            Text(model.selectedLook.lutFilename ?? "None")
            Button("Import .cube LUT") { importingLUT = true }
            if model.selectedLook.lutFilename != nil {
                slider("LUT intensity", bind(\.lutIntensity), 0...1)
                Button("Remove LUT", role: .destructive) { model.selectedLook.lutFilename = nil }
            }
        }
    }

    // MARK: Helpers

    private func bind<T>(_ keyPath: WritableKeyPath<Look, T>) -> Binding<T> {
        Binding(get: { model.selectedLook[keyPath: keyPath] },
                set: { var l = model.selectedLook; l[keyPath: keyPath] = $0; model.selectedLook = l })
    }

    private func mixBinding(_ keyPath: WritableKeyPath<ChannelMix, Double>) -> Binding<Double> {
        Binding(get: { model.selectedLook.channel(mixColor)[keyPath: keyPath] },
                set: { value in
                    var l = model.selectedLook
                    var ch = l.channel(mixColor)
                    ch[keyPath: keyPath] = value
                    l.setChannel(mixColor, ch)
                    model.selectedLook = l
                })
    }

    private func slider(_ title: String, _ value: Binding<Double>, _ range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading) {
            Text("\(title): \(value.wrappedValue, specifier: "%.2f")").font(.caption)
            Slider(value: value, in: range)
        }
    }

    private func swatch(_ c: MixColor) -> Color {
        Color(hue: c.centerHue / 360, saturation: 0.8, brightness: 0.9)
    }

    /// Resets edits but keeps the look's identity, name and LUT.
    private func resetLook() {
        var l = Look(name: model.selectedLook.name, note: model.selectedLook.note, lutFilename: model.selectedLook.lutFilename)
        l.id = model.selectedLook.id
        model.selectedLook = l
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
