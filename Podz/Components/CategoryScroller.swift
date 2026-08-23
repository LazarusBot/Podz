import SwiftUI

/// One chip in the category scroller. `isSelected` matches the black-filled
/// "Hikes" state in Figma; unselected chips are white pills.
struct CategoryChip: View {
    let title: String
    var count: Int? = nil
    var isSelected: Bool = false
    var gradientText: Bool = false   // matches the "Lenny" grayscale-gradient label
    var icon: String? = nil          // SF Symbol shown before the label
    var action: () -> Void = {}
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon {
                    ChipIcon(name: icon, isSelected: isSelected, gradientText: gradientText)
                }
                
                Group {
                    if gradientText {
                        Text(title)
                            .font(AppFont.pillLabel(17))
                            .foregroundStyle(
                                LinearGradient(colors: [Color(white: 0.77), .black],
                                               startPoint: .top, endPoint: .bottom)
                            )
                    } else {
                        Text(title)
                            .font(AppFont.pillLabel(17))
                            .foregroundColor(isSelected ? .white : .black)
                    }
                }
                
                if let count {
                    Text("\(count)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(isSelected ? .black : .white)
                        .frame(width: 18, height: 18)
                        .background(Circle().fill(isSelected ? Color.white : Color.black))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .pillStyle(fill: isSelected ? .appAccentBlack : .white, border: .appBorder)
    }
}

/// Custom asset if present
/// falls back to SF Symbol otherwise — same pattern as TabIcon.
private struct ChipIcon: View {
    let name: String
    let isSelected: Bool
    var gradientText: Bool = false
    
    var body: some View {
        Group {
            if UIImage(named: name) != nil {
                Image(name)
                    .resizable()
                    .renderingMode(.template)
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: name)
            }
        }
        .frame(width: 14, height: 14)
        .modifier(ChipIconTint(isSelected: isSelected, gradientText: gradientText))
    }
}

/// Applies either the plain white/black tint or the same grayscale
/// gradient used on the "Lenny" text — kept as a ViewModifier since
/// .foregroundStyle needs a concrete type per branch, not an `if/else`
/// returning different View types directly.
private struct ChipIconTint: ViewModifier {
    let isSelected: Bool
    let gradientText: Bool
    
    func body(content: Content) -> some View {
        if gradientText {
            content.foregroundStyle(
                LinearGradient(colors: [Color(white: 0.77), .black],
                               startPoint: .top, endPoint: .bottom)
            )
        } else {
            content.foregroundStyle(isSelected ? Color.white : Color.black)
        }
    }
}

/// Horizontal scroller for category chips (node 3779:2063).
struct CategoryScroller: View {
    struct Category: Identifiable {
        let id = UUID()
        let title: String
        var count: Int? = nil
        var icon: String? = nil
        var gradientText: Bool = false
    }
    
    let categories: [Category]
    @Binding var selected: String
    var onTapLenny: () -> Void = {}
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(categories) { category in
                    CategoryChip(
                        title: category.title,
                        count: category.count,
                        isSelected: selected == category.title,
                        gradientText: category.gradientText,
                        icon: category.icon
                    ) {
                        if category.title == "Lenny" {
                            onTapLenny()
                        } else {
                            selected = category.title
                        }
                    }
                }
            }
            .padding(.trailing, 24)
            .padding(.leading, 24)
            .padding(.bottom, 20)
        }
        .background(
            LinearGradient(
                stops: [.init(color: Color.appHomeBackground.opacity(0.95), location: 0.68),
                        .init(color: Color.appHomeBackground.opacity(0), location: 1)],
                startPoint: .top, endPoint: .bottom
            )
        )
    }
}
