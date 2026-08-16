import SwiftUI

/// Shared "signature" section used in Settings across all Kašpárek iOS apps.
/// Keep this file and the KasparekCrown asset identical in every app.
struct KasparekSignatureSection: View {
    var body: some View {
        Section {
            HStack(spacing: 14) {
                Image("KasparekCrown")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 34, height: 34)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: "Jakub Kašpárek")
                        .font(.subheadline.weight(.semibold))
                    Text(verbatim: "Made in 🇨🇿")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 2)
            .accessibilityElement(children: .combine)

            if let url = URL(string: "https://kasparek.net") {
                Link(destination: url) {
                    Label {
                        Text(verbatim: "kasparek.net")
                    } icon: {
                        Image(systemName: "link")
                    }
                    .font(.footnote)
                }
            }

            if let url = URL(string: "https://apps.kasparek.app") {
                Link(destination: url) {
                    Label {
                        Text("More apps")
                    } icon: {
                        Image(systemName: "square.grid.2x2")
                    }
                    .font(.footnote)
                }
            }
        }
    }
}
