//
//  SpeakView.swift
//  pictospeak-ios
//
//  Created by Yujia Zhang on 8/4/25.
//

import AVFoundation
import AVKit
import SwiftUI

struct SpeakView: View {
    @EnvironmentObject private var router: Router
    let selectedImage: UIImage?
    let selectedVideo: URL?
    let materialsModel: InternalUploadedMaterialsViewModel?

    private let maxRecordingDuration: TimeInterval = 45.0

    @State private var isRecording = false
    @State private var audioRecorder: AVAudioRecorder?
    @State private var recordingURL: URL?
    @State private var recordingTimer: Timer?
    @State private var recordingTime: TimeInterval = 0
    @State private var showFeedbackView = false
    @State private var recordedAudioData: Data?
    @State private var currentImage: UIImage?
    @State private var currentVideo: URL?
    @State private var videoPlayer: AVPlayer?

    init(selectedImage: UIImage) {
        self.selectedImage = selectedImage
        print("SpeakView: init: selectedImage: \(selectedImage)")
        selectedVideo = nil
        materialsModel = nil
        _currentImage = State(initialValue: selectedImage)
        _currentVideo = State(initialValue: nil)
        _videoPlayer = State(initialValue: nil)
    }

    init(selectedVideo: URL) {
        selectedImage = nil
        self.selectedVideo = selectedVideo
        materialsModel = nil
        _currentImage = State(initialValue: nil)
        _currentVideo = State(initialValue: selectedVideo)
        let player = AVPlayer(url: selectedVideo)
        player.actionAtItemEnd = .none
        _videoPlayer = State(initialValue: player)
    }

    init(materialsModel: InternalUploadedMaterialsViewModel) {
        selectedImage = nil
        selectedVideo = nil
        self.materialsModel = materialsModel
        _currentImage = State(initialValue: nil)
        _currentVideo = State(initialValue: nil)
        _videoPlayer = State(initialValue: nil)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                // Background Media
                if let currentImage = currentImage {
                    // Show image as background
                    Image(uiImage: currentImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                        .ignoresSafeArea()
                        .gesture(
                            // Only enable gestures if we have a materialsModel
                            materialsModel != nil ?
                                DragGesture()
                                .onEnded { value in
                                    handleSwipeGesture(value)
                                } : nil
                        )
                } else if let videoPlayer = videoPlayer {
                    // Show video player as background
                    VideoPlayer(player: videoPlayer)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                        .ignoresSafeArea()
                        .onAppear {
                            videoPlayer.play()
                            setupVideoLooping()
                        }
                        .gesture(
                            // Only enable gestures if we have a materialsModel
                            materialsModel != nil ?
                                DragGesture()
                                .onEnded { value in
                                    handleSwipeGesture(value)
                                } : nil
                        )
                } else {
                    // Placeholder while loading
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .ignoresSafeArea()
                }

                VStack {
                    Spacer()

                    // Timer display (only shown when recording)
                    if isRecording {
                        Text(String(format: "%02d:%02d", Int(recordingTime) / 60, Int(recordingTime) % 60))
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.black.opacity(0.6))
                            )
                            .padding(.bottom, 16)
                            .transition(.opacity.combined(with: .scale))
                            .animation(.easeInOut(duration: 0.3), value: isRecording)
                    }

                    Button(action: {
                        if isRecording {
                            stopRecording()
                        } else {
                            startRecording()
                        }
                    }) {
                        ZStack {
                            if isRecording {
                                Circle()
                                    .fill(Color.gray.opacity(0.4))
                                    .frame(width: 72, height: 72)
                                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)

                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.red)
                                    .frame(width: 32, height: 32)

                            } else {
                                Circle()
                                    .fill(Color.gray.opacity(0.4))
                                    .frame(width: 72, height: 72)
                                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)

                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 60, height: 60)

