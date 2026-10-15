import SwiftUI
import SwiftData
import UIKit

/// Customize an individual friend: identify (or correct) which animal it is,
/// crop their photo, choose which Grove zone they live in, or release them
/// back to the wild. (Naming them happens right on their name, on the friend
/// page.) Nothing changes until Save, which edits the friend's `Catch`
/// directly. Releasing is signalled to the presenter via `onRelease` (which
/// performs the delete once this sheet closes, so we never touch a deleted
/// model).
struct EditFriendView: View {
    let friend: Catch
    let onRelease: () -> Void

    @Environment(\.dismiss) private var dismiss
    /// Set when this opens as a right-page panel on the open Duo.
    @Environment(\.groveSheetClose) private var closePanel
    @Environment(\.modelContext) private var context

    /// The friend's kind — mutable so it can be (re)identified here.
    @State private var species: Species
    /// The photo crop as edited here; applied on Save.
    @State private var framing: PhotoFraming?
    @State private var showCrop = false
    @State private var zone: Habitat
    @State private var showReleaseConfirm = false

    /// Drives the push to the full, searchable catalog.
    @State private var showPicker = false

    init(friend: Catch, onRelease: @escaping () -> Void) {
        self.friend = friend
        self.onRelease = onRelease
        _species = State(initialValue: friend.species)
        _framing = State(initialValue: friend.framing)
        _zone = State(initialValue: friend.effectiveZone)
    }

    private var isMystery: Bool { species.id == Species.mystery.id }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 22) {
                    preview
                    typeSection
                    zonePicker
                    releaseButton
                }
                .padding()
            }
            .navigationDestination(isPresented: $showPicker) {
                SpeciesPickerView(selectedID: species.id) { picked in
                    select(picked)
                }
            }
        }
        .groveSheetChrome(
            title: isMystery ? "New Friend" : "Edit \(species.name)",
            cancel: SheetAction(title: "Cancel") { close() },
            confirm: SheetAction(title: "Save") { save() }
        )
        .fullScreenCover(isPresented: $showCrop) {
            if let image = friend.photoData.flatMap(UIImage.init(data:)) {
                PhotoCropView(image: image, framing: framing) { framing = $0 }
            }
        }
        .sheet(isPresented: $showReleaseConfirm) {
            ReleaseSheet(speciesName: species.name) {
                onRelease()
                close()
            }
            .presentationDetents([.height(340)])
            .presentationDragIndicator(.visible)
        }
    }

    private var preview: some View {
        Color.clear
            .aspectRatio(Theme.photoAspectRatio, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .overlay {
                ZStack {
                    zone.gradient
                    if let data = friend.photoData, let ui = UIImage(data: data) {
                        FriendPhoto(image: ui, framing: framing)
                    } else {
                        Text(species.emoji).font(.system(size: 64))
                    }
                }
            }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(alignment: .topTrailing) {
            if friend.photoData != nil {
                Button { showCrop = true } label: {
                    Label("Crop", systemImage: "crop")
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(.white.opacity(0.92)))
                }
                .buttonStyle(.plain)
                .padding(12)
            }
        }
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

    // MARK: Animal — the full, searchable catalog behind a door

    private var typeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Same words as the catch celebration's cards: Animal, Lives in.
            sectionLabel("ANIMAL")
            browseButton
        }
    }

    /// The door to the full, searchable catalog.
    private var browseButton: some View {
        Button {
            showPicker = true
        } label: {
            HStack(spacing: 10) {
                if isMystery {
                    Image(systemName: "square.grid.2x2.fill")
                        .foregroundStyle(Theme.accent)
                    Text("Browse all animals")
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                } else {
                    Text(species.emoji)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(species.name)
                            .font(.system(.body, design: .rounded, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                        Text("Tap to choose a different animal")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(Theme.ink.opacity(0.5))
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.ink.opacity(0.3))
            }
            .padding()
            .softCard()
        }
        .buttonStyle(.plain)
    }

    private var zonePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("LIVES IN")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 10)], spacing: 10) {
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

    // MARK: Actions

    /// Pick a kind. Moves the friend to that kind's home zone so "Lives in"
    /// reflects the choice — the player can still override it just below.
    private func select(_ candidate: Species) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            species = candidate
            zone = candidate.zone
        }
    }

    private func save() {
        // If the kind changed, re-log it and recompute its first-of-kind bonus.
        if species.id != friend.speciesID {
            let others = (try? context.fetch(FetchDescriptor<Catch>())) ?? []
            let isFirst = !others.contains { $0 !== friend && $0.speciesID == species.id }
            friend.speciesID = species.id
            friend.isFirstSighting = isFirst
            friend.sparksEarned = Progression.sparks(for: species, isFirstSighting: isFirst)
        }

        friend.framing = framing
        friend.zoneOverride = (zone == species.zone) ? nil : zone

        try? context.save()
        close()
    }

    /// Close this sheet, or the right-page panel it opened as.
    private func close() {
        if let closePanel { closePanel() } else { dismiss() }
    }
}

// MARK: - Release confirmation

/// A cozy slide-up sheet confirming a friend's release, in place of the stock
/// system action sheet.
private struct ReleaseSheet: View {
    let speciesName: String
    /// Called when the player confirms the release.
    let onRelease: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 14) {
                Text("🍃").font(.system(size: 46))

                Text("Release \(speciesName)?")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)

                Text("They'll leave your Grove for good. You can always meet a new friend out in the wild.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Theme.ink.opacity(0.6))
                    .multilineTextAlignment(.center)

                Spacer(minLength: 4)

                VStack(spacing: 10) {
                    Button(action: onRelease) {
                        Text("Release back to the wild")
                            .font(.system(.body, design: .rounded, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(Capsule().fill(Color(hex: 0xE86A6A)))
                    }
                    Button { dismiss() } label: {
                        Text("Keep them")
                            .font(.system(.body, design: .rounded, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(Capsule().fill(.white))
                            .overlay(Capsule().stroke(Theme.ink.opacity(0.1), lineWidth: 1))
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(24)
        }
    }
}

// MARK: - Full catalog picker

/// The extensive, searchable list of every friend — a dedicated screen so the
/// edit sheet stays compact and this scales as the catalog grows. Picking an
/// animal reports it back and pops.
struct SpeciesPickerView: View {
    let selectedID: String
    let onPick: (Species) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 10)]

    private var results: [Species] { CreatureCatalog.matching(query) }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                if results.isEmpty {
                    Text("No animals match “\(query.trimmingCharacters(in: .whitespaces))”.")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(Theme.ink.opacity(0.5))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                } else {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(results) { candidate in
                            SpeciesTile(species: candidate, isSelected: candidate.id == selectedID) {
                                onPick(candidate)
                                dismiss()
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Choose a Friend")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search animals")
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)
    }
}

// MARK: - Shared tile

/// One animal in a grid: emoji, name, a rarity-tinted border, and an accent
/// ring + check when it's the current pick. Shared by the inline suggestions
/// and the full picker so they stay visually identical.
struct SpeciesTile: View {
    let species: Species
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Text(species.emoji).font(.system(size: 30))
                Text(species.name)
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? Theme.accent.opacity(0.12) : Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? Theme.accent : species.rarity.tint.opacity(0.35),
                            lineWidth: isSelected ? 2.5 : 1.5)
            )
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.accent)
                        .padding(6)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
