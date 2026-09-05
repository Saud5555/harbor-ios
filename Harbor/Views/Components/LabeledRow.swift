import SwiftUI

struct LabeledRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(Theme.textPrimary)
            Spacer()
            Text(value)
                .foregroundColor(Theme.textSecondary)
        }
    }
}
