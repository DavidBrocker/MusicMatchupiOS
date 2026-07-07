import SwiftUI

struct GhostConstellationView: View {
    @State private var nodes: [GhostNode] = []
    @State private var edges: [(Int, Int)] = []

    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                for edge in edges {
                    guard edge.0 < nodes.count, edge.1 < nodes.count else { continue }
                    var path = Path()
                    path.move(to: nodes[edge.0].position)
                    path.addLine(to: nodes[edge.1].position)
                    context.stroke(path, with: .color(.secondary.opacity(0.08)), lineWidth: 0.75)
                }

                for node in nodes {
                    let rect = CGRect(
                        x: node.position.x - node.size / 2,
                        y: node.position.y - node.size / 2,
                        width: node.size,
                        height: node.size
                    )
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(.secondary.opacity(node.opacity))
                    )
                }
            }
            .onAppear {
                if nodes.isEmpty {
                    nodes = Self.bakedLayout(in: geo.size)
                    edges = Self.bakedEdges(nodeCount: nodes.count)
                }
            }
        }
        .allowsHitTesting(false)
    }

    // Pre-baked, randomized-once layout. No physics, no timers — costs nothing at runtime.
    private static func bakedLayout(in size: CGSize) -> [GhostNode] {
        let center = CGPoint(x: size.width / 2, y: size.height * 0.42)
        var result: [GhostNode] = []
        let count = 70

        for _ in 0..<count {
            let angle = CGFloat.random(in: 0...(2 * .pi))
            // Bias toward center using sqrt of a random value, so density
            // is highest in the middle and thins toward the edges
            let radius = sqrt(CGFloat.random(in: 0...1)) * min(size.width, size.height) * 0.42
            let pos = CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )
            result.append(
                GhostNode(
                    position: pos,
                    size: CGFloat.random(in: 14...34),
                    opacity: Double.random(in: 0.08...0.22)
                )
            )
        }
        return result
    }

    private static func bakedEdges(nodeCount: Int) -> [(Int, Int)] {
        guard nodeCount > 1 else { return [] }
        var result: [(Int, Int)] = []
        // Sparse, semi-random connections — enough to read as a network,
        // not so many it becomes a solid mess
        for i in 0..<nodeCount {
            let connections = Int.random(in: 1...3)
            for _ in 0..<connections {
                let target = Int.random(in: 0..<nodeCount)
                if target != i {
                    result.append((i, target))
                }
            }
        }
        return result
    }
}

private struct GhostNode {
    let position: CGPoint
    let size: CGFloat
    let opacity: Double
}
