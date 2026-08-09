//
//  SoundManager.swift
//  MacClipboard
//
//  Created by Yunlong Zhang on 2026/7/29.
//

import AppKit

struct SoundManager {
    static func playCopySound() {
        guard AppSettings.shared.enableSoundEffects else { return }
        NSSound(named: "Tink")?.play()
    }
    
    static func playPasteSound() {
        guard AppSettings.shared.enableSoundEffects else { return }
        NSSound(named: "Pop")?.play()
    }
}
