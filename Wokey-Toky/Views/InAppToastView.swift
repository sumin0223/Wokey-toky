//
//  InAppToastView.swift
//  Wokey-Toky
//

import SwiftUI

struct InAppToastView: View {
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
            Text(message)
                .font(.subheadline)
                .lineLimit(2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(radius: 8)
        .padding(.top, 12)
        .padding(.horizontal, 16)
    }
}
