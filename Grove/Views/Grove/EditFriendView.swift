import SwiftUI
import SwiftData

/// Customize an individual friend: give them a nickname, choose which Grove zone
/// they live in, or release them back to the wild. Edits the friend's `Catch`
/// directly. Releasing is signalled to the presenter via `onRelease` (which
/// performs the delete once this sheet closes, so we never touch a deleted model).
struct EditFriendView: View {
    let friend: Catch
    let onRelease: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var nickname: String
    @State private var zone: Habitat
    @State private var showReleaseConfirm = false

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 10)]

    init(friend: Catch, onRelease: @escaping () -> Void) {
        self.friend = friend
        self.onRelease = onRelease
        _nickname = State(initialValue: friend.nickname ?? "")
        _zone = State(initialValue: friend.effectiveZone)
    }

    private var species: Species { friend.species }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 22) {
                        preview
                        nicknameField
                        zonePicker
                        releaseButton
                    }
                    .padding()
                }
            }
            .navigationTitle("Edit \(species.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.bold)
                }
            }
            .confirmationDialog("Release \(species.name)?", isPresented: $showReleaseConfirm, titleVisibility: .visible) {
                Button("Release back to the wild", role: .destructive) {
                    onRelease()
                    dismiss()
                }
                Button("Keep them", role: .cancel) {}
            } message: {
                Text("They'll leave your Grove for good. You can always meet a new friend out in the wild.")
            }
        }
    }

    private var preview: some View {
        ZStack {
            zone.gradient
            if let data = friend.photoData, let ui = UIImage(data: data) {
                Image(uiImage: ui).resizable().scaledToFill()
            } else {
                Text(species.emoji).font(.system(size: 64))
            }
        }
        .frame(height: 130)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .animation(.easeInOut(duration: 0.25), value: zone)
    }

    private var nicknameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("NICKNAME")
            TextField("A name just for this friend", text: $nickname)
                .font(.system(.body, design: .rounded))
                .padding()
                .softCard()
        }
    }

    private var zonePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("LIVES IN")
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(Habitat.ordered) { habitat in
                    Button {
                        withAnimation { zone = habitat }
                    } label: {
                        HStack(spacing: 6) {
                            Text(habitat.emoji)
                            Text(habitat.shortName)
                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        }
                        .foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(zone == habitat
                                      ? habitat.gradient
                                      : LinearGradient(colors: [.white, .white], startPoint: .top, endPoint: .bottom))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(zone == habitat ? Theme.accent : Theme.ink.opacity(0.08), lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var releaseButton: some View {
        Button(role: .destructive) {
            showReleaseConfirm = true
        } label: {
            Text("🍃 Release \(species.name) back to the wild")
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(Theme.ink.opacity(0.5))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
        .padding(.top, 4)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(Theme.ink.opacity(0.45))
            .padding(.leading, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func save() {
        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        friend.nickname = trimmed.isEmpty ? nil : trimmed
        friend.zoneOverride = (zone == species.zone) ? nil : zone
        try? context.save()
        dismiss()
    }
}
