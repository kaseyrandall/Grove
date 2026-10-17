import SwiftUI

/// A small sheet asking one five-point question: tap a face, then Send. A
/// thank-you replaces the question for a moment before the sheet closes.
struct SurveySheet: View {
    let survey: Survey
    var onAnswer: (Int) -> Void
    var onNotNow: () -> Void

    @Environment(\.dismiss) private var dismiss
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @State private var score: Int?
    @State private var sent = false

    var body: some View {
        VStack(spacing: 0) {
            if sent {
                thanks
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            } else {
                question
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 28)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.cream)
        .presentationDetents([.height(372)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
    }

    private var question: some View {
        VStack(spacing: 18) {
            Text("🌿 Quick question")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.ink.opacity(0.5))

            Text(survey.question)
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    ForEach(1...5, id: \.self) { face($0) }
                }
                scaleLabels
            }

            VStack(spacing: 4) {
                GroveButton(title: "Send") {
                    guard let score else { return }
                    onAnswer(score)
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { sent = true }
                    Task {
                        try? await Task.sleep(for: .seconds(1.3))
                        dismiss()
                    }
                }
                .disabled(score == nil)
                .opacity(score == nil ? 0.45 : 1)

                Button("Not now") {
                    onNotNow()
                    dismiss()
                }
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(Theme.ink.opacity(0.55))
                .padding(.vertical, 10)
            }
        }
    }

    private func face(_ value: Int) -> some View {
        let selected = score == value
        let dimmed = score != nil && !selected
        return Button {
            if hapticsEnabled { UISelectionFeedbackGenerator().selectionChanged() }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { score = value }
        } label: {
            Text(Survey.faces[value - 1])
                .font(.system(size: 30))
                .frame(width: 56, height: 56)
                .background(Circle().fill(selected ? Theme.accent.opacity(0.16) : .white))
                .overlay(Circle().stroke(selected ? Theme.accent : .clear, lineWidth: 2.5))
                .shadow(color: Theme.ink.opacity(0.08), radius: 8, x: 0, y: 4)
                .grayscale(dimmed ? 0.7 : 0)
                .opacity(dimmed ? 0.55 : 1)
                .scaleEffect(selected ? 1.1 : 1)
        }
        .buttonStyle(BouncyButtonStyle())
        .accessibilityLabel("\(value) of 5, \(survey.labels[value - 1])")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    /// The ends of the scale, with the chosen answer spelled out between them.
    private var scaleLabels: some View {
        ZStack {
            HStack {
                Text(survey.labels[0])
                Spacer()
                Text(survey.labels[4])
            }
            .font(.system(.caption, design: .rounded, weight: .semibold))
            .foregroundStyle(Theme.ink.opacity(0.5))

            if let score {
                Text(survey.labels[score - 1])
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.accent)
                    .contentTransition(.opacity)
            }
        }
        .padding(.horizontal, 4)
        .accessibilityHidden(true)
    }

    private var thanks: some View {
        VStack(spacing: 10) {
            Spacer(minLength: 0)
            Text("💛").font(.system(size: 52))
            Text("Thank you!")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.ink)
            Text("That helps Grove grow.")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Theme.ink.opacity(0.65))
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    Color.gray.sheet(isPresented: .constant(true)) {
        SurveySheet(survey: SurveyCatalog.all[1], onAnswer: { _ in }, onNotNow: {})
    }
}
