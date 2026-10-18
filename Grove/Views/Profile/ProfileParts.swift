import SwiftUI
import SwiftData

/// The pieces of the Profile that are about the player rather than their
/// progress (that's the Journal): their name, how their story started,
/// favorite friends, and who they met lately.

// MARK: Name

/// The player's name, renamed in place like a friend's: tap, type, done.
/// Empty means they haven't chosen one, which shows as "Explorer".
struct ProfileNameField: View {
    @AppStorage("profileName") private var name = ""
    @State private var isEditing = false
    @State private var draft = ""
    @FocusState private var focused: Bool

    static let placeholder = "Explorer"

    var body: some View {
        Group {
            if isEditing {
                TextField("Your name", text: $draft)
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                    .submitLabel(.done)
                    .focused($focused)
                    .onSubmit { isEditing = false }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 16)
                    .background(Capsule().fill(Theme.cream))
                    .overlay(Capsule().stroke(Theme.accent, lineWidth: 2))
                    .padding(.horizontal, 32)
            } else {
                Button { isEditing = true } label: {
                    HStack(spacing: 8) {
                        Text(name.isEmpty ? Self.placeholder : name)
                            .font(.system(size: 22, weight: .heavy, design: .rounded))
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                        Image(systemName: "pencil")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Theme.accent)
                            .frame(width: 24, height: 24)
                            .background(Circle().fill(Theme.cream))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(name.isEmpty ? Self.placeholder : name), rename")
            }
        }
        .onChange(of: isEditing) { _, editing in
            if editing {
                draft = name
                focused = true
            } else {
                focused = false
                name = String(draft.trimmingCharacters(in: .whitespacesAndNewlines).prefix(24))
            }
        }
        .onChange(of: focused) { _, isFocused in
            if !isFocused && isEditing { isEditing = false }
        }
    }
}

// MARK: Your story

/// "Exploring since October 2026", and the first friend who came home.
struct ProfileStoryLine: View {
    let catches: [Catch]

    var body: some View {
        if let first = catches.min(by: { $0.caughtAt < $1.caughtAt }) {
            VStack(spacing: 2) {
                Text("Exploring since \(first.caughtAt.formatted(.dateTime.month(.wide).year()))")
                Text("First friend: \(first.species.emoji) \(first.displayName)")
            }
            .font(.system(.subheadline, design: .rounded))
            .foregroundStyle(Theme.ink.opacity(0.6))
            .multilineTextAlignment(.center)
        } else {
            Text("Your story starts with your first snap.")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Theme.ink.opacity(0.6))
        }
    }
}

// MARK: Card headers

/// A Profile card's title with its icon in front, like the Settings rows.
struct ProfileCardHeader: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.accent)
            Text(title)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(Theme.ink)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: Friend thumbnails

/// A friend's photo (or its kind's emoji) clipped to a shape, framed the way
/// the player cropped it.
private struct FriendThumb<S: Shape>: View {
    let friend: Catch
    let shape: S
    var emojiSize: CGFloat = 30

    var body: some View {
        ZStack {
            shape.fill(Theme.cream)
            if let data = friend.photoData, let ui = UIImage(data: data) {
                FriendPhoto(image: ui, framing: friend.framing)
                    .clipShape(shape)
            } else {
                Text(friend.species.emoji).font(.system(size: emojiSize))
            }
        }
    }
}

// MARK: Favorites

/// Up to three friends the player pinned, with "+" slots for the rest.
struct FavoriteFriendsCard: View {
    let catches: [Catch]
    let onEdit: () -> Void

    var body: some View {
        let favorites = Favorites.of(catches)
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ProfileCardHeader(title: "Favorite friends", systemImage: "heart.fill")
                Spacer()
                if !favorites.isEmpty {
                    Button("Edit", action: onEdit)
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(Theme.accent)
                }
            }

            HStack(alignment: .top, spacing: 12) {
                ForEach(0..<Favorites.limit, id: \.self) { slot in
                    if slot < favorites.count {
                        filledSlot(favorites[slot])
                    } else {
                        emptySlot
                    }
                }
            }

            if favorites.isEmpty {
                Text(catches.isEmpty
                     ? "Once you've met a few friends, pin your favorites here."
                     : "Pin the friends you love most. Tap ♥ on a friend's page, or tap + here.")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Theme.ink.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .softCard()
    }

