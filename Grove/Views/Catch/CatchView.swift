import SwiftUI
import SwiftData
import AVFoundation
import PhotosUI
import ImageIO

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
    @State private var noAnimalNotice = false
    @State private var notTodayNotice = false
    @State private var libraryItem: PhotosPickerItem?
    @State private var result: CatchResult?
    @State private var showOptions = false
    @State private var flashOpacity: Double = 0
    @State private var focusPoint: CGPoint?
    @State private var focusToken = UUID()
    @State private var baseZoom: CGFloat = 1.0

    private var lastCatch: Catch? {
        allCatches.filter { $0.photoData != nil }.max { $0.caughtAt < $1.caughtAt }
    }

    var body: some View {
        ZStack {
            // Full-bleed viewfinder (or a friendly placeholder off-device).
            viewfinder
                .ignoresSafeArea()
                .gesture(
                    MagnifyGesture()
                        .onChanged { value in camera.zoom(to: baseZoom * value.magnification) }
                        .onEnded { _ in baseZoom = camera.zoomFactor }
                )

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

            // Shutter flash.
            Color.white
                .opacity(flashOpacity)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            // Gentle nudge when the photo didn't hold an animal.
            if noAnimalNotice {
                noAnimalBanner
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, 68)
                    .padding(.horizontal, 24)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Gentle nudge when an uploaded photo wasn't taken today.
            if notTodayNotice {
                notTodayBanner
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, 68)
                    .padding(.horizontal, 24)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .groveTabBarHidden()
        .onChange(of: libraryItem) { _, newItem in
            guard let newItem else { return }
            Task { await importFromLibrary(newItem) }
        }
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
            if camera.zoomFactor > 1.05 {
                Text(String(format: "%.1f×", camera.zoomFactor))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(.black.opacity(0.45)))
                    .transition(.scale.combined(with: .opacity))
            }
            safetyLine
            HStack {
                // Fixed-size side slots keep the shutter centered even before the
                // camera authorizes (and the flip button appears) or when there's
                // no last catch yet — an empty view alone would collapse to zero.
                sideSlot(alignment: .leading) {
                    if camera.status == .authorized {
                        circleButton("arrow.triangle.2.circlepath") { camera.flip() }
                            .transition(.opacity.combined(with: .scale))
                    }
                }

                Spacer()
                shutterButton
                Spacer()

                // Bottom-right opens the photo library (taken-today only),
                // following the familiar camera pattern: your last catch shows
                // as the thumbnail, or a photos glyph before your first.
                sideSlot(alignment: .trailing) {
                    PhotosPicker(selection: $libraryItem, matching: .images, photoLibrary: .shared()) {
                        Group {
                            if let last = lastCatch, let data = last.photoData, let ui = UIImage(data: data) {
                                Image(uiImage: ui).resizable().scaledToFill()
                            } else {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.system(size: 19, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .background(Color.black.opacity(0.42))
                            }
                        }
                        .frame(width: 46, height: 46)
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(.white.opacity(0.9), lineWidth: 2))
                    }
                    .disabled(isIdentifying)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: camera.status)
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

    /// A fixed 52pt-wide slot flanking the shutter. Always reserves its width so
    /// the shutter stays centered whether or not its content is present yet.
    private func sideSlot<Content: View>(alignment: Alignment, @ViewBuilder content: () -> Content) -> some View {
        Color.clear
            .frame(width: 52, height: 52)
            .overlay(alignment: alignment, content: content)
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

    /// Shown (briefly) when Vision was confident the photo held no animal.
    /// Tapping it — or taking another shot — dismisses it.
    private var noAnimalBanner: some View {
        HStack(spacing: 12) {
            Text("🌿")
                .font(.system(size: 26))
            VStack(alignment: .leading, spacing: 2) {
                Text("No critter in frame")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white)
                Text("Get a little closer and try again.")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.25)) { noAnimalNotice = false }
        }
    }

    /// Shown when an uploaded photo wasn't taken today — keeps Grove real-time.
    private var notTodayBanner: some View {
        HStack(spacing: 12) {
            Text("📅")
                .font(.system(size: 26))
            VStack(alignment: .leading, spacing: 2) {
                Text("From the last day")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white)
                Text("Grove is about what you're spotting now — snap it live, or upload a photo from the last 24 hours.")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.25)) { notTodayNotice = false }
        }
    }

    private func capture() {
        // Clear any lingering nudges — we're trying again.
        if noAnimalNotice || notTodayNotice {
            withAnimation(.easeInOut(duration: 0.25)) {
                noAnimalNotice = false
                notTodayNotice = false
            }
        }
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
        // Blocks a second capture while we work; the celebration sheet slides
        // up the moment we have a result (no separate loading screen).
        isIdentifying = true

        let labels = await AnimalClassifier.classify(image)
        let species = CreatureCatalog.match(labels: labels)

        // Non-animal guard: if Vision gave us labels and none of them look like
        // an animal, don't mint a friend — nudge a retry instead. We only turn
        // a photo away when we're sure (looksLikeAnimal == false); a `nil`
        // ("can't tell", e.g. the Simulator) keeps the friendly Mystery path.
        if species.id == Species.mystery.id,
           CreatureCatalog.looksLikeAnimal(labels: labels) == false {
            if hapticsEnabled { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { noAnimalNotice = true }
            isIdentifying = false
            return
        }

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

    // MARK: Gallery import (recent photos only)

    /// Bring in a photo from the library, keeping Grove's real-time spirit: we
    /// only turn a photo away when its capture date positively shows it's more
    /// than a day old. A photo whose date we can't read (screenshots, stripped
    /// metadata) is let through — better to welcome a genuine recent find than
    /// to block it on missing EXIF.
    @MainActor
    private func importFromLibrary(_ item: PhotosPickerItem) async {
        defer { libraryItem = nil }
        guard !isIdentifying,
              let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }

        let dayOld: TimeInterval = 24 * 60 * 60
        let tooOld = captureDate(from: data).map { Date().timeIntervalSince($0) > dayOld } ?? false
        if tooOld {
            if hapticsEnabled { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                noAnimalNotice = false
                notTodayNotice = true
            }
        } else {
            await identify(image)
        }
    }

    /// The photo's original capture date from its EXIF/TIFF metadata, if present.
    private func captureDate(from data: Data) -> Date? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        else { return nil }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"

        if let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any],
           let string = (exif[kCGImagePropertyExifDateTimeOriginal]
                         ?? exif[kCGImagePropertyExifDateTimeDigitized]) as? String,
           let date = formatter.date(from: string) {
            return date
        }
        if let tiff = props[kCGImagePropertyTIFFDictionary] as? [CFString: Any],
           let string = tiff[kCGImagePropertyTIFFDateTime] as? String,
           let date = formatter.date(from: string) {
            return date
        }
        return nil
    }
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
