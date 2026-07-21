//
//  AppleMusicModels.swift
//  MuseAmp
//
//  Created by Hwang on 2026/07/20.
//

import Foundation

nonisolated enum AppleMusicAuthorizationState: Equatable {
    case notDetermined
    case denied
    case restricted
    case authorized
}

nonisolated struct AppleMusicPlaylistSummary: Hashable, Identifiable {
    let id: String
    let name: String
    let curatorName: String?
}

nonisolated struct AppleMusicSongSummary: Hashable {
    let title: String
    let artistName: String
    let albumTitle: String?
    let durationMillis: Int?
}
