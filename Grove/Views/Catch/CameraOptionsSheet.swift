import SwiftUI
import AVFoundation

/// The small "Camera options" sheet the viewfinder's top-right button opens.
/// Folding flash, grid, and location tagging in here keeps the top corners
/// clear of the Dynamic Island.
struct CameraOptionsSheet: View {
    @Binding var flashMode: AVCaptureDevice.FlashMode
    @Binding var gridOn: Bool
    @Binding var locationTagging: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Camera options")
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(Theme.ink)
                .padding(.bottom, 8)

            row("Flash") {
                Picker("Flash", selection: $flashMode) {
                    Text("Off").tag(AVCaptureDevice.FlashMode.off)
                    Text("On").tag(AVCaptureDevice.FlashMode.on)
                    Text("Auto").tag(AVCaptureDevice.FlashMode.auto)
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }
            Divider()
            row("Framing grid") {
                Toggle("", isOn: $gridOn).labelsHidden().tint(Theme.accent)
            }
            Divider()
            row("Tag where I met them") {
                Toggle("", isOn: $locationTagging).labelsHidden().tint(Theme.accent)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .presentationDetents([.height(250)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
    }

    private func row<Control: View>(_ title: String, @ViewBuilder control: () -> Control) -> some View {
        HStack {
            Text(title)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Spacer()
            control()
        }
        .padding(.vertical, 9)
    }
}

#Preview {
    Color.gray.sheet(isPresented: .constant(true)) {
        CameraOptionsSheet(flashMode: .constant(.off), gridOn: .constant(true), locationTagging: .constant(true))
    }
}
