import SwiftUI
import SwiftData

/// The crop tool: slide and pinch the photo inside the card shape to choose
/// what shows on a friend's cards. Nothing is cut from the photo — the full
/// shot still opens full screen, and the crop can be redone any time.
struct PhotoCropView: View {
    let image: UIImage
    let onSave: (PhotoFraming?) -> Void

    @Environment(\.dismiss) private var dismiss
    /// The settled crop; the live drag and pinch ride on top of it.
    @State private var framing: PhotoFraming
    @GestureState private var drag: CGSize = .zero
    @GestureState private var pinch: CGFloat = 1

    init(image: UIImage, framing: PhotoFraming?, onSave: @escaping (PhotoFraming?) -> Void) {
        self.image = image
        self.onSave = onSave
        _framing = State(initialValue: framing ?? PhotoFraming())
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            GeometryReader { geo in
                let card = CGSize(width: geo.size.width - 32,
                                  height: (geo.size.width - 32) / Theme.photoAspectRatio)
                let live = liveFraming(in: card)
                let placed = live.layout(photo: image.size, in: card)

                ZStack {
                    // The whole photo, dimmed, so you can see what's outside the card.
                    Image(uiImage: image)
                        .resizable()
                        .frame(width: placed.size.width, height: placed.size.height)
                        .offset(x: placed.origin.x, y: placed.origin.y)
                        .frame(width: card.width, height: card.height, alignment: .topLeading)
                        .opacity(0.3)

                    FriendPhoto(image: image, framing: live)
                        .frame(width: card.width, height: card.height)
                        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .strokeBorder(.white, lineWidth: 2))
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture()
                        .updating($drag) { value, state, _ in state = value.translation }
                        .onEnded { value in
                            framing = moved(framing, by: value.translation, pinch: 1, in: card)
                        }
                )
                .simultaneousGesture(
                    MagnifyGesture()
                        .updating($pinch) { value, state, _ in state = value.magnification }
                        .onEnded { value in
                            framing = moved(framing, by: .zero, pinch: value.magnification, in: card)
                        }
                )
            }
            .ignoresSafeArea()

            VStack {
                HStack {
                    barButton("Cancel") { dismiss() }
                    Spacer()
                    barButton("Done", prominent: true) {
                        // An untouched, centred photo is simply "not cropped".
                        onSave(framing == PhotoFraming() ? nil : framing)
                        dismiss()
                    }
                }
                Spacer()
                Text("Drag and pinch to choose what shows on the card")
                    .font(.system(.footnote, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { framing = PhotoFraming() }
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(.white.opacity(0.18)))
                }
                .opacity(framing == PhotoFraming() ? 0.4 : 1)
                .disabled(framing == PhotoFraming())
                .padding(.top, 10)
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
        .presentationBackground(.black)
        .statusBarHidden()
    }

    /// The crop as it looks mid-gesture.
    private func liveFraming(in card: CGSize) -> PhotoFraming {
        moved(framing, by: drag, pinch: pinch, in: card)
    }

    /// `start` after zooming by `pinch` and sliding the photo by `translation`
    /// (in points), kept inside the photo.
    private func moved(_ start: PhotoFraming, by translation: CGSize, pinch: CGFloat, in card: CGSize) -> PhotoFraming {
        var next = start
        next.zoom = min(max(start.zoom * pinch, 1), PhotoFraming.maxZoom)
        let size = next.layout(photo: image.size, in: card).size
        if size.width > 0, size.height > 0 {
            next.centerX -= translation.width / size.width
            next.centerY -= translation.height / size.height
        }
        return next.clamped(photo: image.size, in: card)
    }

    private func barButton(_ title: String, prominent: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(prominent ? Theme.ink : .white)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(Capsule().fill(prominent ? Color.white : Color.white.opacity(0.18)))
        }
        .buttonStyle(.plain)
    }
}

private struct PhotoCropper: ViewModifier {
    @Binding var isPresented: Bool
    let friend: Catch
    @Environment(\.modelContext) private var context

    func body(content: Content) -> some View {
        content.fullScreenCover(isPresented: $isPresented) {
            if let image = friend.photoData.flatMap(UIImage.init(data:)) {
                PhotoCropView(image: image, framing: friend.framing) { framing in
                    friend.framing = framing
                    try? context.save()
                }
            }
        }
    }
}

extension View {
    /// Presents the crop tool for `friend`'s photo and saves the result.
    func photoCropper(isPresented: Binding<Bool>, friend: Catch) -> some View {
        modifier(PhotoCropper(isPresented: isPresented, friend: friend))
    }
}
