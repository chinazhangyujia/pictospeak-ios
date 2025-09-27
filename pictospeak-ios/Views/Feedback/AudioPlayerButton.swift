//
//  AudioPlayerButton.swift
//  pictospeak-ios
//
//  Created by AI Assistant.
//

import AVFoundation
import SwiftUI

struct AudioPlayerButton: View {
    let audioUrl: String
    let foregroundColorPlaying: Color
    let foregroundColorNotPlaying: Color
    let backgroundColorPlaying: Color
    let backgroundColorNotPlaying: Color

    @State private var isPlaying = false
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isLoading = false
    @State private var hasError = false
    @State private var audioDelegate: AudioPlayerDelegate?

    init(audioUrl: String,
         foregroundColorPlaying: Color = .primary,
         foregroundColorNotPlaying: Color = .primary,
         backgroundColorPlaying: Color = Color(red: 0.549, green: 0.549, blue: 0.549),
         backgroundColorNotPlaying: Color = Color(red: 0.549, green: 0.549, blue: 0.549))
    {
        self.audioUrl = audioUrl
        self.foregroundColorPlaying = foregroundColorPlaying
        self.foregroundColorNotPlaying = foregroundColorNotPlaying
        self.backgroundColorPlaying = backgroundColorPlaying
        self.backgroundColorNotPlaying = backgroundColorNotPlaying
    }

    var body: some View {
        Button(action: {
            if isPlaying {
                stopAudio()
            } else {
                playAudio()
            }
        }) {
            if isLoading {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 16, height: 16)
            } else if hasError {
                Image(systemName: "speaker.slash")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.gray)
            } else {
                Image(systemName: isPlaying ? "speaker.wave.3" : "speaker.wave.2")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(isPlaying ? foregroundColorPlaying : foregroundColorNotPlaying)
            }
        }
        .frame(width: 44, height: 44)
        .background(isPlaying ? backgroundColorPlaying : backgroundColorNotPlaying)
        .clipShape(Circle())
        .disabled(isLoading || hasError)
        .onDisappear {
            stopAudio()
        }
    }

    private func playAudio() {
        guard let url = URL(string: audioUrl) else {
            hasError = true
            return
        }

        isLoading = true
        hasError = false

        // Download and play audio from URL
        URLSession.shared.dataTask(with: url) { data, _, error in
            DispatchQueue.main.async {
                isLoading = false

                guard let data = data, error == nil else {
                    hasError = true
                    return
                }

                do {
                    // Configure audio session for playback
                    try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
                    try AVAudioSession.sharedInstance().setActive(true)

                    // Create and configure audio player
                    audioPlayer = try AVAudioPlayer(data: data)

                    // Create and store delegate
                    audioDelegate = AudioPlayerDelegate { [weak audioPlayer] in
                        DispatchQueue.main.async {
                            // Check if this is still the current audio player
                            if audioPlayer === self.audioPlayer {
                                self.isPlaying = false
                            }
                        }
                    }

                    audioPlayer?.delegate = audioDelegate

                    audioPlayer?.prepareToPlay()
                    audioPlayer?.play()
                    isPlaying = true

                    // Fallback: Start a timer to check if audio has finished
                    startFallbackTimer()

                } catch {
                    hasError = true
                }
            }
        }.resume()
    }

    private func stopAudio() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        stopFallbackTimer()
    }

    private func startFallbackTimer() {
        stopFallbackTimer()
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            if let player = self.audioPlayer, !player.isPlaying {
                DispatchQueue.main.async {
                    self.isPlaying = false
                    timer.invalidate()
                }
            }
        }
    }

    private func stopFallbackTimer() {
        // Timer will invalidate itself when audio finishes
    }
}

// Helper delegate class for audio player callbacks
private class AudioPlayerDelegate: NSObject, AVAudioPlayerDelegate {
    private let onFinished: () -> Void

    init(onFinished: @escaping () -> Void) {
        self.onFinished = onFinished
    }

    func audioPlayerDidFinishPlaying(_: AVAudioPlayer, successfully _: Bool) {
        onFinished()
    }

    func audioPlayerDecodeErrorDidOccur(_: AVAudioPlayer, error _: Error?) {
        onFinished()
    }
}

#Preview {
    VStack(spacing: 20) {
        HStack {
            AudioPlayerButton(audioUrl: "https://example.com/audio.mp3")
            Text("🔊 Speaker icon - normal state")
                .font(.system(size: 17))
        }

        HStack {
            AudioPlayerButton(audioUrl: "invalid-url")
            Text("🔇 Error state example")
                .font(.system(size: 17))
        }
    }
    .padding()
}
