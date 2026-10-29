import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var model: AppModel
    @AppStorage("showGrid") private var showGrid = true
    @AppStorage("shutterHaptic") private var shutterHaptic = true
    @AppStorage("rememberLastLook") private var rememberLastLook = true

    var body: some View {
        NavigationStack {
            Form {
                Section("Saved per shot") {
                    Toggle("Original RAW (DNG)", isOn: $model.options.saveRAW)
                    Toggle("Rendered photo (look baked in)", isOn: $model.options.saveRendered)
                    Toggle("Look settings file", isOn: $model.options.saveSidecar)
                    Toggle("Also save rendered to Photos", isOn: $model.options.saveToPhotos)
                    Picker("Rendered format", selection: $model.options.renderedFormat) {
                        ForEach(OutputOptions.RenderedFormat.allCases, id: \.self) { Text($0.rawValue.uppercased()).tag($0) }
                    }
                    Text("≈ \(model.options.estimatedMB, specifier: "%.1f") MB per shot").font(.footnote).foregroundStyle(.secondary)
                }
                Section("Camera") {
                    Toggle("Rule-of-thirds grid", isOn: $showGrid)
                    Toggle("Shutter haptic", isOn: $shutterHaptic)
                    Toggle("Remember last look", isOn: $rememberLastLook)
                }
                Section("Features") {
                    Toggle("In-app gallery", isOn: model.$galleryEnabled)
                }
                Section("Storage") {
                    Text("Library: \(ByteCountFormatter.string(fromByteCount: Storage.usedBytes(), countStyle: .file))")
                    if let free = freeBytes() { Text("Free on device: \(ByteCountFormatter.string(fromByteCount: free, countStyle: .file))") }
                }
                Section("About the looks") {
                    ForEach(model.looks) { look in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(look.name).font(.subheadline.bold())
                            if !look.note.isEmpty { Text(look.note).font(.footnote).foregroundStyle(.secondary) }
                        }
                    }
                    Text("Looks are inspired by classic films, not exact copies. Names follow the LUT files in the pack.")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
        }
    }

    private func freeBytes() -> Int64? {
        try? URL(fileURLWithPath: NSHomeDirectory()).resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]).volumeAvailableCapacityForImportantUsage
    }
}
