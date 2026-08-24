//
//  LennySearchBar.swift
//  Podz
//
//  Created by Max Prx on 21/08/2026.
//

import SwiftUI

/// Replaces the HomeSearchRow entirely while active (screen 3796:276
/// idle/editing, 3796:690 searching). Idle = the small "Lenny" chip
/// lives back in HomeSearchRow as before; this view only exists once
/// tapped.
struct LennySearchBar: View {
    @ObservedObject var viewModel: LennySearchViewModel
    @FocusState private var isFocused: Bool
    
    /// "Lenny speaking : " (bold) + "Your plan is ready !" (medium) —
    /// built with AttributedString since Text's `+` operator is
    /// deprecated (same pattern as ProfilePromoCard.promoTitle).
    private var readyMessage: AttributedString {
        var bold = AttributeContainer()
        bold.font = AppFont.mediumLabel()
        let prefix = AttributedString("Lenny speaking : ", attributes: bold)
        
        var medium = AttributeContainer()
        medium.font = AppFont.mediumLabel()
        let suffix = AttributedString("Your plan is ready !", attributes: medium)
        
        return prefix + suffix
    }
    
    var body: some View {
        HStack(spacing: 15) {
            LennyIcon(size: 14)
            
            switch viewModel.phase {
            case .editing:
                TextField(
                    "Describe your hike itinerary and Lenny will carry on...",
                    text: $viewModel.itineraryText,
                    axis: .vertical
                )
                .font(AppFont.mediumLabel())
                .focused($isFocused)
                .submitLabel(.search)
                .onChange(of: viewModel.itineraryText) { _, newValue in
                    // axis: .vertical eats the return key as a newline
                    // instead of firing onSubmit — detect it manually,
                    // strip it, and treat it as "search" instead.
                    guard newValue.hasSuffix("\n") else { return }
                    viewModel.itineraryText.removeLast()
                    Task { await viewModel.submit() }
                }
                
            case .searching:
                Text("Lenny is searching...")
                    .font(AppFont.mediumLabel())
                
            case .results:
                Text(readyMessage)
                    .lineLimit(1)
                
            default:
                EmptyView()
            }
            
            Spacer()
            
            if viewModel.phase == .editing && !viewModel.itineraryText.isEmpty {
                Button {
                    Task { await viewModel.submit() }
                } label: {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.appAccentBlack)
                }
            }
            
            if viewModel.phase != .idle {
                Button {
                    viewModel.cancel()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.appTextMuted)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .modifier(LennyBarStyle(showBorder: viewModel.phase == .editing))
        .onChange(of: isFocused) { _, newValue in
            // Local FocusState changed (user tapped the field, or the
            // system dismissed the keyboard) — mirror it up to the
            // shared view model.
            viewModel.isKeyboardFocused = newValue
        }
        .onChange(of: viewModel.isKeyboardFocused) { _, newValue in
            // View model changed it programmatically (cancel()/submit()
            // calling for a dismiss) — mirror it down to the real
            // FocusState that actually controls the keyboard.
            isFocused = newValue
        }
        .onAppear { isFocused = viewModel.isKeyboardFocused }
    }
}

/// Only applies the pill chrome (border, shadow, background) while
/// actively editing — searching/results show plain text, so the
/// textfield-like appearance would be misleading once it's not
/// actually editable anymore.
private struct LennyBarStyle: ViewModifier {
    let showBorder: Bool
    
    func body(content: Content) -> some View {
        if showBorder {
            content.pillStyle()
        } else {
            content
        }
    }
}

/// The small "Lenny" mark (12x12), reused in the chip, the search bar,
/// and the searching-state header. Custom SVG asset if present, else a
/// simple fallback so nothing breaks before it's exported.
struct LennyIcon: View {
    var size: CGFloat = 12
    
    var body: some View {
        Group {
            if UIImage(named: "lenny") != nil {
                Image("lenny").resizable()
            } else {
                Image(systemName: "sparkles").resizable()
            }
        }
        .aspectRatio(contentMode: .fit)
        .frame(width: size, height: size)
    }
}

#Preview {
    LennySearchBar(viewModel: LennySearchViewModel())
        .padding()
        .background(Color.appHomeBackground)
}
