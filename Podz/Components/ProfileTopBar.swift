import SwiftUI

/// Header row: back button (31x31 circle) — centered title — empty
/// trailing spacer (node 3827:1382). Padding is 24 horizontal / 31
/// vertical exactly as in Figma — don't round these to 20/32.
struct ProfileTopBar: View {
    var title: String = "Profile"
    var onBack: (() -> Void)? = nil
    
    var body: some View {
        HStack {
            if let onBack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(width: 31, height: 31)
                }
                .background(Circle().fill(Color.white))
                .overlay(Circle().strokeBorder(Color.appBorder, lineWidth: 0.5))
            } else {
                Color.clear.frame(width: 31, height: 31)
            }
            
            Spacer()
            
            Text(title)
                .font(AppFont.pillLabel(24))
                .fontWeight(.heavy)
                .foregroundColor(.black)
            
            Spacer()
            
            // Empty 31x31 placeholder to keep the title perfectly centered
            // (matches the empty circle on the right in Figma, node 3827:1386).
            Color.clear.frame(width: 31, height: 31)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 31)
        .background(Color.appHomeBackground)
    }
}
