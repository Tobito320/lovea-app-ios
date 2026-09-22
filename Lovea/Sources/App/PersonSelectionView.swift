import SwiftUI

struct PersonSelectionView: View {
    let onSelect: (LoveaPerson) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            Spacer()

            VStack(alignment: .leading, spacing: 8) {
                Text("Lovea")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                Text("Wer bist du gerade?")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 0) {
                ForEach(LoveaPerson.allCases, id: \.self) { person in
                    Button {
                        onSelect(person)
                    } label: {
                        HStack {
                            Text(person.rawValue)
                                .font(.title2.weight(.semibold))
                            Spacer()
                            Image(systemName: "arrow.right")
                                .foregroundStyle(.secondary)
                        }
                        .frame(minHeight: 64)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if person != LoveaPerson.allCases.last {
                        Divider()
                    }
                }
            }

            Spacer()
        }
        .padding(28)
        .background(Color(uiColor: .systemBackground))
    }
}
