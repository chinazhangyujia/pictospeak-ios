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

                        if selectedMode == .video && isRecording {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 60, height: 60)
                        } else if selectedMode == .video {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 60, height: 60)
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
                Button(action: {
                    showingPhotoLibrary = true
                }) {
                    if let latestImage = latestGalleryImage {
                        Image(uiImage: latestImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 1)
                            )
                    } else {
                        Circle()
                            .fill(Color.gray.opacity(0.4))
                            .frame(width: 24, height: 24)
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(.white)
                                    .font(.system(size: 18))
                            )
                    }
                }
            }
            ToolbarItem(placement: .status) {
                HStack(spacing: -20) {
                    Button(action: {
                        selectedMode = .photo
                        cameraManager.prepareForPhoto()
                        // Clear any selected media when switching modes
                        cameraManager.selectedImage = nil
                        selectedVideo = nil
                    }) {
                        Text("PHOTO")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(selectedMode == .photo ? Color(red: 0.247, green: 0.388, blue: 0.910) : .black)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 8)
                            .background(selectedMode == .photo ? Color(red: 0.929, green: 0.929, blue: 0.929) : Color.clear)
                            .clipShape(Capsule())
                            .frame(width: 90, height: 36)
                    }

                    Button(action: {
                        selectedMode = .video
                        cameraManager.prepareForVideo()
                        // Clear any selected media when switching modes
                        cameraManager.selectedImage = nil
                        selectedVideo = nil
                    }) {
                        Text("VIDEO")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(selectedMode == .video ? Color(red: 0.247, green: 0.388, blue: 0.910) : .black)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 8)
                            .background(selectedMode == .video ? Color(red: 0.929, green: 0.929, blue: 0.929) : Color.clear)
                            .clipShape(Capsule())
                            .frame(width: 90, height: 36)
                    }
                }
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
        isRecording = true
        recordingTime = 0
        cameraManager.startRecording()

        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            recordingTime += 0.1
            if recordingTime >= 5 { // Allow up to 30 seconds for video recording
                stopRecording()
            }
        }
    }

    private func stopRecording() {
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

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context _: Context) -> UIView {
        let view = UIView()
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
        return view
    }

    func updateUIView(_ uiView: UIView, context _: Context) {
        if let previewLayer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            previewLayer.frame = uiView.bounds
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

    override init() {
        super.init()
        setupSession()
    }

    func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isCameraAuthorized = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.isCameraAuthorized = granted
                }
            }
        case .denied, .restricted:
            showingPermissionAlert = true
        @unknown default:
            break
        }
    }

    private func setupSession() {
        session.beginConfiguration()

        // Add video input
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else { return }

        do {
            let videoInput = try AVCaptureDeviceInput(device: videoDevice)
            if session.canAddInput(videoInput) {
                session.addInput(videoInput)
                videoDeviceInput = videoInput
            }
        } catch {
            print("Error setting up video input: \(error)")
        }

        // Add photo output
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }

        // Add video output
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }

        session.commitConfiguration()

        // Start session after configuration is complete
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }

    func startSession() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }

    func prepareForPhoto() {
        session.beginConfiguration()
        session.removeOutput(videoOutput)
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }
        session.commitConfiguration()
    }

    func prepareForVideo() {
        session.beginConfiguration()
        session.removeOutput(photoOutput)
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }
        session.commitConfiguration()
    }

    func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    func startRecording() {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let videoName = "video_\(Date().timeIntervalSince1970).mov"
        let videoURL = documentsPath.appendingPathComponent(videoName)
        recordedVideoURL = videoURL
        videoOutput.startRecording(to: videoURL, recordingDelegate: self)
    }

    func stopRecording() {
        videoOutput.stopRecording()
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
        if error == nil {
            // Handle successful video recording
            DispatchQueue.main.async {
                self.recordedVideoURL = outputFileURL
                print("Video saved to: \(outputFileURL)")
            }
        } else {
            print("Video recording error: \(error?.localizedDescription ?? "Unknown error")")
        }
    }
}

// MARK: - Event Handlers

extension CaptureView {
    private func handleOnAppear() {
        cameraManager.checkPermissions()
        // Reset recording state
        isRecording = false
        recordingTime = 0
        timer?.invalidate()
        timer = nil
    }

    private func handleImageChange(_ newValue: UIImage?) {
        if let image = newValue {
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                router.goTo(.speakFromVideo(selectedVideo: videoURL))
            }
            // Clear the recorded video after navigation
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                cameraManager.recordedVideoURL = nil
            }
        }
    }

    private func handleSelectedVideoChange(_ newValue: URL?) {
        if let videoURL = newValue {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                router.goTo(.speakFromVideo(selectedVideo: videoURL))
            }
            // Clear the selected video after navigation
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                selectedVideo = nil
            }
        }
    }

    private func handleOnDisappear() {
        timer?.invalidate()
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
