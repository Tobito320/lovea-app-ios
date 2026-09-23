import SwiftUI

/// Z-27.2 letter, sealed until tapped; opens with a spring pop in place. Also used by the partner
/// profile's "Briefe" list (Agent B2) — keep `BriefBlase(titel:text:von:)`.
struct BriefBlase: View {
    let titel: String
    let text: String
    let von: Person
    @State private var geoeffnet = false
    @Environment(\.chatBackdrop) private var festerBackdrop
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var eigene: Bool { von == Raum.shared.ich }

    var body: some View {
        let backdrop = festerBackdrop ?? Backdrops.aktuell
        let fuellung = eigene
            ? AnyShapeStyle(LinearGradient(colors: backdrop.verlauf, startPoint: .topLeading, endPoint: .bottomTrailing))
            : AnyShapeStyle(backdrop.partnerBlase)
        Group {
            if geoeffnet {
                VStack(alignment: .leading, spacing: 6) {
                    Label(titel, systemImage: "envelope.open.fill").font(.headline)
                    Text(text)
                }
                .padding(12)
                .transition(.scale(scale: 0.85).combined(with: .opacity))
            } else {
                // A tap gesture, not a Button: a Button inside the bubble would swallow the long press.
                VStack(spacing: 6) {
                    Image(systemName: "envelope.fill").font(.title2)
                    Text("Brief").font(.subheadline.weight(.semibold))
                    Text("„\(titel)“").font(.caption).lineLimit(1)
                }
                .frame(width: 160, height: 110)
                .contentShape(.rect)
                .onTapGesture(perform: oeffnen)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Brief „\(titel)“")
                .accessibilityHint("Öffnen")
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { oeffnen() }
            }
        }
        .foregroundStyle(eigene ? backdrop.eigeneText : backdrop.partnerText)
        .background(fuellung, in: .rect(cornerRadius: 18))
    }

    private func oeffnen() {
        Haptik.mittel()
        withAnimation(reduceMotion ? .easeOut(duration: 0.2) : Feder.federnd) { geoeffnet = true }
    }
}

/// Plus → Brief (Z-32.3): title and text, then send. The time capsule is gone (Spec 2.10).
struct BriefBlatt: View {
    @Environment(\.dismiss) private var dismiss
    @State private var titel = ""
    @State private var text = ""

    private var kannSenden: Bool {
        !titel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Titel") {
                    TextField("z. B. Für dich", text: $titel)
                }
                Section("Brief") {
                    TextField("Text", text: $text, axis: .vertical).lineLimit(5...12)
                }
            }
            .navigationTitle("Brief")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Senden") {
                        ChatModell.shared.briefSenden(titel: titel, text: text)
                        Haptik.leicht()
                        dismiss()
                    }
                    .disabled(!kannSenden)
                }
            }
        }
        .presentationDetents([.large])
    }
}
