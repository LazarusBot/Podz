import SwiftUI

/// A single "label + helper text ... control" row, separated by a
/// hairline divider below it. Matches the repeated row pattern in the
/// Figma frame (Hikers / Check-in / Checkout / Wifi / Pets).
struct FilterRow<Control: View>: View {
    let title: String
    let helper: String
    @ViewBuilder var control: () -> Control

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(AppFont.itemTitle())
                        .foregroundColor(.appTextPrimary)
                    Text(helper)
                        .font(AppFont.itemHelper())
                        .foregroundColor(.appTextSecondary)
                }
                Spacer()
                control()
            }
            .padding(.horizontal, 20)

            Divider()
                .background(Color.appBorder)
                .padding(.top, 12)
        }
    }
}

/// Reproduces the "Locations" filter panel, node 3665:1015.
struct FiltersView: View {
    @State private var hikers: Int = 0
    @State private var checkIn: String = "22 october 2027"
    @State private var checkOut: String = "28 october 2027"
    @State private var wifi: Bool = true
    @State private var pets: Bool = true

    var body: some View {
        VStack(spacing: 18) {
            // Top bar: location chip, active Filters pill, add button
            HStack(spacing: 10) {
                PillChip(title: "Slovenia", badgeCount: 1)
                PillButton(title: "Filters", icon: "slider.horizontal.3")
                PillIconButton(systemImage: "plus")
            }
            .padding(10)
            .pillStyle()

            Divider().background(Color.appBorder)

            FilterRow(title: "Hikers", helper: "Number of hikers with you.") {
                StepperControl(value: $hikers)
            }

            FilterRow(title: "Check-in", helper: "Date of arrival in your pod.") {
                Text(checkIn)
                    .font(AppFont.pillLabel())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .pillStyle()
            }

            FilterRow(title: "Checkout", helper: "Date of leaving from your pod.") {
                Text(checkOut)
                    .font(AppFont.pillLabel())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .pillStyle()
            }

            FilterRow(title: "Wifi", helper: "Location is wired or not.") {
                ToggleCheckButton(isOn: $wifi)
            }

            FilterRow(title: "Pets", helper: "Pets are allowed in the pod or not.") {
                ToggleCheckButton(isOn: $pets)
            }

            PillButton(title: "Save") {
                // TODO: wire up save action
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.appBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .strokeBorder(Color.appBorder, lineWidth: 0.5)
                )
        )
        .padding()
    }
}

struct FiltersView_Previews: PreviewProvider {
    static var previews: some View {
        FiltersView()
    }
}
