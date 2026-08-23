//
//  LennySearchSteps.swift
//  Podz
//
//  Created by Max Prx on 21/08/2026.
//

import SwiftUI

/// The 3-step progress list under the search bar while Lenny works
/// (node 3806:878 / 3802:850 / 3802:854). Done steps are solid black
/// with a filled dot; the pending step is grayed out with a hollow dot —
/// matches the gradient-text treatment in Figma via reduced opacity.
struct LennySearchSteps: View {
    let steps: [LennySearchViewModel.StepInfo]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            ForEach(steps) { step in
                HStack(alignment: .top, spacing: 12) {
                    Circle()
                        .fill(step.isDone ? Color.black : Color.clear)
                        .overlay(Circle().strokeBorder(Color.appTextMuted.opacity(0.4), lineWidth: step.isDone ? 0 : 1))
                        .frame(width: 12, height: 12)
                        .padding(.top, 2)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(step.title)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(step.isDone ? .black : .appTextMuted.opacity(0.5))
                        if !step.subtitle.isEmpty {
                            Text(step.subtitle)
                                .font(.system(size: 8, weight: .medium))
                                .foregroundColor(step.isDone ? .appTextMuted : .appTextMuted.opacity(0.5))
                        }
                    }
                }
                .animation(.easeOut(duration: 0.3), value: step.isDone)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
    }
}
