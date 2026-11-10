//
//  GraphNode.swift
//  MusicMatchup
//
//  Created by David Brocker on 6/17/26.
//

import SwiftUI
import Combine

class GraphNode: ObservableObject, Identifiable {
    let id: String
    let name: String
    let imageURL: URL?
    var position: CGPoint
    var velocity: CGPoint = .zero
    var isPinned: Bool = false
    var depth: Int
    var isExpanded: Bool = false

    // Which "galaxy" (seed search) this node traces back to, expressed as a
    // hue (0...1) rather than a fixed Color so the render side can vary
    // saturation/brightness (dimming, selection) without losing the identity
    // color. Set post-init by ForceSimulation — a fresh hue for a new seed
    // in load(), inherited from the tapped node for anything spawned via
    // expand() — same idea as `depth`, just propagated down the tree instead
    // of incremented.
    var galaxyHue: Double = 0

    init(id: String, name: String, imageURL: URL?, position: CGPoint, depth: Int = 0) {
        self.id = id
        self.name = name
        self.imageURL = imageURL
        self.position = position
        self.depth = depth
    }
    
    var nodeSize: CGFloat {
        switch depth {
        case 0: return 72
        case 1: return 52
        case 2: return 38
        default: return 28
        }
    }
}
