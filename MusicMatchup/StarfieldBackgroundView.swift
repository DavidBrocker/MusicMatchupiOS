//
//  StarfieldBackgroundView.swift
//  MusicMatchup
//
//  Created by David Brocker on 7/1/26.
//

import SwiftUI

// A faint, non-interactive starfield — randomized once, then given a slow
// per-layer drift (no user input, no physics engine). Three depth layers
// moving at different speeds give a parallax feel cheaply, using a single
// Canvas draw rather than per-star SwiftUI views. Shown behind both the
// splash/search screen and the live constellation, so the background stays
// visually continuous across that transition instead of swapping to a
// different decorative view.
struct StarfieldBackgroundView: View {
    @State private var layers: [StarLayer] = []

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1 / 30, paused: layers.isEmpty)) { timeline in
                Canvas { context, size in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    for layer in layers {
                        let dx = CGFloat(sin(t * layer.driftSpeed + layer.phase)) * layer.driftAmplitude
                        let dy = CGFloat(cos(t * layer.driftSpeed * 0.7 + layer.phase)) * layer.driftAmplitude * 0.6
                        for star in layer.stars {
                            let rect = CGRect(
                                x: star.position.x + dx - star.size / 2,
                                y: star.position.y + dy - star.size / 2,
                                width: star.size,
                                height: star.size
                            )
                            context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(star.opacity)))
                        }
                    }
                }
            }
            .onAppear {
                if layers.isEmpty {
                    // Guard against a collapsed/zero size being reported
                    // mid-transition — falls back to the screen bounds so
                    // stars never end up randomized into a 0...0 range
                    // (which would render them invisibly stacked at the origin).
                    let effectiveSize = geo.size == .zero ? UIScreen.main.bounds.size : geo.size
                    layers = Self.bakedLayers(in: effectiveSize)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private static func bakedLayers(in size: CGSize) -> [StarLayer] {
        [
            // Far layer: smallest, dimmest, slowest — most of the density.
            StarLayer(
                stars: makeStars(count: 65, size: 1.0...1.8, opacity: 0.08...0.18, in: size),
                driftSpeed: 0.018, driftAmplitude: 5, phase: .random(in: 0...(2 * .pi))
            ),
            StarLayer(
                stars: makeStars(count: 50, size: 1.6...2.6, opacity: 0.16...0.30, in: size),
                driftSpeed: 0.032, driftAmplitude: 9, phase: .random(in: 0...(2 * .pi))
            ),
            // Near layer: fewest, brightest, fastest — reads as foreground.
            StarLayer(
                stars: makeStars(count: 25, size: 2.2...3.6, opacity: 0.26...0.42, in: size),
                driftSpeed: 0.05, driftAmplitude: 15, phase: .random(in: 0...(2 * .pi))
            ),
        ]
    }

    private static func makeStars(count: Int, size: ClosedRange<CGFloat>, opacity: ClosedRange<Double>, in canvasSize: CGSize) -> [Star] {
        (0..<count).map { _ in
            Star(
                position: CGPoint(
                    x: CGFloat.random(in: 0...canvasSize.width),
                    y: CGFloat.random(in: 0...canvasSize.height)
                ),
                size: CGFloat.random(in: size),
                opacity: Double.random(in: opacity)
            )
        }
    }
}

private struct StarLayer {
    let stars: [Star]
    let driftSpeed: Double
    let driftAmplitude: CGFloat
    let phase: Double
}

private struct Star {
    let position: CGPoint
    let size: CGFloat
    let opacity: Double
}
