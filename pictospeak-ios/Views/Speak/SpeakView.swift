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
                        .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
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
                        .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
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
                        .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                        .ignoresSafeArea()
                }

                VStack {
                    topSection
                    Spacer()
                    bottomSection
                }.frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .navigationBarHidden(true)
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
                // Stop recording
                recordingTimer?.invalidate()
                recordingTimer = nil
                recordingTime = 0

                // Get recorded audio data and navigate to feedback
                if let url = recordingURL {
                    do {
                        recordedAudioData = try Data(contentsOf: url)
                        if let currentImage = currentImage {
                            router.goTo(.feedbackFromSpeak(selectedImage: currentImage, selectedVideo: nil, audioData: recordedAudioData ?? Data(), mediaType: .image))
                        } else if let currentVideo = currentVideo {
                            router.goTo(.feedbackFromSpeak(selectedImage: nil, selectedVideo: currentVideo, audioData: recordedAudioData ?? Data(), mediaType: .video))
                        }
                    } catch {
                        print("Failed to read audio data: \(error)")
                    }
                }
            }
        }
    }

    // MARK: - Top Section

    private var topSection: some View {
        HStack {
            Button(action: {
                router.resetToHome()
            }) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.gray.opacity(0.3))
                    .clipShape(Circle())
            }

            Spacer()

            Text("Speak")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)

            Spacer()

            Color.clear
                .frame(width: 40, height: 40)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }

    // MARK: - Bottom Section

    private var bottomSection: some View {
        VStack(spacing: 20) {
            // Voice Input Overlay
            VStack(spacing: 16) {
                // Microphone Button
                Button(action: {
                    // This will be handled by the gesture
                }) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: isRecording ? [.red, .orange] : [.purple, .blue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)
                            .scaleEffect(isRecording ? 1.1 : 1.0)
                            .animation(.easeInOut(duration: 0.2), value: isRecording)

                        Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white)
                            .scaleEffect(isRecording ? 1.2 : 1.0)
                            .animation(isRecording ? .easeInOut(duration: 0.5).repeatForever(autoreverses: true) : .default, value: isRecording)
                    }
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            if !isRecording {
                                startRecording()
                            }
                        }
                        .onEnded { _ in
                            stopRecording()
                        }
                )

                Text(isRecording ? "Recording... \(String(format: "%.1f", 10 - recordingTime))s" : "Hold to record (max 10s)")
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
            }
            .padding(.vertical, 32)
            .padding(.horizontal, 40)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
            )
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 50)
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
        audioRecorder?.record()
        isRecording = true
        recordingTime = 0

        // Start timer to track recording time
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            recordingTime += 0.1
            if recordingTime >= 10.0 {
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
        guard let model = materialsModel else { return }

        let verticalThreshold: CGFloat = 50
        let horizontalThreshold: CGFloat = 100

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
