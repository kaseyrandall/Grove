import SwiftUI
import SwiftData
import PhotosUI

/// The main "go find critters" screen: live camera + a shutter button, plus a
/// photo-library fallback so it's fully testable in the Simulator.
struct CatchView: View {
    @Environment(\.modelContext) private var context
    @Query private var allCatches: [Catch]

    @StateObject private var camera = CameraModel()
    @StateObject private var location = LocationProvider()

    @State private var libraryItem: PhotosPickerItem?
    @State private var isIdentifying = false
    @State private var result: CatchResult?

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 20) {
                header

                cameraArea

                controls
            }
            .padding()
        }
        .onAppear {
            camera.start()
            location.requestIfNeeded()
        }
        .onDisappear {
            camera.stop()
            location.stop()
        }
        .onChange(of: libraryItem) { _, newItem in
            guard let newItem else { return }
            Task { await handleLibraryPick(newItem) }
        }
        .sheet(item: $result) { result in
            CatchResultView(result: result)
                .presentationDetents([.large])
        }
    }

    // MARK: Pieces

    private var header: some View {
        VStack(spacing: 2) {
            Text("Popple")
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.accent)
            Text("Snap a critter to add it to your Dex!")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Theme.ink.opacity(0.7))
        }
    }

    private var cameraArea: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Theme.ink.opacity(0.06))

            switch camera.status {
            case .authorized:
                CameraPreview(session: camera.session)
                    .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            case .denied:
                placeholder(
                    emoji: "🚫",
                    text: "Camera access is off.\nEnable it in Settings, or pick a photo below."
                )
            default:
                placeholder(
                    emoji: "📷",
                    text: "Point me at something wild!\n(On Simulator, use Pick from Library.)"
                )
            }

            if isIdentifying {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(.ultraThinMaterial)
                VStack(spacing: 12) {
                    ProgressView().scaleEffect(1.4)
                    Text("Identifying…")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(Theme.ink)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func placeholder(emoji: String, text: String) -> some View {
        VStack(spacing: 12) {
            Text(emoji).font(.system(size: 56))
            Text(text)
                .multilineTextAlignment(.center)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Theme.ink.opacity(0.7))
                .padding(.horizontal)
        }
    }

    private var controls: some View {
        VStack(spacing: 12) {
            PoppleButton(title: "Snap!", systemImage: "camera.fill") {
                capture()
            }
            .disabled(camera.status != .authorized || isIdentifying)
            .opacity(camera.status == .authorized ? 1 : 0.5)

            PhotosPicker(selection: $libraryItem, matching: .images) {
                Label("Pick from Library", systemImage: "photo.on.rectangle")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }
            .disabled(isIdentifying)
        }
    }

    // MARK: Flow

    private func capture() {
        camera.capturePhoto { image in
            guard let image else { return }
            Task { await identify(image) }
        }
    }

    private func handleLibraryPick(_ item: PhotosPickerItem) async {
        libraryItem = nil
        guard
            let data = try? await item.loadTransferable(type: Data.self),
            let image = UIImage(data: data)
        else { return }
        await identify(image)
    }

    @MainActor
    private func identify(_ image: UIImage) async {
        isIdentifying = true
        defer { isIdentifying = false }

        let species = await AnimalClassifier.identify(image)

        let isFirst = !allCatches.contains { $0.speciesID == species.id }
        let sparks = Progression.sparks(for: species, isFirstSighting: isFirst)
        let coord = location.current

        let record = Catch(
            speciesID: species.id,
            sparksEarned: sparks,
            isFirstSighting: isFirst,
            photoData: image.jpegData(compressionQuality: 0.8),
            latitude: coord?.latitude,
            longitude: coord?.longitude
        )
        context.insert(record)
        try? context.save()

        UINotificationFeedbackGenerator().notificationOccurred(.success)
        result = CatchResult(
            species: species,
            sparks: sparks,
            isFirstSighting: isFirst,
            image: image
        )
    }
}

/// Value passed to the celebration sheet.
struct CatchResult: Identifiable {
    let id = UUID()
    let species: Species
    let sparks: Int
    let isFirstSighting: Bool
    let image: UIImage
}

#Preview {
    CatchView()
        .modelContainer(for: Catch.self, inMemory: true)
        .tint(Theme.accent)
        .fontDesign(.rounded)
}
