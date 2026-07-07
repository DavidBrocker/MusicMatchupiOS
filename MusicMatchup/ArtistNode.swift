//
//  ArtistNode.swift
//  MusicMatcup
//
//  Created by David Brocker on 6/16/26.
//

import Foundation
import MusicKit

struct ArtistNode: Identifiable, Hashable {
    let id: MusicItemID
    let name: String
    let imageURL: URL?
    var connections: [MusicItemID] = []
}