                                Image(systemName: "mic")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.bottom, 90)
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .onAppear {
            setupAudioRecorder()

            // Load material if we have a materials model
            if let model = materialsModel, let material = model.currentMaterial {
                loadMaterial(material)
            }
        }
        .onDisappear {
            stopRecording()
            // Stop video playback when leaving the view
            videoPlayer?.pause()
        }
        .onChange(of: isRecording) { _, newValue in
            if !newValue {
                // Capture duration before reset
                let finalDuration = recordingTime

                // Stop recording
                recordingTimer?.invalidate()
                recordingTimer = nil
                recordingTime = 0

                // Get recorded audio data and navigate to feedback
                if let url = recordingURL {
                    do {
                        let audioDataToSend: Data?

                        if finalDuration < 2.0 {
                            print("Recording too short (< 2s), sending without audio")
                            audioDataToSend = nil
                        } else {
                            audioDataToSend = try Data(contentsOf: url)
                        }

                        recordedAudioData = audioDataToSend

                        if let currentImage = currentImage {
                            router.goTo(.feedbackFromSpeak(selectedImage: currentImage, selectedVideo: nil, audioData: audioDataToSend, mediaType: .image))
                        } else if let currentVideo = currentVideo {
                            router.goTo(.feedbackFromSpeak(selectedImage: nil, selectedVideo: currentVideo, audioData: audioDataToSend, mediaType: .video))
                        }
                    } catch {
                        print("Failed to read audio data: \(error)")
                    }
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .ignoresSafeArea()
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: {
                    router.goBack()
                }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.black)
                        .frame(width: 24, height: 24)
                        .clipShape(Circle())
                        .blendMode(.multiply)
                }
            }
        }
    }

    // MARK: - Audio Recording Functions

    private func setupAudioRecorder() {
        let audioSession = AVAudioSession.sharedInstance()

        do {
            try audioSession.setCategory(.playAndRecord, mode: .default)
            try audioSession.setActive(true)

            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let audioFilename = documentsPath.appendingPathComponent("recording.m4a")
            recordingURL = audioFilename

            // Use default settings for simplest recording
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: [:])
            audioRecorder?.prepareToRecord()

        } catch {
            print("Could not set up audio recorder: \(error)")
        }
    }

    private func startRecording() {
        guard audioRecorder?.isRecording != true else { return }

        audioRecorder?.record()
        isRecording = true
        recordingTime = 0

        // Start timer to track recording time
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            recordingTime += 0.1
            if recordingTime >= maxRecordingDuration {
                stopRecording()
            }
        }
    }

    private func stopRecording() {
        audioRecorder?.stop()
        isRecording = false
        recordingTimer?.invalidate()
        recordingTimer = nil
    }

    // MARK: - Swipe Gesture Functions

    private func handleSwipeGesture(_ value: DragGesture.Value) {
        guard materialsModel != nil else { return }

        let verticalThreshold: CGFloat = 50

        // Determine swipe direction
        if abs(value.translation.height) > abs(value.translation.width) {
            // Vertical swipe
            if value.translation.height > verticalThreshold {
                // Swipe down - go to next material
                handleSwipeDown()
            } else if value.translation.height < -verticalThreshold {
                // Swipe up - go to previous material
                handleSwipeUp()
            }
        }
    }

    private func handleSwipeUp() {
        guard let model = materialsModel else { return }

        // Check if we can go to next material
        if model.currentIndex < model.materials.count - 1 || model.hasMoreMaterials {
            let newIndex = model.currentIndex + 1
            model.setCurrentIndex(newIndex)
            loadMaterial(model.currentMaterial!)
        }
    }

    private func handleSwipeDown() {
        guard let model = materialsModel else { return }

        // Check if we can go to previous material (index > 0)
        if model.currentIndex > 0 {
            let newIndex = model.currentIndex - 1
            model.setCurrentIndex(newIndex)
            loadMaterial(model.currentMaterial!)
        }
    }

    private func loadMaterial(_ material: Material) {
        guard let url = URL(string: material.materialUrl) else {
            return
        }

        // Use URLSession for asynchronous loading
        URLSession.shared.dataTask(with: url) { data, _, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Error downloading data from URL: \(error)")
                    return
                }

                guard let data = data else {
                    print("No data received from URL")
                    return
                }

                if material.type == .image {
                    if let image = UIImage(data: data) {
                        // Stop any existing video
                        videoPlayer?.pause()
                        currentImage = image
                        currentVideo = nil
                        videoPlayer = nil
                    }
                } else if material.type == .video {
                    // For video, save to temp file and create player
                    let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    let videoName = "temp_video_\(Date().timeIntervalSince1970).mov"
                    let videoURL = documentsPath.appendingPathComponent(videoName)

                    do {
                        try data.write(to: videoURL)
                        // Stop any existing video
                        videoPlayer?.pause()
                        currentImage = nil
                        currentVideo = videoURL
                        let player = AVPlayer(url: videoURL)
                        player.actionAtItemEnd = .none
                        videoPlayer = player
                    } catch {
                        print("Error saving video data: \(error)")
                    }
                }
            }
        }.resume()
    }

    private func setupVideoLooping() {
        guard let videoPlayer = videoPlayer else { return }

        // Remove any existing observers first
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)

        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: videoPlayer.currentItem,
            queue: .main
        ) { _ in
            videoPlayer.seek(to: .zero)
            videoPlayer.play()
        }
    }
}

#Preview {
    // Create a sample image for preview
    let sampleImage = UIImage(systemName: "photo") ?? UIImage()
    SpeakView(selectedImage: sampleImage)
}
