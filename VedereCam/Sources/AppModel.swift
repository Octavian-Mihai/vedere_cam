import SwiftUI

/// Shared app state: selected look, saved looks, output options, library records.
final class AppModel: ObservableObject {
    @Published var looks: [Look] = Look.builtIn
    @Published var selectedLookID: UUID = Look.neutral.id
    @Published var options: OutputOptions { didSet { persistOptions() } }
    @Published var records: [PhotoRecord] = []

    @AppStorage("galleryEnabled") var galleryEnabled = true

    var selectedLook: Look {
        get { looks.first { $0.id == selectedLookID } ?? .neutral }
        set { if let i = looks.firstIndex(where: { $0.id == newValue.id }) { looks[i] = newValue } }
    }

    init() {
        if let d = UserDefaults.standard.data(forKey: "options"),
           let o = try? JSONDecoder().decode(OutputOptions.self, from: d) { options = o } else { options = OutputOptions() }
        selectedLookID = looks.first?.id ?? Look.neutral.id
        reload()
    }

    func reload() { records = Storage.loadRecords() }

    func addLook(_ look: Look) { looks.append(look); selectedLookID = look.id }

    private func persistOptions() {
        if let d = try? JSONEncoder().encode(options) { UserDefaults.standard.set(d, forKey: "options") }
    }
}
