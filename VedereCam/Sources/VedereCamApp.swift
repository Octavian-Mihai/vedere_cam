import SwiftUI

@main
struct VedereCamApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            TabView {
                CameraView().tabItem { Label("Camera", systemImage: "camera") }
                if model.galleryEnabled {
                    GalleryView().tabItem { Label("Gallery", systemImage: "photo.on.rectangle") }
                }
                SettingsView().tabItem { Label("Settings", systemImage: "gearshape") }
            }
            .environmentObject(model)
        }
    }
}