    private func filledSlot(_ friend: Catch) -> some View {
        NavigationLink {
            GuideEntryView(friend: friend)
        } label: {
            VStack(spacing: 6) {
                FriendThumb(friend: friend, shape: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .aspectRatio(1, contentMode: .fit)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(friend.species.rarity.tint, lineWidth: 3)
                    )
                Text(friend.displayName)
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private var emptySlot: some View {
        Button(action: onEdit) {
            VStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Theme.ink.opacity(0.18), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.cream.opacity(0.6)))
                    .aspectRatio(1, contentMode: .fit)
                    .overlay {
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(catches.isEmpty ? Theme.ink.opacity(0.2) : Theme.accent)
                    }
                // Keeps the slots level with the named ones beside them.
                Text(" ")
                    .font(.system(.caption, design: .rounded, weight: .bold))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .disabled(catches.isEmpty)
        .accessibilityLabel("Add a favorite friend")
    }
}

/// Every friend in a grid; tap to pin or unpin, up to the limit.
struct FavoritesPicker: View {
    @Query(sort: \Catch.caughtAt, order: .reverse) private var catches: [Catch]
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.groveSheetClose) private var closePanel

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 14)]

    var body: some View {
        let pinned = Favorites.of(catches).count
        let full = pinned >= Favorites.limit
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    Text(full ? "\(pinned) of \(Favorites.limit) pinned. Tap one to unpin it."
                              : "\(pinned) of \(Favorites.limit) pinned")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(Theme.ink.opacity(0.6))
                        .contentTransition(.numericText())

                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(catches) { friend in
                            tile(friend, dimmed: full && friend.favoritedAt == nil)
                        }
                    }
                }
                .padding()
            }
        }
        .groveSheetChrome(title: "Favorite friends",
                          confirm: SheetAction(title: "Done") { close() })
    }

    private func close() {
        if let closePanel { closePanel() } else { dismiss() }
    }

    private func tile(_ friend: Catch, dimmed: Bool) -> some View {
        let pinned = friend.favoritedAt != nil
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                Favorites.toggle(friend, among: catches, context: context)
            }
        } label: {
            VStack(spacing: 6) {
                FriendThumb(friend: friend, shape: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .aspectRatio(1, contentMode: .fit)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(pinned ? Theme.accent : .clear, lineWidth: 3)
                    )
                    .overlay(alignment: .topTrailing) {
                        if pinned {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 24, height: 24)
                                .background(Circle().fill(Theme.accent))
                                .offset(x: 5, y: -5)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                Text(friend.displayName)
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
            }
            .opacity(dimmed ? 0.4 : 1)
        }
        .buttonStyle(.plain)
        .disabled(dimmed)
        .accessibilityLabel(friend.displayName)
        .accessibilityAddTraits(pinned ? .isSelected : [])
    }
}

// MARK: Recently met

/// The newest friends, newest first, in a row you can scroll.
struct RecentFriendsCard: View {
    let catches: [Catch]
    static let count = 8

    var body: some View {
        let recent = catches.sorted { $0.caughtAt > $1.caughtAt }.prefix(Self.count)
        VStack(alignment: .leading, spacing: 12) {
            ProfileCardHeader(title: "Recently met", systemImage: "clock.arrow.circlepath")
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(Array(recent)) { friend in
                        NavigationLink {
                            GuideEntryView(friend: friend)
                        } label: {
                            VStack(spacing: 6) {
                                FriendThumb(friend: friend, shape: Circle(), emojiSize: 26)
                                    .frame(width: 64, height: 64)
                                    .overlay(Circle().stroke(friend.species.rarity.tint, lineWidth: 3))
                                Text(friend.displayName)
                                    .font(.system(.caption, design: .rounded, weight: .bold))
                                    .foregroundStyle(Theme.ink)
                                    .lineLimit(1)
                                Text(Self.when(friend.caughtAt))
                                    .font(.system(.caption2, design: .rounded))
                                    .foregroundStyle(Theme.ink.opacity(0.5))
                            }
                            .frame(width: 72)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 2)
            }
        }
        .padding(.vertical)
        .frame(maxWidth: .infinity, alignment: .leading)
        .softCard()
    }

    /// "Today", "Yesterday", or a short date.
    static func when(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }
}
