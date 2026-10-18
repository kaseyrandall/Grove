import SwiftUI
import SwiftData
import AVFoundation
import PhotosUI
import ImageIO
import CoreLocation

/// The main "go find friends" screen: a full-bleed, immersive camera, plus
/// the photo library (bottom-right) for friends you've already snapped, from
/// any date.
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
    @State private var uploadIssue: UploadIssue?
    @State private var libraryItem: PhotosPickerItem?
    @State private var result: CatchResult?
    /// The open Duo in landscape (the celebration opens full screen there).
    @Environment(\.groveIsSpread) private var isSpread
    /// The Duo half-folded like a tiny laptop: viewfinder up top, a control
    /// deck on the bottom half (see `halfFoldLayout`).
    @Environment(\.groveFold) private var fold
    @State private var windowSize: CGSize = .zero
    private var isLaptopPose: Bool { fold.isHalfFolded && windowSize.height > windowSize.width }
    /// Self-timer for the half-fold deck: 0 (off), 3 or 10 seconds.
    @AppStorage("cameraTimerSeconds") private var timerSeconds = 0
    /// The countdown in progress, if any.
    @State private var countdown: Int?
    @State private var countdownTask: Task<Void, Never>?
    @State private var showOptions = false
    @State private var flashOpacity: Double = 0
    @State private var focusPoint: CGPoint?
    @State private var focusToken = UUID()
    @State private var baseZoom: CGFloat = 1.0
    /// True while a pinch is in progress, so the camera setting its own zoom
    /// (on open / flip) doesn't clobber the pinch base mid-gesture.
    @GestureState private var isPinching = false

    private var lastCatch: Catch? {
        allCatches.filter { $0.photoData != nil }.max { $0.caughtAt < $1.caughtAt }
    }

    var body: some View {
        Group {
            if isLaptopPose { halfFoldLayout } else { standardLayout }
        }
        .onGeometryChange(for: CGSize.self) { proxy in
            let insets = proxy.safeAreaInsets
            return CGSize(width: proxy.size.width + insets.leading + insets.trailing,
                          height: proxy.size.height + insets.top + insets.bottom)
        } action: { windowSize = $0 }
        .onChange(of: isLaptopPose) { _, _ in cancelCountdown() }
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
        .sheet(item: isSpread ? .constant(nil) : $result, onDismiss: { isIdentifying = false }) { result in
            CatchResultView(result: result, onDone: {
                self.result = nil
                ReviewPrompt.shared.catchFinished()
                onFinished()
            })
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        // On the open Duo the celebration takes the whole screen as a two-page
        // spread (a sheet would be a small centered card there).
        .fullScreenCover(item: isSpread ? $result : .constant(nil), onDismiss: { isIdentifying = false }) { result in
            CatchResultView(result: result, onDone: {
                self.result = nil
                ReviewPrompt.shared.catchFinished()
                onFinished()
            })
        }
        #if DEBUG
        // Test hook: `-GroveStartTimer` starts a 3-second self-timer.
        .task {
            guard ProcessInfo.processInfo.arguments.contains("-GroveStartTimer") else { return }
            try? await Task.sleep(for: .milliseconds(1500))
            timerSeconds = 3
            snapWithTimer()
        }
        // Test hook: `-GroveShowCatchResult` shows the celebration for one of
        // your sample friends, as a not-yet-named Mystery Friend.
        .task {
            guard ProcessInfo.processInfo.arguments.contains("-GroveShowCatchResult") else { return }
            try? await Task.sleep(for: .milliseconds(800))
            if let friend = allCatches.first(where: { $0.photoData != nil }),
               let data = friend.photoData, let image = UIImage(data: data) {
                // `-GroveSampleAchievements <n>` adds n sample badges (3 if no
                // number); `-GroveCatchNamed` shows the friend as already named
                // (its kind, sparks and first-find from the store) instead of
                // as a Mystery Friend.
                let args = ProcessInfo.processInfo.arguments
                var samples: [Achievement] = []
                if let i = args.firstIndex(of: "-GroveSampleAchievements") {
                    let n = (i + 1 < args.count ? Int(args[i + 1]) : nil) ?? 3
                    samples = Array(AchievementCatalog.all.prefix(n))
                }
                let named = args.contains("-GroveCatchNamed")
                result = CatchResult(record: friend,
                                     species: named ? friend.species : .mystery,
                                     sparks: named ? friend.sparksEarned : Progression.snapSparks,
                                     isFirstSighting: named && friend.isFirstSighting,
                                     image: image, newAchievements: samples)
            }
        }
        #endif
        .sheet(isPresented: $showOptions) {
            CameraOptionsSheet(
                flashMode: $camera.flashMode,
                gridOn: $gridOn,
                locationTagging: $locationTaggingEnabled
            )
        }
        .alert(uploadIssue?.title ?? "", isPresented: Binding(
            get: { uploadIssue != nil },
            set: { if !$0 { uploadIssue = nil } }
        ), presenting: uploadIssue) { _ in
            Button("Got it", role: .cancel) {}
        } message: { issue in
            Text(issue.message)
        }
    }

    private var standardLayout: some View {
        ZStack {
            // Full-bleed viewfinder (or a friendly placeholder off-device).
            viewfinder
                .ignoresSafeArea()
                .gesture(
                    MagnifyGesture()
                        .updating($isPinching) { _, state, _ in state = true }
                        .onChanged { value in camera.zoom(to: baseZoom * value.magnification) }
                        .onEnded { _ in baseZoom = camera.zoomFactor }
                )
                // Keep the pinch base aligned with the camera's own zoom changes
                // (initial open at native 1×, or a flip) when not actively pinching.
                .onChange(of: camera.zoomFactor) { _, newValue in
                    if !isPinching { baseZoom = newValue }
                }

            // Controls live inside the safe area so nothing hides behind the
            // Dynamic Island or the home indicator.
            if isSpread {
                spreadControls
            } else {
                VStack(spacing: 0) {
                    topBar
                    Spacer()
                    bottomControls
                }
                .padding(.horizontal, 18)
                .padding(.top, 6)
                .padding(.bottom, 14)
            }

            // Shutter flash.
            Color.white
                .opacity(flashOpacity)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
    }

    // MARK: Viewfinder

    #if DEBUG
    /// Test hook for screenshots in the simulator (which has no camera):
    /// `-GroveCameraBackdrop <image path>` fills the viewfinder with that photo
    /// and shows the controls as they'd be with a live camera.
    private static let debugBackdrop: UIImage? = {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-GroveCameraBackdrop"), i + 1 < args.count else { return nil }
        return UIImage(contentsOfFile: args[i + 1])
    }()
    #endif

    /// Whether the camera-only controls (flip) should show.
    private var cameraIsLive: Bool {
        #if DEBUG
        if Self.debugBackdrop != nil { return true }
        #endif
        return camera.status == .authorized
    }

    private var viewfinder: some View {
        ZStack {
            Color.black

            cameraLayer

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

    /// The live camera, or a friendly placeholder when there isn't one.
    @ViewBuilder private var cameraLayer: some View {
        #if DEBUG
        if let backdrop = Self.debugBackdrop {
            // In an overlay so the photo fills the viewfinder without
            // stretching the layout around it.
            Color.clear
                .overlay { Image(uiImage: backdrop).resizable().scaledToFill() }
                .clipped()
        } else {
            liveCameraLayer
        }
        #else
        liveCameraLayer
        #endif
    }

    @ViewBuilder private var liveCameraLayer: some View {
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

    // MARK: Half-fold (iPhone Duo)

    /// The Duo stood up like a tiny laptop: the viewfinder fills the top half
    /// and the bottom half becomes a control deck you can tap anywhere to
    /// snap, so you never have to hold (and shake) the phone.
    private var halfFoldLayout: some View {
        GeometryReader { geo in
            let full = geo.size.height + geo.safeAreaInsets.top + geo.safeAreaInsets.bottom
            let top = full / 2 - geo.safeAreaInsets.top
            VStack(spacing: 0) {
                ZStack {
                    viewfinder
                        .gesture(
                            MagnifyGesture()
                                .updating($isPinching) { _, state, _ in state = true }
                                .onChanged { value in camera.zoom(to: baseZoom * value.magnification) }
                                .onEnded { _ in baseZoom = camera.zoomFactor }
                        )
                    VStack {
                        topBar
                        Spacer()
                        safetyLine
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, geo.safeAreaInsets.top + 6)
                    .padding(.bottom, 14)
                    if let countdown {
                        Text("\(countdown)")
                            .font(.system(size: 120, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.4), radius: 12)
                            .contentTransition(.numericText(countsDown: true))
                            .transition(.scale.combined(with: .opacity))
                    }
                    Color.white.opacity(flashOpacity).allowsHitTesting(false)
                }
                .frame(height: top + geo.safeAreaInsets.top)
                .clipped()

                controlDeck
                    .padding(.bottom, geo.safeAreaInsets.bottom)
                    .frame(maxHeight: .infinity)
            }
            .ignoresSafeArea()
        }
        .background(Color.black.ignoresSafeArea())
        .onChange(of: camera.zoomFactor) { _, newValue in
            if !isPinching { baseZoom = newValue }
        }
    }

    /// The bottom half: lenses, a big shutter between the library and flip,
    /// and the self-timer. A tap anywhere else on the deck snaps too.
    private var controlDeck: some View {
        ZStack {
            Color(hex: 0x16211A)
                .contentShape(Rectangle())
                .onTapGesture { snapWithTimer() }
                .accessibilityHidden(true)

            VStack(spacing: 22) {
                if lensStops.count > 1 { lensButtons(vertical: false) }

                HStack(spacing: 44) {
                    libraryButton
                    Button { snapWithTimer() } label: {
                        ZStack {
                            Circle().strokeBorder(.white, lineWidth: 5).frame(width: 104, height: 104)
                            Circle().fill(Theme.accent).frame(width: 82, height: 82)
                                .shadow(color: Theme.accent.opacity(0.5), radius: 10, y: 3)
                            Image(systemName: countdown == nil ? "camera.fill" : "xmark")
                                .font(.system(size: 30, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .buttonStyle(BouncyButtonStyle())
                    .disabled(!cameraIsLive || isIdentifying)
                    .opacity(cameraIsLive ? 1 : 0.45)
                    .accessibilityLabel(countdown == nil ? "Take photo" : "Cancel timer")
                    sideSlot(alignment: .center) {
                        if cameraIsLive {
                            circleButton("arrow.triangle.2.circlepath") { camera.flip() }
                        }
                    }
                }

                timerPicker

                Text(countdown == nil ? "Tap anywhere here to snap" : "Tap to cancel")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
            }
            .padding(.bottom, 10)
        }
    }

    private var timerPicker: some View {
        HStack(spacing: 4) {
            ForEach([0, 3, 10], id: \.self) { seconds in
                let selected = timerSeconds == seconds
                Button {
                    timerSeconds = seconds
                    if hapticsEnabled { UISelectionFeedbackGenerator().selectionChanged() }
                } label: {
                    Label(seconds == 0 ? "Off" : "\(seconds)s",
                          systemImage: seconds == 0 ? "timer.slash" : "timer")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(selected ? Color(hex: 0x16211A) : .white.opacity(0.8))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(selected ? Theme.gold : .clear))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Capsule().fill(.white.opacity(0.1)))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Self-timer")
    }

    /// Snap now, or after the self-timer; a tap during a countdown cancels it.
    private func snapWithTimer() {
        guard cameraIsLive, !isIdentifying else { return }
        if countdown != nil { cancelCountdown(); return }
        guard timerSeconds > 0 else { capture(); return }
        countdownTask = Task { @MainActor in
            for remaining in stride(from: timerSeconds, through: 1, by: -1) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { countdown = remaining }
                if hapticsEnabled { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
            }
            withAnimation { countdown = nil }
            capture()
        }
    }

    private func cancelCountdown() {
        countdownTask?.cancel()
        countdownTask = nil
        withAnimation { countdown = nil }
    }

    // MARK: Controls

    private var topBar: some View {
        HStack {
            circleButton("xmark") { onFinished() }
            Spacer()
            circleButton("slider.horizontal.3") { showOptions = true }
        }
    }

    /// The open Duo: the viewfinder runs across both pages and the controls
    /// stand in a column on the trailing edge, like Camera in landscape, so
    /// the shutter never sits on the fold. The safety reminder stays bottom
    /// left, on the first page.
    private var spreadControls: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading) {
                circleButton("xmark") { onFinished() }
                Spacer()
                safetyLine
            }
            Spacer()
            VStack(spacing: 22) {
                circleButton("slider.horizontal.3") { showOptions = true }
                Spacer()
                if lensStops.count > 1 { lensButtons(vertical: true) }
                shutterButton
                libraryButton
                Spacer()
                sideSlot(alignment: .center) {
                    if cameraIsLive {
                        circleButton("arrow.triangle.2.circlepath") { camera.flip() }
                            .transition(.opacity.combined(with: .scale))
                    }
                }
            }
            .animation(.easeInOut(duration: 0.25), value: camera.status)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    /// Opens the photo library (any photo, any date), following the familiar
    /// camera pattern: your last catch shows as the thumbnail, or a photos
    /// glyph before your first.
    private var libraryButton: some View {
        PhotosPicker(selection: $libraryItem, matching: .images, photoLibrary: .shared()) {
            Group {
                if let last = lastCatch, let data = last.photoData, let ui = UIImage(data: data) {
                    FriendPhoto(image: ui, framing: last.framing)
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

    private var bottomControls: some View {
        VStack(spacing: 14) {
            if lensStops.count > 1 { lensButtons(vertical: false) }
            safetyLine
            HStack {
                // Fixed-size side slots keep the shutter centered even before the
                // camera authorizes (and the flip button appears) or when there's
                // no last catch yet — an empty view alone would collapse to zero.
                sideSlot(alignment: .leading) {
                    if cameraIsLive {
                        circleButton("arrow.triangle.2.circlepath") { camera.flip() }
                            .transition(.opacity.combined(with: .scale))
                    }
                }

                Spacer()
                shutterButton
                Spacer()

                // Bottom-right opens the photo library.
                sideSlot(alignment: .trailing) { libraryButton }
            }
            .animation(.easeInOut(duration: 0.25), value: camera.status)
        }
    }

    /// The lens buttons to show. (DEBUG: the screenshot backdrop has no camera,
    /// so it shows a typical set.)
    private var lensStops: [CGFloat] {
        #if DEBUG
        if Self.debugBackdrop != nil, camera.lensStops.isEmpty { return [0.5, 1, 2, 5] }
        #endif
        return camera.lensStops
    }

    /// The lens you're on: the longest one at or below the current zoom.
    private var activeLens: CGFloat? {
        lensStops.last { $0 <= camera.displayZoom + 0.05 } ?? lensStops.first
    }

    /// One button per lens (0.5×, 1×, 2×, 5×…). The lens you're on is lit and
    /// shows the live zoom, so a pinch in between reads as "1.4×".
    private func lensButtons(vertical: Bool) -> some View {
        let layout = vertical ? AnyLayout(VStackLayout(spacing: 6)) : AnyLayout(HStackLayout(spacing: 6))
        return layout {
            ForEach(lensStops, id: \.self) { stop in
                let isActive = stop == activeLens
                Button {
                    if hapticsEnabled { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
                    camera.selectLens(stop)
                } label: {
                    Text(isActive ? Self.zoomLabel(camera.displayZoom) + "×" : Self.zoomLabel(stop))
                        .font(.system(size: isActive ? 13 : 12, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(isActive ? Theme.gold : .white)
                        .frame(width: isActive ? 44 : 34, height: isActive ? 44 : 34)
                        .background(Circle().fill(.black.opacity(isActive ? 0.6 : 0.4)))
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(Self.zoomLabel(stop)) times zoom")
                .accessibilityAddTraits(isActive ? .isSelected : [])
            }
        }
        .padding(vertical ? .vertical : .horizontal, 4)
        .background(Capsule().fill(.black.opacity(0.3)))
        .animation(.easeInOut(duration: 0.18), value: activeLens)
    }

    /// "0.5", "1", "2", "1.4" — whole numbers drop the decimal.
    private static func zoomLabel(_ zoom: CGFloat) -> String {
        let rounded = (zoom * 10).rounded() / 10
        return rounded == rounded.rounded() ? String(format: "%.0f", rounded) : String(format: "%.1f", rounded)
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
        .opacity(cameraIsLive ? 1 : 0.45)
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

    private func capture() {
        flashOpacity = 0.9
        withAnimation(.easeOut(duration: 0.4)) { flashOpacity = 0 }
        if hapticsEnabled { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }

        camera.capturePhoto { image in
            guard let image else { return }
            Task { await logCatch(image, at: locationTaggingEnabled ? location.current : nil) }
        }
    }

    /// Record the snap and open the celebration. We no longer guess the animal
    /// with on-device Vision — recognition wasn't reliable enough to be fun —
    /// so every catch arrives as an unnamed Mystery Friend and the player picks
    /// who it is on the celebration screen, where random animal confetti greets
    /// the new find.
    @MainActor
    /// `coord` is where you met: here and now for a live snap; for a library
    /// photo, wherever the photo says it was taken (see `importFromLibrary`).
    private func logCatch(_ image: UIImage, at coord: CLLocationCoordinate2D?) async {
        // Blocks a second capture while we work; the celebration sheet slides
        // up the moment the record is ready (no separate loading screen).
        isIdentifying = true

        // An unidentified blob isn't a "first sighting" of anything, so it earns
        // a flat snap token with no first-find bonus. The real value (and the 2×
        // discovery bonus) lands when the player names the friend.
        let species = Species.mystery
        let isFirst = false
        let sparks = Progression.snapSparks

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
            newAchievements: newAchievements
        )
    }

    /// A clear reason an uploaded photo couldn't be added — shown as an alert.
    private enum UploadIssue: Identifiable {
        case loadFailed
        var id: Int { 0 }
        var title: String { "Couldn't open that photo" }
        var message: String { "Something went wrong opening that photo. Try another, or snap your friend live." }
    }

    // MARK: Gallery import

    /// Bring in a photo from the library, from any date. Where you met comes
    /// from the photo's own location when it has one; otherwise from here,
    /// but only for a photo taken in the last day (or with no date), since
    /// an older photo was probably taken somewhere else. The friend joins
    /// your Grove today either way, so streaks and daily challenges stay
    /// about what you do now.
    @MainActor
    private func importFromLibrary(_ item: PhotosPickerItem) async {
        defer { libraryItem = nil }
        guard !isIdentifying else { return }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            if hapticsEnabled { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
            uploadIssue = .loadFailed
            return
        }

        var coord: CLLocationCoordinate2D?
        if locationTaggingEnabled {
            let dayOld: TimeInterval = 24 * 60 * 60
            let isRecent = captureDate(from: data).map { Date().timeIntervalSince($0) <= dayOld } ?? true
            coord = photoLocation(from: data) ?? (isRecent ? location.current : nil)
        }
        await logCatch(image, at: coord)
    }

    /// Where the photo was taken, from its GPS metadata, if present.
    private func photoLocation(from data: Data) -> CLLocationCoordinate2D? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let gps = props[kCGImagePropertyGPSDictionary] as? [CFString: Any],
              let lat = gps[kCGImagePropertyGPSLatitude] as? Double,
              let lon = gps[kCGImagePropertyGPSLongitude] as? Double
        else { return nil }
        let south = (gps[kCGImagePropertyGPSLatitudeRef] as? String) == "S"
        let west = (gps[kCGImagePropertyGPSLongitudeRef] as? String) == "W"
        let coord = CLLocationCoordinate2D(latitude: south ? -lat : lat, longitude: west ? -lon : lon)
        return CLLocationCoordinate2DIsValid(coord) ? coord : nil
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
