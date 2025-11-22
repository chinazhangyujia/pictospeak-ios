//
//  CaptureView.swift
//  pictospeak-ios
//
//  Created by Yujia Zhang on 8/4/25.
//

import AVFoundation
import Photos
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

enum CaptureMode: String, CaseIterable {
    case photo = "Photo"
    case video = "Video"
}

struct CaptureView: View {
    @EnvironmentObject private var router: Router
    @StateObject private var cameraManager = CameraManager()
    @State private var selectedMode: CaptureMode = .photo
    @State private var showingImagePicker = false
    @State private var showingPhotoLibrary = false
    @State private var isRecording = false
    @State private var recordingTime: TimeInterval = 0
    @State private var timer: Timer?
    @State private var selectedVideo: URL?
    @State private var latestGalleryImage: UIImage?

    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()

            cameraViewSection

            // Floating Capture Button
            VStack {
                Spacer()

                if selectedMode == .video && isRecording {
                    Text(String(format: "%02d:%02d", Int(recordingTime) / 60, Int(recordingTime) % 60))
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.black.opacity(0.6))
                        )
                        .padding(.bottom, 12)
                        .transition(.opacity.combined(with: .scale))
                        .animation(.easeInOut(duration: 0.3), value: isRecording)
                }

                Button(action: {
                    if selectedMode == .photo {
                        cameraManager.capturePhoto()
                    } else {
                        if isRecording {
                            stopRecording()
                        } else {
                            startRecording()
                        }
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.gray.opacity(0.4))
                            .frame(width: 72, height: 72)
                            .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)

                        if selectedMode == .video {
                            if isRecording {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.red)
                                    .frame(width: 32, height: 32)
                            } else {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 60, height: 60)
                            }
                        } else {
                            Circle()
                                .fill(
                                    Color.white
                                )
                                .frame(width: 60, height: 60)
                        }
                    }
                }
                .padding(.bottom, 90)
            }
        }
        .onAppear(perform: {
            handleOnAppear()
            fetchLatestImageFromGallery()
        })
        .onChange(of: cameraManager.selectedImage) { _, newValue in
            handleImageChange(newValue)
        }
        .onChange(of: cameraManager.recordedVideoURL) { _, newValue in
            handleRecordedVideoChange(newValue)
        }
        .onChange(of: selectedVideo) { _, newValue in
            handleSelectedVideoChange(newValue)
        }
        .onChange(of: selectedMode) { _, newValue in
            switch newValue {
            case .photo:
                cameraManager.prepareForPhoto()
                cameraManager.selectedImage = nil
                selectedVideo = nil
            case .video:
                cameraManager.prepareForVideo()
                cameraManager.selectedImage = nil
                selectedVideo = nil
            }
        }
        .onDisappear(perform: handleOnDisappear)
        .sheet(isPresented: $showingPhotoLibrary) {
            PhotoPicker(selectedImage: $cameraManager.selectedImage, selectedVideo: $selectedVideo, latestGalleryImage: $latestGalleryImage, selectedMode: selectedMode)
        }
        .alert("Camera Access Required", isPresented: $cameraManager.showingPermissionAlert) {
            Button("Settings") {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please enable camera access in Settings to use this feature.")
        }
        .ignoresSafeArea()
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: {
                    router.resetToHome()
                }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.black)
                        .frame(width: 24, height: 24)
                        .clipShape(Circle())
                }
            }
            ToolbarItem(placement: .bottomBar) {
                if let latestImage = latestGalleryImage {
                    Image(uiImage: latestImage)
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                        .onTapGesture {
                            showingPhotoLibrary = true
                        }
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.4))
                        .frame(width: 24, height: 24)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(.white)
                                .font(.system(size: 18))
                        )
                        .onTapGesture {
                            showingPhotoLibrary = true
                        }
                }
            }
            ToolbarItem(placement: .status) {
                Picker("Capture Mode", selection: $selectedMode) {
                    ForEach(CaptureMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue.uppercased()).tag(mode)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .controlSize(.large)
                .frame(width: 200)
            }
            ToolbarItem(placement: .bottomBar) {
                Button(action: {}) {
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundColor(.white)
                                .font(.system(size: 22))
                        )
                }
            }
        }
    }

    // MARK: - Camera View Section

    private var cameraViewSection: some View {
        ZStack {
            if cameraManager.isCameraAuthorized {
                CameraPreviewView(session: cameraManager.session)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea(.all, edges: .horizontal)
                    .overlay(
                        // Recording indicator
                        VStack {
                            if selectedMode == .video && isRecording {
                                HStack {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 8, height: 8)
                                        .scaleEffect(isRecording ? 1.2 : 1.0)
                                        .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: isRecording)

                                    Text("REC")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.red)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.black.opacity(0.7))
                                .clipShape(Capsule())
                            }
                            Spacer()
                        }
                        .padding(.top, 16)
                        .padding(.leading, 16)
                    )
            } else {
                // Camera placeholder when not authorized
                VStack(spacing: 16) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)

                    Text("Access camera permission to use this feature")
                        .font(.body)
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.gray.opacity(0.1))
            }
        }
    }

    // MARK: - Recording Functions

    private func startRecording() {
        guard selectedMode == .video, !isRecording else { return }

        isRecording = true
        recordingTime = 0
        timer?.invalidate()
        cameraManager.startRecording()

        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            recordingTime += 0.1
            if recordingTime >= 5 { // Allow up to 30 seconds for video recording
                stopRecording()
            }
        }
    }

    private func stopRecording() {
        guard isRecording else { return }

        isRecording = false
        timer?.invalidate()
        timer = nil
        cameraManager.stopRecording()

        // Clear the recorded video URL after a short delay to allow navigation
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            cameraManager.recordedVideoURL = nil
            selectedVideo = nil
        }
    }
}

