import Foundation
import AppKit
import AVFoundation

class CelebrationService {
    static let shared = CelebrationService()
    private var audioPlayer: AVAudioPlayer?

    func playCelebrationSound() {
        // Play a combo of sounds for a more satisfying effect
        // First play Funk (punchy)
        if let funkSound = NSSound(named: "Funk") {
            funkSound.play()
        }

        // Then play Glass after a tiny delay for a sparkle effect
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            if let glassSound = NSSound(named: "Glass") {
                glassSound.play()
            }
        }
    }
}
