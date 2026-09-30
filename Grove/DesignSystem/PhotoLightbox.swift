import SwiftUI

/// A tap-to-open full-photo viewer — the "shadow box." Presents the whole,
/// uncropped photo centered on a dimmed backdrop; tap anywhere (or the close
/// button) to dismiss. Pinch or double-tap to zoom in, drag to look around. Used wherever a friend's cropped photo card appears, so
/// people can see the full shot behind the crop.
private struct PhotoLightbox: ViewModifier {
    @Binding var isPresented: Bool
    let image: UIImage?

    @State private var shown = false
    /// Settled zoom and pan; the live pinch and drag ride on top of these.
    @State private var zoom: CGFloat = 1
    @State private var pan: CGSize = .zero
    @GestureState private var pinch: CGFloat = 1
    @GestureState private var drag: CGSize = .zero

    private let maxZoom: CGFloat = 5
    private var isZoomed: Bool { zoom > 1.01 }

    func body(content: Content) -> some View {
        content.fullScreenCover(isPresented: $isPresented) {
            ZStack {
                Color.black.opacity(shown ? 0.92 : 0)
                    .ignoresSafeArea()

                if let image {
                    GeometryReader { geo in
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .padding(isZoomed ? 0 : 20)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .scaleEffect(min(max(zoom * pinch, 0.8), maxZoom * 1.2))
                            .offset(x: pan.width + drag.width, y: pan.height + drag.height)
                            .scaleEffect(shown ? 1 : 0.92)
                            .opacity(shown ? 1 : 0)
                            .contentShape(Rectangle())
                            .gesture(
                                MagnifyGesture()
                                    .updating($pinch) { value, state, _ in state = value.magnification }
                                    .onEnded { value in
                                        settle(zoom: zoom * value.magnification, pan: pan, in: geo.size)
                                    }
                            )
                            .simultaneousGesture(
                                DragGesture()
                                    .updating($drag) { value, state, _ in state = value.translation }
                                    .onEnded { value in
                                        settle(zoom: zoom,
                                               pan: CGSize(width: pan.width + value.translation.width,
                                                           height: pan.height + value.translation.height),
                                               in: geo.size)
                                    },
                                isEnabled: isZoomed
                            )
                            .onTapGesture(count: 2) {
                                settle(zoom: isZoomed ? 1 : 2.5, pan: .zero, in: geo.size)
                            }
                            .onTapGesture { if !isZoomed { dismiss() } }
                    }
                    .ignoresSafeArea()
                }

                VStack {
                    HStack {
                        Spacer()
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 38, height: 38)
                                .background(Circle().fill(.white.opacity(0.18)))
                        }
                        .padding(.trailing, 18)
                        .padding(.top, 8)
                        .opacity(shown ? 1 : 0)
                    }
                    Spacer()
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { if !isZoomed { dismiss() } }
            .presentationBackground(.clear)
            .onAppear {
                zoom = 1
                pan = .zero
                withAnimation(.easeOut(duration: 0.25)) { shown = true }
            }
        }
    }

    /// Rests the photo at a zoom and pan that keep it on screen: zoom stays
    /// between 1× and the max, and the pan can't drag the photo out of view.
    private func settle(zoom newZoom: CGFloat, pan newPan: CGSize, in size: CGSize) {
        let z = min(max(newZoom, 1), maxZoom)
        // How far the zoomed photo spills past each screen edge.
        let photo = image?.size ?? size
        let fit = min(size.width / max(photo.width, 1), size.height / max(photo.height, 1))
        let reachX = max(0, (photo.width * fit * z - size.width) / 2)
        let reachY = max(0, (photo.height * fit * z - size.height) / 2)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            zoom = z
            pan = CGSize(width: min(max(newPan.width, -reachX), reachX),
                         height: min(max(newPan.height, -reachY), reachY))
        }
    }

    private func dismiss() {
        withAnimation(.easeIn(duration: 0.18)) { shown = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { isPresented = false }
    }
}

extension View {
    /// Presents `image` full-screen in a dimmed shadow box when `isPresented`.
    func photoLightbox(isPresented: Binding<Bool>, image: UIImage?) -> some View {
        modifier(PhotoLightbox(isPresented: isPresented, image: image))
    }
}
