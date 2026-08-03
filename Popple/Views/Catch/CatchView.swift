import SwiftUI
import SwiftData
#if DEBUG
import PhotosUI
#endif

/// The main "go find critters" screen: strictly a live camera + shutter button.
/// Catches can only come from a photo taken *right now* — no uploading saved or
/// downloaded images. (In DEBUG builds only, a library picker is available so the
/// loop stays testable in the Simulator, which has no camera. It is compiled out
/// of release builds entirely.)
struct CatchView: View {
    @Environment(\.modelContext) private var context
    @Query private var allCatches: [Catch]

    @StateObject private var camera = CameraModel()
    @StateObject private var location = LocationProvider()

    @State private var isIdentifying = false
    @State private var result: CatchResult?

    #if DEBUG
    @State private var libraryItem: PhotosPickerItem?
    #endif

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
                    text: "Popple needs your camera to catch critters.\nTurn it on in Settings to start snapping."
                )
            case .unavailable:
                placeholder(
                    emoji: "📷",
                    text: "No camera found on this device."
                )
            case .idle:
                placeholder(
                    emoji: "📷",
                    text: "Point me at something wild!"
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
            if camera.status == .denied {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(Theme.accent)
            }
        }
    }

    private var controls: some View {
        VStack(spacing: 12) {
            PoppleButton(title: "Snap!", systemImage: "camera.fill") {
                capture()
            }
            .disabled(camera.status != .authorized || isIdentifying)
            .opacity(camera.status == .authorized ? 1 : 0.5)

            #if DEBUG
            debugLibraryPicker
            #endif
        }
    }

    // MARK: Flow

    private func capture() {
        camera.capturePhoto { image in
            guard let image else { return }
            Task { await identify(image) }
        }
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

        // Snapshot achievements before/after so we can celebrate new unlocks.
        let before = PlayerStats(catches: allCatches)
        context.insert(record)
        try? context.save()
        let after = PlayerStats(catches: allCatches + [record])
        let newAchievements = AchievementCatalog.newlyUnlocked(before: before, after: after)

        UINotificationFeedbackGenerator().notificationOccurred(.success)
        result = CatchResult(
            species: species,
            sparks: sparks,
            isFirstSighting: isFirst,
            image: image,
            newAchievements: newAchievements
        )
    }

    // MARK: Debug-only library import (compiled out of release builds)

    #if DEBUG
    private var debugLibraryPicker: some View {
        PhotosPicker(selection: $libraryItem, matching: .images) {
            Label("DEBUG: Pick from Library", systemImage: "ladybug")
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(Theme.ink.opacity(0.5))
        }
        .disabled(isIdentifying)
        .onChange(of: libraryItem) { _, newItem in
            guard let newItem else { return }
            Task {
                defer { libraryItem = nil }
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await identify(image)
                }
            }
        }
    }
    #endif
}

/// Value passed to the celebration sheet.
struct CatchResult: Identifiable {
    let id = UUID()
    let species: Species
    let sparks: Int
    let isFirstSighting: Bool
    let image: UIImage
    let newAchievements: [Achievement]
}

#Preview {
    CatchView()
        .modelContainer(for: Catch.self, inMemory: true)
        .tint(Theme.accent)
        .fontDesign(.rounded)
}
