import SwiftUI

// MARK: - NexusDesign: Metrics
//
// Shared spacing, corner radius, blur, and stroke values. These do NOT
// override the island's own corner constants in `Constants.swift`
// (compact 18 / expanded 22 / fullExpanded 40) — those stay authoritative
// for the pill shape. These tokens are for cards, chips, and controls.

enum NexusMetrics {
    static let cornerRadiusS: CGFloat = 10
    static let cornerRadiusM: CGFloat = 16
    static let cornerRadiusL: CGFloat = 24
    static let blurStandard: CGFloat = 20
    static let strokeHairline: CGFloat = 0.5
    static let spacingUnit: CGFloat = 8
}
