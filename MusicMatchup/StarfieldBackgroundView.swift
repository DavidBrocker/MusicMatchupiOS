//
//  StarfieldBackgroundView.swift
//  MusicMatchup
//
//  Created by David Brocker on 7/1/26.
//

import SwiftUI

// A faint, non-interactive starfield drawn behind the live constellation.
// Reuses the same "randomized once, no physics" trick as the splash screen's
// GhostConstellationView, but spreads across the full canvas rather than
// clustering toward a center point.
struct StarfieldBackgroundView: View {
    @State private var stars: [Star] = []

    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                for star in stars {
                    let rect = CGRect(
                        x: star.position.x - star.size / 2,
                        y: star.position.y - star.size / 2,
                        width: star.size,
                        height: star.size
                    )
                    context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(star.opacity)))
                }
            }
            .onAppear {
                if stars.isEmpty {
                    // Guard against a collapsed/zero size being reported
                    // mid-transition — falls back to the screen bounds so
                    // stars never end up randomized into a 0...0 range
                    // (which would render them invisibly stacked at the origin).
                    let effectiveSize = geo.size == .zero ? UIScreen.main.bounds.size : geo.size
                    stars = Self.bakedStars(in: effectiveSize)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private static func bakedStars(in size: CGSize) -> [Star] {
        (0..<140).map { _ in
            Star(
                position: CGPoint(
                    x: CGFloat.random(in: 0...size.width),
                    y: CGFloat.random(in: 0...size.height)
                ),
                size: CGFloat.random(in: 1.5...3.5),
                opacity: Double.random(in: 0.15...0.4)
            )
        }
    }
}

private struct Star {
    let position: CGPoint
    let size: CGFloat
    let opacity: Double
}
