import SwiftUI

/// Create (or rename) a photo set.
struct NewSetSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss

    /// When set, the sheet edits an existing set instead of creating one.
    var editing: PhotoSet? = nil

    @State private var name = ""
    @State private var symbol = "heart.fill"
    @FocusState private var focused: Bool

    private let suggestions = ["Family", "Travel", "Us", "Pets", "Friends", "Summer ’26"]
    private let columns = [GridItem(.adaptive(minimum: 46), spacing: 12)]  // 6 across on most phones, fewer on an SE

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 26) {
                    Image(systemName: symbol)
                        .font(.system(size: 38, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 92, height: 92)
                        .background(Brand.gradient, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                        .shadow(color: Brand.lavender.opacity(0.5), radius: 16, y: 8)
                        .contentTransition(.symbolEffect(.replace))
                        .padding(.top, 8)
                        .accessibilityHidden(true)

                    TextField("Set name", text: $name)
                        .font(Brand.title(24))
                        .multilineTextAlignment(.center)
                        .focused($focused)
                        .submitLabel(.done)
                        .onSubmit(save)
                        .padding(.vertical, 14)
                        .glass(cornerRadius: 18)

                    if editing == nil {
                        ScrollView(.horizontal) {
                            HStack {
                                ForEach(suggestions, id: \.self) { s in
                                    Button { withAnimation(Brand.spring) { name = s } } label: {
                                        ChoiceChip(title: s, selected: name == s)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .scrollIndicators(.hidden)
                    }

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(PhotoSet.symbols, id: \.self) { s in
                            Button { withAnimation(Brand.bouncy) { symbol = s } } label: {
                                Image(systemName: s)
                                    .font(.system(size: 18, weight: .semibold))
                                    .frame(width: 46, height: 46)
                                    .foregroundStyle(symbol == s ? .white : .primary)
                                    .background {
                                        if symbol == s { Circle().fill(Brand.gradient) }
                                    }
                                    .glassCircle()
                            }
                            .buttonStyle(PressableStyle())
                            .accessibilityLabel(Self.symbolName(s))
                            .accessibilityAddTraits(symbol == s ? .isSelected : [])
                        }
                    }
                }
                .padding(20)
            }
            .background(AnimatedBackground())
            .navigationTitle(editing == nil ? "New Set" : "Edit Set")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(editing == nil ? "Create" : "Save", action: save).fontWeight(.semibold)
                }
            }
            .sensoryFeedback(.selection, trigger: symbol)
        }
        .presentationDetents([.large])
        .presentationCornerRadius(32)
        .onAppear {
            if let editing {
                name = editing.name
                symbol = editing.symbol
            } else {
                focused = true
            }
        }
    }

    private func save() {
        if var set = editing {
            set.name = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? set.name : name
            set.symbol = symbol
            model.update(set)
            dismiss()
        } else {
            let set = model.createSet(name: name, symbol: symbol)
            dismiss()
            // Jump straight into the new set so the user can add photos.
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(350))
                router.path = [.set(set.id)]
            }
        }
    }
}

extension NewSetSheet {
    /// VoiceOver name for an icon, e.g. "moon.stars.fill" → "Moon stars".
    static func symbolName(_ symbol: String) -> String {
        let words = symbol.split(separator: ".").filter { $0 != "fill" && $0 != "2" }.joined(separator: " ")
        return words.prefix(1).uppercased() + words.dropFirst()
    }
}
