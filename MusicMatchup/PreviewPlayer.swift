//
//  PreviewPlayer.swift
//  MusicMatchup
//
//  Created by David Brocker on 6/17/26.
//


import Foundation
import AVFoundation
import MusicKit


@Observable
@MainActor
class PreviewPlayer {
    var currentArtistID: String? = nil
    var currentArtistName: String? = nil
    var currentTrackName: String? = nil
    var currentArtworkURL: URL? = nil
    var isPlaying: Bool = false
    
    // Detail sheet state
    var genreNames: [String] = []
    var topSongs: [Song] = []
    var isFollowing: Bool = false
    
    private var player: AVPlayer?
    private var autoStopTask: Task<Void, Never>?
    
    func play(artistID: String, artistName: String, imageURL: URL?) async {
        do {
            var request = MusicCatalogResourceRequest<Artist>(
                matching: \.id,
                equalTo: MusicItemID(artistID)
            )
            request.properties = [.topSongs, .genres]
            let response = try await request.response()
            
            guard let artist = response.items.first,
                  let songs = artist.topSongs
            else { return }
            
            self.topSongs = Array(songs)
            self.genreNames = artist.genreNames ?? []
            self.currentArtistID = artistID
            
            guard let firstSong = songs.first else { return }
            await playSong(firstSong, artistName: artistName, imageURL: imageURL)
            
        } catch {
            print("Preview error: \(error)")
        }
    }

    func playSong(_ song: Song, artistName: String, imageURL: URL?) async {
        guard let previewURL = song.previewAssets?.first?.url else {
            print("No preview available for \(song.title)")
            return
        }
        
        self.stopPlaybackOnly()
        self.player = AVPlayer(url: previewURL)
        self.player?.play()
        self.currentArtistName = artistName
        self.currentTrackName = song.title
        self.currentArtworkURL = imageURL
        self.isPlaying = true
        
        autoStopTask?.cancel()
        autoStopTask = Task {
            try? await Task.sleep(for: .seconds(30))
            guard !Task.isCancelled else { return }
            self.stopPlaybackOnly()
        }
    }
    
    // Stops audio but keeps the sheet's song list / artist info around
    private func stopPlaybackOnly() {
        player?.pause()
        player = nil
        isPlaying = false
    }
    
    // Fully closes the mini player and clears artist context
    func stop() {
        autoStopTask?.cancel()
        stopPlaybackOnly()
        currentArtistID = nil
        currentArtistName = nil
        currentTrackName = nil
        currentArtworkURL = nil
        topSongs = []
        genreNames = []
        isFollowing = false
    }
    
    func toggleFollow() {
        isFollowing.toggle()
        // Hook point for a real "follow" persistence layer later
    }
}