// MARK: - Camera Preview View

final class CameraPreviewUIView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context _: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.previewLayer.videoGravity = .resizeAspectFill
        view.previewLayer.session = session
        return view
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context _: Context) {
        if uiView.previewLayer.session !== session {
            uiView.previewLayer.session = session
        }
    }
}

// MARK: - Photo Picker

struct PhotoPicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Binding var selectedVideo: URL?
    @Binding var latestGalleryImage: UIImage?
    let selectedMode: CaptureMode
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = selectedMode == .photo ? .images : .videos
        config.selectionLimit = 1

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_: PHPickerViewController, context _: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoPicker

        init(_ parent: PhotoPicker) {
            self.parent = parent
        }

        func picker(_: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.dismiss()

            guard let provider = results.first?.itemProvider else { return }

            if parent.selectedMode == .photo {
                // Handle image selection
                if provider.canLoadObject(ofClass: UIImage.self) {
                    provider.loadObject(ofClass: UIImage.self) { image, _ in
                        DispatchQueue.main.async {
                            print("PhotoPicker: Setting selectedImage")
                            self.parent.selectedImage = image as? UIImage
                            self.parent.latestGalleryImage = image as? UIImage
                            print("PhotoPicker: Setting selectedImage to \(self.parent.selectedImage != nil)")
                        }
                    }
                }
            } else {
                // Handle video selection
                if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                    provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, error in
                        if let error = error {
                            print("Error loading video: \(error)")
                            return
                        }

                        guard let url = url else { return }

                        // Copy video to documents directory
                        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                        let videoName = "selected_video_\(Date().timeIntervalSince1970).mov"
                        let destinationURL = documentsPath.appendingPathComponent(videoName)

                        do {
                            try FileManager.default.copyItem(at: url, to: destinationURL)
                            DispatchQueue.main.async {
                                self.parent.selectedVideo = destinationURL
                                print("PhotoPicker: Video selected and saved to \(destinationURL)")
                            }
                        } catch {
                            print("Error copying video: \(error)")
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Camera Manager

class CameraManager: NSObject, ObservableObject {
    @Published var isCameraAuthorized = false
    @Published var showingPermissionAlert = false
    @Published var selectedImage: UIImage?
    @Published var recordedVideoURL: URL?

    let session = AVCaptureSession()
    private var videoOutput = AVCaptureMovieFileOutput()
    private var photoOutput = AVCapturePhotoOutput()
    private var videoDeviceInput: AVCaptureDeviceInput?

    private let sessionQueue = DispatchQueue(label: "com.pictospeak.camera.session")
    private var isSessionConfigured = false
    private var audioDeviceInput: AVCaptureDeviceInput?
    private var activeRecordingURL: URL?

    override init() {
        super.init()
    }

    func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isCameraAuthorized = true
            configureSessionIfNeeded()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.isCameraAuthorized = granted
                    if granted {
                        self?.configureSessionIfNeeded()
                    } else {
                        self?.showingPermissionAlert = true
                    }
                }
            }
        case .denied, .restricted:
            showingPermissionAlert = true
        @unknown default:
            break
        }
    }

    private func configureSessionIfNeeded() {
        sessionQueue.async { [weak self] in
            self?.configureSessionIfNeededOnSessionQueue()
        }
    }

    private func configureSessionIfNeededOnSessionQueue() {
        guard isCameraAuthorized else { return }
        if isSessionConfigured {
            return
        }

        session.beginConfiguration()
        session.automaticallyConfiguresApplicationAudioSession = true
        if session.canSetSessionPreset(.photo) {
            session.sessionPreset = .photo
        }

        // Add video input
        if videoDeviceInput == nil,
           let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
        {
            do {
                let videoInput = try AVCaptureDeviceInput(device: videoDevice)
                if session.canAddInput(videoInput) {
                    session.addInput(videoInput)
                    videoDeviceInput = videoInput
                }
            } catch {
                print("Error setting up video input: \(error)")
            }
        }

        // Add photo output by default
        if !session.outputs.contains(where: { $0 === photoOutput }),
           session.canAddOutput(photoOutput)
        {
            session.addOutput(photoOutput)
        }

        // Add video output
        if !session.outputs.contains(where: { $0 === videoOutput }),
           session.canAddOutput(videoOutput)
        {
            session.addOutput(videoOutput)
        }

        session.commitConfiguration()
        isSessionConfigured = true
    }

    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self = self, self.isCameraAuthorized else { return }
            self.configureSessionIfNeededOnSessionQueue()
            if !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    func prepareForPhoto() {
        sessionQueue.async { [weak self] in
            guard let self = self, self.isSessionConfigured else { return }
            self.configureSessionIfNeededOnSessionQueue()
            if let audioInput = self.audioDeviceInput, self.session.inputs.contains(audioInput) {
                self.session.removeInput(audioInput)
                self.audioDeviceInput = nil
            }
            self.session.beginConfiguration()
            if self.session.canSetSessionPreset(.photo) {
                self.session.sessionPreset = .photo
            }
            self.session.commitConfiguration()
        }
    }

    func prepareForVideo() {
        sessionQueue.async { [weak self] in
            guard let self = self, self.isSessionConfigured else { return }
            self.configureSessionIfNeededOnSessionQueue()

            self.session.beginConfiguration()
            if self.session.canSetSessionPreset(.high) {
                self.session.sessionPreset = .high
            }

            // Ensure no audio input is attached (we don't want to record sound)
            if let audioInput = self.audioDeviceInput, self.session.inputs.contains(audioInput) {
                self.session.removeInput(audioInput)
                self.audioDeviceInput = nil
            }

            self.session.commitConfiguration()
        }
    }

    func capturePhoto() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.configureSessionIfNeededOnSessionQueue()
            let settings = AVCapturePhotoSettings()
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    func startRecording() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.configureSessionIfNeededOnSessionQueue()
            guard self.session.outputs.contains(where: { $0 === self.videoOutput }) else {
                print("Video output not configured; cannot start recording.")
                return
            }
            guard !self.videoOutput.isRecording else { return }
            guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                print("Unable to access documents directory for recording.")
                return
            }

            let videoName = "video_\(Date().timeIntervalSince1970).mov"
            let videoURL = documentsPath.appendingPathComponent(videoName)
            self.activeRecordingURL = videoURL
            self.videoOutput.startRecording(to: videoURL, recordingDelegate: self)
        }
    }

    func stopRecording() {
        sessionQueue.async { [weak self] in
            guard let self = self, self.videoOutput.isRecording else { return }
            self.videoOutput.stopRecording()
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(_: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error _: Error?) {
        if let imageData = photo.fileDataRepresentation(),
           let image = UIImage(data: imageData)
        {
            DispatchQueue.main.async {
                self.selectedImage = image
            }
        }
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate

extension CameraManager: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from _: [AVCaptureConnection], error: Error?) {
        if let error = error {
            print("Video recording error: \(error.localizedDescription)")
        } else {
            DispatchQueue.main.async {
                self.recordedVideoURL = outputFileURL
                print("Video saved to: \(outputFileURL)")
            }
        }
        sessionQueue.async { [weak self] in
            self?.activeRecordingURL = nil
        }
    }
}

// MARK: - Event Handlers

extension CaptureView {
    private func handleOnAppear() {
        cameraManager.checkPermissions()
        cameraManager.startSession()
        // Reset recording state
        isRecording = false
        recordingTime = 0
        timer?.invalidate()
        timer = nil
    }

    private func handleImageChange(_ newValue: UIImage?) {
        if let image = newValue {
            cameraManager.stopSession()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                router.goTo(.speakFromImage(selectedImage: image))
            }
            // Clear the selected image after navigation
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                cameraManager.selectedImage = nil
            }
        }
    }

    private func handleRecordedVideoChange(_ newValue: URL?) {
        if let videoURL = newValue {
            cameraManager.stopSession()
            Task {
                let frames = await generateFrames(from: videoURL)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    router.goTo(.speakFromVideo(selectedVideo: videoURL, frames: frames))
                }
            }
            // Clear the recorded video after navigation
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                cameraManager.recordedVideoURL = nil
            }
        }
    }

    private func handleSelectedVideoChange(_ newValue: URL?) {
        if let videoURL = newValue {
            cameraManager.stopSession()
            Task {
                let frames = await generateFrames(from: videoURL)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    router.goTo(.speakFromVideo(selectedVideo: videoURL, frames: frames))
                }
            }
            // Clear the selected video after navigation
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                selectedVideo = nil
            }
        }
    }

    private func generateFrames(from videoURL: URL, count: Int = 5) async -> [Data] {
        let asset = AVAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero

        var frames: [Data] = []

        do {
            let duration = try await asset.load(.duration)
            let durationSeconds = CMTimeGetSeconds(duration)

            // Calculate evenly distributed timestamps (taking the middle of each segment)
            let interval = durationSeconds / Double(count)

            for i in 0 ..< count {
                let timeSeconds = Double(i) * interval + (interval / 2)
                let time = CMTime(seconds: timeSeconds, preferredTimescale: 600)

                // Use the async image generation API if available (iOS 16+), or wrapper for older
                if #available(iOS 16.0, *) {
                    let (image, _) = try await generator.image(at: time)
                    if let data = UIImage(cgImage: image).jpegData(compressionQuality: 0.7) {
                        frames.append(data)
                    }
                } else {
                    // Fallback for older iOS versions
                    let image = try generator.copyCGImage(at: time, actualTime: nil)
                    if let data = UIImage(cgImage: image).jpegData(compressionQuality: 0.7) {
                        frames.append(data)
                    }
                }
            }
        } catch {
            print("Error generating frames: \(error)")
        }

        return frames
    }

    private func handleOnDisappear() {
        timer?.invalidate()
        cameraManager.stopSession()
    }

    private func fetchLatestImageFromGallery() {
        // Check if we already have a latest image
        guard latestGalleryImage == nil else { return }

        // Request photo library access
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized else { return }

            // Fetch the most recent image
            let fetchOptions = PHFetchOptions()
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            fetchOptions.fetchLimit = 1

            let fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)

            guard let asset = fetchResult.firstObject else { return }

            let imageManager = PHImageManager.default()
            let requestOptions = PHImageRequestOptions()
            requestOptions.isSynchronous = false
            requestOptions.deliveryMode = .highQualityFormat

            imageManager.requestImage(for: asset, targetSize: CGSize(width: 200, height: 200), contentMode: .aspectFill, options: requestOptions) { image, _ in
                DispatchQueue.main.async {
                    self.latestGalleryImage = image
                }
            }
        }
    }
}

#Preview {
    CaptureView()
}
