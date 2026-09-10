import SwiftUI

/// A tap-to-open full-photo viewer — the "shadow box." Presents the whole,
/// uncropped photo centered on a dimmed backdrop; tap anywhere (or the close
/// button) to dismiss. Used wherever a friend's cropped photo card appears, so
/// people can see the full shot behind the crop.
private struct PhotoLightbox: ViewModifier {
    @Binding var isPresented: Bool
    let image: UIImage?

    @State private var shown = false

    func body(content: Content) -> some View {
        content.fullScreenCover(isPresented: $isPresented) {
            ZStack {
                Color.black.opacity(shown ? 0.92 : 0)
                    .ignoresSafeArea()

                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding(20)
                        .scaleEffect(shown ? 1 : 0.92)
                        .opacity(shown ? 1 : 0)
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
            .onTapGesture { dismiss() }
            .presentationBackground(.clear)
            .onAppear {
                withAnimation(.easeOut(duration: 0.25)) { shown = true }
            }
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
