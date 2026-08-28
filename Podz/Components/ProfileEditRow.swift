//
//  ProfileEditRow.swift
//  Podz
//
//  Created by Max Prx on 20/08/2026.
//

import SwiftUI

/// "@bosoveille / Edit username" row with trailing pencil icon (node
/// pattern repeated for username/name/age/location, 3827:1559 etc).
/// Same padding as ProfileAccountRow (24h/31v) — visually this screen
/// reuses that row rhythm rather than the tighter 18v menu rows.
struct ProfileEditRow: View {
    let value: String
    let label: String
    var onTap: () -> Void = {}

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(value)
                        .font(AppFont.pillLabelSemiBold(16))
                        .foregroundColor(.black)
                    Text(label)
                        .font(AppFont.mediumLabel(11))
                        .foregroundColor(.appTextMuted)
                }
                Spacer()
                Image(systemName: "pencil")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.black)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 31)
        .background(Color.appHomeBackground)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.black.opacity(0.1)).frame(height: 0.5)
        }
    }
}
