import SwiftUI
import SwiftData
import AVFoundation
#if DEBUG
import PhotosUI
#endif

/// The main "go find friends" screen: a full-bleed, immersive camera. A catch
/// can only come from a photo taken *right now* — no uploading saved or
/// downloaded images. (In DEBUG builds only, a library picker is available so
/// the loop stays testable in the Simulator, which has no camera. It is
/// compiled out of release builds entirely.)
struct CatchView: View {
    /// Called when the player leaves the flow — the root slides to the Grove.
    /// Used by both the close button and the celebration's "Add to my Grove".
    var onFinished: () -> Void = {}

    @Environment(\.modelContext) private var context
    @Query private var allCatches: [Catch]

    @StateObject private var camera = CameraModel()
    @StateObject private var location = LocationProvider()

    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @AppStorage("locationTaggingEnabled") private var locationTaggingEnabled = true
    @AppStorage("cameraGridEnabled") private var gridOn = false

    @State private var isIdentifying = false
    @State private var result: CatchResult?
    @State private var showOptions = false
    @State private var flashOpacity: Double = 0
    @State private var focusPoint: CGPoint?
    @State private var focusToken = UUID()

    #if DEBUG
    @State private var libraryItem: PhotosPickerItem?
    #endif

    private var lastCatch: Catch? {
        allCatches.filter { $0.photoData != nil }.max { $0.caughtAt < $1.caughtAt }
    }

    var body: some View {
        ZStack {
            // Full-bleed viewfinder (or a friendly placeholder off-device).
            viewfinder
                .ignoresSafeArea()

            // Controls live inside the safe area so nothing hides behind the
            // Dynamic Island or the home indicator.
            VStack(spacing: 0) {
                topBar
                Spacer()
                bottomControls
            }
            .padding(.horizontal, 18)
            .padding(.top, 6)
            .padding(.bottom, 14)

            // The cozy "who's this?" moment while Grove works it out.
            if isIdentifying {
                IdentifyingOverlay()
                    .ignoresSafeArea()
                    .transition(.opacity)
            }

            // Shutter flash.
            Color.white
                .opacity(flashOpacity)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
        .groveTabBarHidden()
        .onAppear {
            camera.start()
            if locationTaggingEnabled { location.requestIfNeeded() }
        }
        .onDisappear {
            camera.stop()
            location.stop()
        }
        .sheet(item: $result, onDismiss: { isIdentifying = false }) { result in
            CatchResultView(result: result, onDone: {
                self.result = nil
                onFinished()
            })
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showOptions) {
            CameraOptionsSheet(
                flashMode: $camera.flashMode,
                gridOn: $gridOn,
                locationTagging: $locationTaggingEnabled
            )
        }
    }

    // MARK: Viewfinder

    private var viewfinder: some View {
        ZStack {
            Color.black

            switch camera.status {
            case .authorized:
                CameraPreview(session: camera.session) { layerPoint, devicePoint in
                    camera.focus(at: devicePoint)
                    showFocus(at: layerPoint)
                }
            case .denied:
                placeholder("🚫", "Grove needs your camera to meet friends.\nTurn it on in Settings to start snapping.", showSettings: true)
            case .unavailable:
                placeholder("📷", "No camera on this device.")
            case .idle:
                placeholder("🌿", "Warming up the lens…")
            }

            if gridOn { GridOverlay() }

            // Legibility scrims behind the top and bottom controls.
            VStack {
                LinearGradient(colors: [.black.opacity(0.45), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 150)
                Spacer()
                LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 240)
            }
            .allowsHitTesting(false)

            if let point = focusPoint {
                FocusReticle()
                    .id(focusToken)
                    .position(point)
                    .allowsHitTesting(false)
            }
        }
    }

    private func placeholder(_ emoji: String, _ text: String, showSettings: Bool = false) -> some View {
        VStack(spacing: 14) {
            Text(emoji).font(.system(size: 58))
            Text(text)
                .multilineTextAlignment(.center)
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 40)
            if showSettings {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(Theme.blush)
            }
        }
    }

    // MARK: Controls

    private var topBar: some View {
        HStack {
            circleButton("xmark") { onFinished() }
            Spacer()
            circleButton("slider.horizontal.3") { showOptions = true }
        }
    }

