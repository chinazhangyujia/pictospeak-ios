//
//  BackgroundVideoPlayer.swift
//  pictospeak-ios
//
//  Created by Yujia Zhang on 8/4/25.
//

import AVKit
import SwiftUI
import UIKit

// MARK: - Video Player Helpers

struct BackgroundVideoPlayer: UIViewRepresentable {
    var player: AVPlayer
    var onReadyForDisplay: (() -> Void)?

    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        view.player = player
        view.playerLayer.videoGravity = .resizeAspectFill

        // Add observer for readyForDisplay
        view.playerLayer.addObserver(context.coordinator, forKeyPath: "readyForDisplay", options: [.new], context: nil)

        return view
    }

    func updateUIView(_ uiView: PlayerView, context: Context) {
        if uiView.player != player {
            // Reset ready state tracking if player changes
            uiView.playerLayer.removeObserver(context.coordinator, forKeyPath: "readyForDisplay")
            uiView.player = player
            uiView.playerLayer.addObserver(context.coordinator, forKeyPath: "readyForDisplay", options: [.new], context: nil)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onReadyForDisplay: onReadyForDisplay)
    }

    class Coordinator: NSObject {
        var onReadyForDisplay: (() -> Void)?

        init(onReadyForDisplay: (() -> Void)?) {
            self.onReadyForDisplay = onReadyForDisplay
        }

        override func observeValue(forKeyPath keyPath: String?, of object: Any?, change _: [NSKeyValueChangeKey: Any]?, context _: UnsafeMutableRawPointer?) {
            if keyPath == "readyForDisplay" {
                if let layer = object as? AVPlayerLayer, layer.isReadyForDisplay {
                    DispatchQueue.main.async {
                        self.onReadyForDisplay?()
                    }
                }
            }
        }
    }

    static func dismantleUIView(_ uiView: PlayerView, coordinator: Coordinator) {
        uiView.playerLayer.removeObserver(coordinator, forKeyPath: "readyForDisplay")
    }
}

class PlayerView: UIView {
    override class var layerClass: AnyClass {
        return AVPlayerLayer.self
    }

    var playerLayer: AVPlayerLayer {
        return layer as! AVPlayerLayer
    }

    var player: AVPlayer? {
        get { return playerLayer.player }
        set { playerLayer.player = newValue }
    }
}
