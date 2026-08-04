import SwiftUI
import SwiftData

/// Customize an individual friend: identify a Mystery Friend, give them a
/// nickname, choose which Grove zone they live in, or release them back to the
/// wild. Edits the friend's `Catch` directly. Releasing is signalled to the
/// presenter via `onRelease` (which performs the delete once this sheet closes,
/// so we never touch a deleted model).
struct EditFriendView: View {
    let friend: Catch
    let onRelease: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    /// The friend's kind — mutable so a Mystery Friend can be identified here.
    @State private var species: Species
    @State private var nickname: String
    @State private var zone: Habitat
    @State private var showReleaseConfirm = false

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 10)]

    init(friend: Catch, onRelease: @escaping () -> Void) {
        self.friend = friend
        self.onRelease = onRelease
        _species = State(initialValue: friend.species)
        _nickname = State(initialValue: friend.nickname ?? "")
        _zone = State(initialValue: friend.effectiveZone)
    }

    private var isMystery: Bool { species.id == Species.mystery.id }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 22) {
                        preview
                        if isMystery { identifySection }
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
        .overlay(alignment: .bottomTrailing) {
            if !isMystery {
                Text("\(species.emoji) \(species.name)")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Capsule().fill(.white.opacity(0.92)))
                    .padding(12)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: zone)
    }

    // MARK: Identify (Mystery Friends only)

    private var identifySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                sectionLabel("WHAT IS IT?")
                Text("Tap the animal you spotted to identify this friend.")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Theme.ink.opacity(0.55))
                    .padding(.leading, 6)
            }

            ForEach(Habitat.ordered) { habitat in
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(habitat.emoji) \(habitat.shortName)")
                        .font(.system(.caption2, design: .rounded, weight: .bold))
                        .foregroundStyle(Theme.ink.opacity(0.5))
                        .padding(.leading, 6)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(CreatureCatalog.species(in: habitat)) { candidate in
                                candidateChip(candidate)
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                }
            }
        }
    }

    private func candidateChip(_ candidate: Species) -> some View {
        Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                species = candidate
                zone = candidate.zone
            }
        } label: {
            HStack(spacing: 5) {
                Text(candidate.emoji)
                Text(candidate.name)
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(Theme.ink)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Capsule().fill(.white))
            .overlay(Capsule().stroke(candidate.rarity.tint, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
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
        // If a Mystery Friend was identified, re-log it as the chosen kind and
        // recompute its first-of-kind bonus + sparks.
        if species.id != friend.speciesID {
            let others = (try? context.fetch(FetchDescriptor<Catch>())) ?? []
            let isFirst = !others.contains { $0 !== friend && $0.speciesID == species.id }
            friend.speciesID = species.id
            friend.isFirstSighting = isFirst
            friend.sparksEarned = Progression.sparks(for: species, isFirstSighting: isFirst)
        }

        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        friend.nickname = trimmed.isEmpty ? nil : trimmed
        friend.zoneOverride = (zone == species.zone) ? nil : zone

        try? context.save()
        dismiss()
    }
}
