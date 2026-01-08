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

    // States for Single Item Mode (when materialsModel is nil)
    @State private var currentImage: UIImage?
    @State private var currentVideo: URL?
    @State private var videoPlayer: AVPlayer?
    @State private var playerObserver: NSObjectProtocol?
    @State private var isLoading = false

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
                if let materialsModel = materialsModel {
                    SwipeableMaterialsView(
                        viewModel: materialsModel,
                        size: geometry.size
                    )
                } else {
                    // Single Item Mode
                    if let currentImage = currentImage {
                        Image(uiImage: currentImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()
                            .ignoresSafeArea()
                    } else if let videoPlayer = videoPlayer {
                        BackgroundVideoPlayer(player: videoPlayer) {
                            isLoading = false
                        }
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                        .ignoresSafeArea()
                        .onAppear {
                            videoPlayer.play()
                            setupVideoLooping()
                        }
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .ignoresSafeArea()
                    }

                    if isLoading {
                        ZStack {
                            Color.black.opacity(0.2)
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.5)
                        }
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .ignoresSafeArea()
                    }
                }

                // Recording UI Overlay
                VStack {
                    Spacer()

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
        }
        .onDisappear {
            stopRecording()
            videoPlayer?.pause()
            if let observer = playerObserver {
                NotificationCenter.default.removeObserver(observer)
                playerObserver = nil
            }
        }
        .onChange(of: isRecording) { _, newValue in
            if !newValue {
                handleRecordingFinished()
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

    private func handleRecordingFinished() {
        // Capture duration before reset
        let finalDuration = recordingTime

        // Stop recording just in case
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

                // Determine what media to pass
                if let model = materialsModel, let material = model.currentMaterial {
                    // List Mode
                    // We need to fetch the image or video from cache to pass it to Feedback
                    // Or rely on the material properties

                    var image: UIImage? = nil
                    var video: URL? = nil
                    let mediaType: MediaType = material.type

                    if material.type == .image {
                        image = model.imageCache[material.id]
                    } else if material.type == .video {
                        // For video, we pass the URL. The cache has the AVPlayer, but FeedbackView expects URL.
                        video = URL(string: material.materialUrl)
                    }

                    router.goTo(.feedbackFromSpeak(selectedImage: image, selectedVideo: video, audioData: audioDataToSend, mediaType: mediaType, materialId: material.id))

                } else {
                    // Single Mode
                    if let currentImage = currentImage {
                        router.goTo(.feedbackFromSpeak(selectedImage: currentImage, selectedVideo: nil, audioData: audioDataToSend, mediaType: .image, materialId: nil))
                    } else if let currentVideo = currentVideo {
                        router.goTo(.feedbackFromSpeak(selectedImage: nil, selectedVideo: currentVideo, audioData: audioDataToSend, mediaType: .video, materialId: nil))
                    }
                }
            } catch {
                print("Failed to read audio data: \(error)")
            }
        }
    }

    private func setupVideoLooping() {
        guard let videoPlayer = videoPlayer else { return }

        if let observer = playerObserver {
            NotificationCenter.default.removeObserver(observer)
            playerObserver = nil
        }

        playerObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: videoPlayer.currentItem,
            queue: .main
        ) { _ in
            videoPlayer.seek(to: .zero)
            videoPlayer.play()
        }
    }
}

// MARK: - Swipeable Materials Components

struct SwipeableMaterialsView: View {
    @ObservedObject var viewModel: InternalUploadedMaterialsViewModel
    let size: CGSize

    @State private var dragOffset: CGFloat = 0
    @State private var isDragging: Bool = false

    var body: some View {
        ZStack {
            // Background color
            Color.black.ignoresSafeArea()

            // Calculate indices to show: [current-1, current, current+1]
            // We use ForEach with material ID to preserve view identity across index changes
            let indices = getVisibleIndices()

            ForEach(indices, id: \.self) { index in
                if let material = getMaterial(at: index) {
                    let relativePos = index - viewModel.currentIndex

                    SingleMaterialView(
                        material: material,
                        viewModel: viewModel,
                        isActive: index == viewModel.currentIndex,
                        shouldPlay: index == viewModel.currentIndex || (index == viewModel.currentIndex && isDragging)
                    )
                    .frame(width: size.width, height: size.height)
                    .offset(y: calculateOffset(relativePos: relativePos) + (relativePos == 0 ? dragOffset : 0))
                    // Opacity logic:
                    // If relativePos is 0 (current): fades out as you drag away
                    // If relativePos is -1 (prev) or 1 (next): fades in as you drag it in
                    .opacity(calculateOpacity(relativePos: relativePos))
                    .zIndex(relativePos == 0 ? 2 : 1) // Current on top
                }
            }
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    isDragging = true
                    dragOffset = value.translation.height
                }
                .onEnded { value in
                    let threshold = size.height / 2
                    let translation = value.translation.height

                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        if translation < -threshold {
                            // Swiped Up -> Next
                            if getNextIndex() != nil {
                                dragOffset = -size.height
                                completeTransition(direction: 1)
                            } else {
                                dragOffset = 0
                            }
                        } else if translation > threshold {
                            // Swiped Down -> Prev
                            if getPreviousIndex() != nil {
                                dragOffset = size.height
                                completeTransition(direction: -1)
                            } else {
                                dragOffset = 0
                            }
                        } else {
                            // Reset
                            dragOffset = 0
                        }
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        isDragging = false
                    }
                }
        )
    }

    private func getVisibleIndices() -> [Int] {
        let current = viewModel.currentIndex
        return [current - 1, current, current + 1].filter { $0 >= 0 && $0 < viewModel.materials.count }
    }

    private func getMaterial(at index: Int) -> Material? {
        guard index >= 0, index < viewModel.materials.count else { return nil }
        return viewModel.materials[index]
    }

    private func getPreviousIndex() -> Int? {
        let prev = viewModel.currentIndex - 1
        return prev >= 0 ? prev : nil
    }

    private func getNextIndex() -> Int? {
        let next = viewModel.currentIndex + 1
        return next < viewModel.materials.count ? next : nil
    }

    private func calculateOffset(relativePos: Int) -> CGFloat {
        // If it's current (0), offset is handled by dragOffset
        if relativePos == 0 { return 0 }

        // If it's prev (-1), it sits above (-height).
        // If it's next (1), it sits below (height).
        // Plus the dragOffset to bring it into view.
        return CGFloat(relativePos) * size.height + dragOffset
    }

    private func calculateOpacity(relativePos: Int) -> Double {
        if relativePos == 0 {
            // Current item: Fade out based on drag distance
            return 1.0 - Double(abs(dragOffset) / size.height)
        } else {
            // Adjacent items: Fade in based on drag distance
            // Only fade in if we are dragging in that direction
            if (relativePos == -1 && dragOffset > 0) || (relativePos == 1 && dragOffset < 0) {
                return Double(abs(dragOffset) / size.height) + 0.5
            }
            return 0
        }
    }

    private func completeTransition(direction: Int) {
        // Wait for animation to finish then update index
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let newIndex = viewModel.currentIndex + direction
            viewModel.setCurrentIndex(newIndex)
            dragOffset = 0
        }
    }
}

