//
//  FolderShape.swift
//  Podz
//
//  Created by Max Prx on 22/08/2026.
//

import SwiftUI

/// A classic folder silhouette — a small tab at the top-left plus a
/// rounded body — used both closed (as the icon on the overview grid)
/// and open (as the container wrapping a folder's contents).
struct FolderShape: Shape {
    var tabWidthRatio: CGFloat = 0.42
    var tabHeightRatio: CGFloat = 0.14
    var cornerRadius: CGFloat = 14

    func path(in rect: CGRect) -> Path {
        let tabHeight = rect.height * tabHeightRatio
        let bodyTop = rect.minY + tabHeight

        var path = Path()

        // Body
        path.addRoundedRect(
            in: CGRect(x: rect.minX, y: bodyTop, width: rect.width, height: rect.height - tabHeight),
            cornerSize: CGSize(width: cornerRadius, height: cornerRadius),
            style: .continuous
        )

        return path
    }
}
