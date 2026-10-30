import Foundation

/// Switches for parts of the app that are built but parked. Flip one to
/// bring it back; nothing here deletes any code.
enum FeatureFlags {
    /// The host side: becoming a host, the host mode switch, the host tabs
    /// and the Add-a-pod form. Parked while the traveler part is finished.
    static let hosting = false
}