struct SingleMaterialView: View {
    let material: Material
    @ObservedObject var viewModel: InternalUploadedMaterialsViewModel
    let isActive: Bool
    let shouldPlay: Bool

    @State private var isLoading = false
    @State private var playerObserver: NSObjectProtocol?

    var body: some View {
        ZStack {
            Color.black // Background

            if material.type == .image {
                if let image = viewModel.imageCache[material.id] {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .ignoresSafeArea()
                } else {
                    ProgressView()
                        .onAppear {
                            loadContent()
                        }
                }
            } else if material.type == .video {
                if let player = viewModel.videoPlayerCache[material.id] {
                    // Video Player
                    BackgroundVideoPlayer(player: player) {
                        // Ready
                    }
                    .ignoresSafeArea()
                    .onAppear {
                        if isActive {
                            stopOtherVideos(currentId: material.id)
                            player.isMuted = true // Always mute in SpeakView

                            // Only seek to zero if we are not resuming from a paused state during drag
                            // If we just became active, and we weren't dragging, or we are at end...
                            // Actually, safer to seek to zero if not playing
                            if player.timeControlStatus != .playing {
                                player.seek(to: .zero)
                            }

                            if shouldPlay {
                                player.play()
                            }
                        } else {
                            player.pause()
                            player.isMuted = true
                        }
                        setupLooping(for: player)
                    }
                    .onDisappear {
                        // Pause player when view disappears to prevent background audio
                        player.pause()
                        removeObserver()
                    }
                    .onChange(of: isActive) { _, active in
                        if active {
                            stopOtherVideos(currentId: material.id)
                            player.isMuted = true

                            // Ensure we start from beginning if becoming active
                            player.seek(to: .zero)

                            if shouldPlay { player.play() }
                        } else {
                            player.pause()
                        }
                    }
                    .onChange(of: shouldPlay) { _, play in
                        if isActive {
                            if play { player.play() }
                            else { player.pause() }
                        }
                    }
                } else {
                    // Show thumbnail if available, otherwise loader
                    if let thumbUrl = material.thumbnailUrl, let url = URL(string: thumbUrl) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case let .success(image):
                                image.resizable().scaledToFill()
                            default:
                                ProgressView()
                            }
                        }
                        .ignoresSafeArea()
                    } else {
                        ProgressView()
                    }

                    // Trigger load
                    Color.clear.onAppear {
                        loadContent()
                    }
                }
            }
        }
    }

    private func loadContent() {
        // Trigger cache load via logic similar to preload
        // We can manually add to cache here if not present
        guard let url = URL(string: material.materialUrl) else { return }

        if material.type == .image {
            if viewModel.imageCache[material.id] == nil {
                URLSession.shared.dataTask(with: url) { data, _, _ in
                    if let data = data, let image = UIImage(data: data) {
                        DispatchQueue.main.async {
                            viewModel.imageCache[material.id] = image
                        }
                    }
                }.resume()
            }
        } else if material.type == .video {
            if viewModel.videoPlayerCache[material.id] == nil {
                let player = AVPlayer(url: url)
                player.actionAtItemEnd = .none
                DispatchQueue.main.async {
                    viewModel.videoPlayerCache[material.id] = player
                }
            }
        }
    }

    private func setupLooping(for player: AVPlayer) {
        removeObserver()

        playerObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in
            player.seek(to: .zero)
            player.play()
        }
    }

    private func removeObserver() {
        if let observer = playerObserver {
            NotificationCenter.default.removeObserver(observer)
            playerObserver = nil
        }
    }

    private func stopOtherVideos(currentId: UUID) {
        for (id, player) in viewModel.videoPlayerCache {
            if id != currentId {
                player.pause()
            }
        }
    }
}
