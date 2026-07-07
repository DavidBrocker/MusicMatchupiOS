//
//  StarfieldBackgroundView.swift
//  MusicMatchup
//
//  Created by David Brocker on 7/1/26.
//

import SwiftUI

// A very faint, non-interactive starfield drawn behind the live constellation.
// Reuses the same "randomized once, no physics" trick as the splash screen's
// GhostConstellationView, but spreads across the full canvas rather than
// clustering toward a center point, and is dimmed further so it never
// competes visually with the real graph in front of it.
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
                    context.fill(Path(ellipseIn: rect), with: .color(.secondary.opacity(star.opacity)))
                }
            }
            .onAppear {
                if stars.isEmpty {
                    stars = Self.bakedStars(in: geo.size)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private static func bakedStars(in size: CGSize) -> [Star] {
        (0..<90).map { _ in
            Star(
                position: CGPoint(
                    x: CGFloat.random(in: 0...size.width),
                    y: CGFloat.random(in: 0...size.height)
                ),
                size: CGFloat.random(in: 1.5...4),
                opacity: Double.random(in: 0.04...0.12)
            )
        }
    }
}

private struct Star {
    let position: CGPoint
    let size: CGFloat
    let opacity: Double
}