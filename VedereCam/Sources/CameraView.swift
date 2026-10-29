import SwiftUI

struct CameraView: View {
    @EnvironmentObject var model: AppModel
    @StateObject private var camera = CaptureService()
    @State private var showEditor = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let cg = camera.previewImage {
                Image(decorative: cg, scale: 1).resizable().scaledToFit()
            } else {
                Text("Camera preview unavailable").foregroundStyle(.secondary)
            }
            VStack {
                if let err = camera.lastError { Text(err).font(.caption).padding(6).background(.red.opacity(0.7), in: Capsule()) }
                Spacer()
                Text(camera.rawSupported ? "RAW" : "Processed only").font(.caption2).foregroundStyle(.white.opacity(0.7))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(model.looks) { look in
                            Button(look.name) { model.selectedLookID = look.id }
                                .buttonStyle(.bordered)
                                .tint(look.id == model.selectedLookID ? .yellow : .gray)
                        }
                    }.padding(.horizontal)
                }
                HStack(spacing: 40) {
                    Button { showEditor = true } label: { Image(systemName: "slider.horizontal.3").font(.title2) }
                    Button {
                        camera.capture { model.reload() }
                    } label: {
                        Circle().strokeBorder(.white, lineWidth: 4).background(Circle().fill(.white.opacity(0.9))).frame(width: 72, height: 72)
                    }
                    Color.clear.frame(width: 28)
                }.padding(.bottom, 12)
            }
        }
        .onAppear { sync(); camera.start() }
        .onDisappear { camera.stop() }
        .onChange(of: model.selectedLookID) { _ in sync() }
        .onChange(of: model.looks) { _ in sync() }
        .onChange(of: model.options) { _ in sync() }
        .sheet(isPresented: $showEditor) { LookEditor().environmentObject(model) }
    }

    private func sync() {
        camera.look = model.selectedLook
        camera.options = model.options
    }
}
