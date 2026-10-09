import SwiftUI

/// Round head crop of one person with a white ring and their own online dot.
/// The head sits at y 30...152 of FigurView's 240-unit canvas, centre about 0.38 of the height:
/// at `groesse = 1.6d` that is 0.19 d above the view centre.
struct ProfilAvatar: View {
    let person: Person
    let online: Bool
    let d: CGFloat
    /// Thin rose ring around the avatar, 0...1 of the way to the next milestone (`Meilenstein`); nil = none.
    var fortschritt: Double? = nil

    var body: some View {
        FigurView(FigurenModell.shared.aussehen(person), zustand: .ruhig, groesse: d * 1.6, animiert: false)
            .offset(y: d * 0.19)
            .frame(width: d, height: d)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(Circle())
            .overlay(Circle().stroke(.white, lineWidth: 3))
            .overlay {
                if let fortschritt {
                    ZStack {
                        Circle().stroke(Color.loveaRose.opacity(0.22), lineWidth: 2.5)
                        Circle().trim(from: 0, to: fortschritt)
                            .stroke(Color.loveaRose, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    }
                    .frame(width: d + 7, height: d + 7)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if online {
                    Circle().fill(.green)
                        .frame(width: d * 0.22, height: d * 0.22)
                        .overlay(Circle().stroke(.white, lineWidth: 2.5))
                        .offset(x: -1, y: -1)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(person.name), \(online ? "online" : "offline")")
    }
}

/// p61: the profile header is for the two of them: both round avatars side by side (Ahmed, Annika),
/// each with its own online dot. `ich` is whoever holds the phone: their dot is the connection, the
/// other one's is the partner being there.
struct ProfilPaarAvatare: View {
    let ich: Person
    var d: CGFloat = 56

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Person.allCases, id: \.self) { p in
                ProfilAvatar(person: p, online: p == ich ? Raum.shared.verbunden : Raum.shared.partnerDa, d: d)
            }
        }
    }

    static let titel = "\(Person.ahmed.name) & \(Person.annika.name)"
}