    private var bottomControls: some View {
        VStack(spacing: 14) {
            safetyLine
            HStack {
                Group {
                    if camera.status == .authorized {
                        circleButton("arrow.triangle.2.circlepath") { camera.flip() }
                    }
                }
                .frame(width: 52, alignment: .leading)

                Spacer()
                shutterButton
                Spacer()

                Group {
                    if let last = lastCatch, let data = last.photoData, let ui = UIImage(data: data) {
                        Button { onFinished() } label: {
                            Image(uiImage: ui)
                                .resizable().scaledToFill()
                                .frame(width: 46, height: 46)
                                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(.white, lineWidth: 2))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(width: 52, alignment: .trailing)
            }

            #if DEBUG
            debugLibraryPicker
            #endif
        }
    }

    private var safetyLine: some View {
        HStack(spacing: 7) {
            Image(systemName: "shield.lefthalf.filled")
            Text("Keep your distance · mind your surroundings")
        }
        .font(.system(size: 11.5, weight: .bold, design: .rounded))
        .foregroundStyle(Theme.gold)
        .padding(.horizontal, 13)
        .padding(.vertical, 6)
        .background(Capsule().fill(.black.opacity(0.42)))
    }

    private var shutterButton: some View {
        Button(action: capture) {
            ZStack {
                Circle().strokeBorder(.white, lineWidth: 4).frame(width: 78, height: 78)
                Circle().fill(Theme.accent).frame(width: 60, height: 60)
                    .shadow(color: Theme.accent.opacity(0.5), radius: 8, y: 3)
                Image(systemName: "camera.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(BouncyButtonStyle())
        .disabled(camera.status != .authorized || isIdentifying)
        .opacity(camera.status == .authorized ? 1 : 0.45)
    }

    private func circleButton(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(Circle().fill(.black.opacity(0.42)))
        }
        .buttonStyle(.plain)
    }

    // MARK: Flow

    private func showFocus(at point: CGPoint) {
        focusPoint = point
        let token = UUID()
        focusToken = token
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            if focusToken == token {
                withAnimation(.easeOut(duration: 0.25)) { focusPoint = nil }
            }
        }
    }

    private func capture() {
        flashOpacity = 0.9
        withAnimation(.easeOut(duration: 0.4)) { flashOpacity = 0 }
        if hapticsEnabled { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }

        camera.capturePhoto { image in
            guard let image else { return }
            Task { await identify(image) }
        }
    }

    @MainActor
    private func identify(_ image: UIImage) async {
        withAnimation(.easeIn(duration: 0.2)) { isIdentifying = true }

        let labels = await AnimalClassifier.classify(image)
        let species = CreatureCatalog.match(labels: labels)

        let isFirst = !allCatches.contains { $0.speciesID == species.id }
        let sparks = Progression.sparks(for: species, isFirstSighting: isFirst)
        let coord = locationTaggingEnabled ? location.current : nil

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

        // Auto-tag where we met them, in the background.
        if let coord {
            Task { @MainActor in
                if let place = await Geocoder.placeName(latitude: coord.latitude, longitude: coord.longitude) {
                    record.placeName = place
                    try? context.save()
                }
            }
        }

        if hapticsEnabled {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        result = CatchResult(
            record: record,
            species: species,
            sparks: sparks,
            isFirstSighting: isFirst,
            image: image,
            newAchievements: newAchievements,
            visionLabels: labels
        )
    }

    // MARK: Debug-only library import (compiled out of release builds)

    #if DEBUG
    private var debugLibraryPicker: some View {
        PhotosPicker(selection: $libraryItem, matching: .images) {
            Label("DEBUG: Pick from Library", systemImage: "ladybug")
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
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
    let record: Catch
    let species: Species
    let sparks: Int
    let isFirstSighting: Bool
    let image: UIImage
    let newAchievements: [Achievement]
    /// Raw Vision labels for this photo — used for the DEBUG identification readout.
    var visionLabels: [String] = []
}

// MARK: - Cozy "identifying" moment

/// Grove peeking through its field guide: a wiggly magnifier looking over animal
/// emojis flipping by, over a warm wash. Deliberately hand-made and playful —
/// the opposite of a clinical scanner.
private struct IdentifyingOverlay: View {
    private let animals = ["🐿️", "🦊", "🐦", "🦆", "🐰", "🦋", "🐢", "🦉", "🐾", "🦌"]
    @State private var bob = false
    @State private var wiggle = false

    var body: some View {
        ZStack {
            RadialGradient(
                gradient: Gradient(colors: [Theme.cream.opacity(0.55), Theme.blush.opacity(0.42), .black.opacity(0.5)]),
                center: UnitPoint(x: 0.5, y: 0.42), startRadius: 20, endRadius: 480
            )

            VStack(spacing: 20) {
                ZStack {
                    Circle().fill(Theme.cream)
                        .frame(width: 106, height: 106)
                        .shadow(color: .black.opacity(0.28), radius: 14, y: 8)
                    TimelineView(.periodic(from: .now, by: 0.12)) { context in
                        let i = Int(context.date.timeIntervalSinceReferenceDate / 0.12) % animals.count
                        Text(animals[i]).font(.system(size: 50))
                    }
                    Text("🔍")
                        .font(.system(size: 28))
                        .rotationEffect(.degrees(wiggle ? 10 : -14))
                        .offset(x: 34, y: 34)
                }
                .offset(y: bob ? -7 : 0)

                Text("Who's this friend?")
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.4), radius: 8, y: 2)
            }

            SparkleFloat(emoji: "✨", delay: 0).offset(x: -72, y: -58)
            SparkleFloat(emoji: "🌿", delay: 0.5).offset(x: 66, y: -30)
            SparkleFloat(emoji: "✨", delay: 1.0).offset(x: 24, y: -96)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { bob = true }
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) { wiggle = true }
        }
    }
}

private struct SparkleFloat: View {
    let emoji: String
    let delay: Double
    @State private var up = false

    var body: some View {
        Text(emoji)
            .font(.system(size: 18))
            .opacity(up ? 0 : 0.9)
            .offset(y: up ? -22 : 6)
            .onAppear {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: false).delay(delay)) { up = true }
            }
    }
}

// MARK: - Viewfinder chrome

private struct GridOverlay: View {
    var body: some View {
        GeometryReader { geo in
            Path { p in
                let w = geo.size.width, h = geo.size.height
                for i in 1...2 {
                    let x = w * CGFloat(i) / 3
                    p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: h))
                    let y = h * CGFloat(i) / 3
                    p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: w, y: y))
                }
            }
            .stroke(Color.white.opacity(0.28), lineWidth: 0.6)
        }
        .allowsHitTesting(false)
    }
}

private struct FocusReticle: View {
    @State private var appear = false
    var body: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .stroke(Theme.gold, lineWidth: 2)
            .frame(width: 74, height: 74)
            .scaleEffect(appear ? 1 : 1.4)
            .opacity(appear ? 1 : 0)
            .onAppear { withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { appear = true } }
    }
}

#Preview {
    CatchView()
        .modelContainer(for: Catch.self, inMemory: true)
        .tint(Theme.accent)
        .fontDesign(.rounded)
}
