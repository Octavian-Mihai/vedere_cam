import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var model: AppModel

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
                Section("Features") {
                    Toggle("In-app gallery", isOn: model.$galleryEnabled)
                }
                Section("Storage") {
                    Text("Library: \(ByteCountFormatter.string(fromByteCount: Storage.usedBytes(), countStyle: .file))")
                    if let free = freeBytes() { Text("Free on device: \(ByteCountFormatter.string(fromByteCount: free, countStyle: .file))") }
                }
            }
            .navigationTitle("Settings")
        }
    }

    private func freeBytes() -> Int64? {
        try? URL(fileURLWithPath: NSHomeDirectory()).resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]).volumeAvailableCapacityForImportantUsage
    }
}
