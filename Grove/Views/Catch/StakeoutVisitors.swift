import SwiftUI
import CoreLocation

/// A photo Stakeout took when something moved, waiting to be kept.
struct StakeoutVisitor: Identifiable {
    let id = UUID()
    let image: UIImage
    let location: CLLocationCoordinate2D?
    let takenAt = Date.now

    /// The tray holds at most this many; Stakeout pauses taking more.
    static let limit = 24
}

/// The tray of Stakeout's photos: tap one to welcome it to your Grove (the
/// usual catch celebration), or let the rest go.
struct StakeoutVisitorsSheet: View {
    @Binding var visitors: [StakeoutVisitor]
    let onKeep: (StakeoutVisitor) -> Void
    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.adaptive(minimum: 140), spacing: 12)]

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Who stopped by while you were away? Tap a visitor to welcome them to your Grove.")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(Theme.ink.opacity(0.65))
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(visitors.reversed()) { visitor in
                                Button {
                                    visitors.removeAll { $0.id == visitor.id }
                                    onKeep(visitor)
                                } label: {
                                    Image(uiImage: visitor.image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(minWidth: 0, maxWidth: .infinity)
                                        .aspectRatio(1, contentMode: .fill)
                                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                        .overlay(alignment: .bottomLeading) {
                                            Text(visitor.takenAt.formatted(date: .omitted, time: .shortened))
                                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                                .foregroundStyle(.white)
                                                .padding(.horizontal, 8).padding(.vertical, 4)
                                                .background(Capsule().fill(.black.opacity(0.45)))
                                                .padding(8)
                                        }
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Visitor at \(visitor.takenAt.formatted(date: .omitted, time: .shortened)). Welcome to your Grove")
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Visitors")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Let all go", role: .destructive) { visitors.removeAll(); dismiss() }
                        .disabled(visitors.isEmpty)
                }
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
        }
    }
}
