//
//  CaptureView.swift
//  pictospeak-ios
//
//  Created by Yujia Zhang on 8/4/25.
//

import AVFoundation
import PhotosUI
import SwiftUI

struct CaptureView: View {
    @EnvironmentObject private var router: Router
    @StateObject private var cameraManager = CameraManager()
    @State private var selectedMode: CaptureMode = .photo
    @State private var showingImagePicker = false
    @State private var showingPhotoLibrary = false
    @State private var isRecording = false
    @State private var recordingTime: TimeInterval = 0
    @State private var timer: Timer?

    enum CaptureMode: String, CaseIterable {
        case photo = "Photo"
        case video = "Video"
    }

    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top Section with Title and Back Button
                topSection

                // Camera View Area
                cameraViewSection

                Spacer()

                // Bottom Control Bar
                bottomControlBar
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            cameraManager.checkPermissions()
        }
        .onChange(of: cameraManager.selectedImage) { _, newValue in
            if newValue != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    router.goTo(.speak(selectedImage: cameraManager.selectedImage ?? UIImage(), mediaType: selectedMode == .photo ? .image : .video))
                }
            }
        }
        .onDisappear {
            timer?.invalidate()
        }
        .sheet(isPresented: $showingPhotoLibrary) {
            PhotoPicker(selectedImage: $cameraManager.selectedImage)
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

            Text("Capture")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)

            Spacer()

            // Invisible placeholder to balance the layout
            Color.clear
                .frame(width: 40, height: 40)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }

    // MARK: - Camera View Section

    private var cameraViewSection: some View {
        VStack {
            if cameraManager.isCameraAuthorized {
                CameraPreviewView(session: cameraManager.session)
                    .frame(maxWidth: .infinity)
                    .aspectRatio(4 / 3, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
            } else {
                // Camera placeholder when not authorized
                VStack(spacing: 16) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)

                    Text("Camera view would appear here")
                        .font(.body)
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .frame(height: UIScreen.main.bounds.width * 0.7) // 4:3 ratio accounting for padding
                .background(Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
        }
    }

    // MARK: - Bottom Control Bar

    private var bottomControlBar: some View {
        VStack(spacing: 20) {
            // Mode Selector
            HStack(spacing: 0) {
                ForEach(CaptureMode.allCases, id: \.self) { mode in
                    Button(action: {
                        selectedMode = mode
                        if mode == .video {
                            cameraManager.prepareForVideo()
                        } else {
                            cameraManager.prepareForPhoto()
                        }
                    }) {
                        Text(mode.rawValue)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(selectedMode == mode ? .white : .gray)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                selectedMode == mode ?
                                    Color.gray.opacity(0.3) : Color.clear
                            )
                    }
                }
            }
            .background(Color.gray.opacity(0.2))
            .clipShape(Capsule())
            .padding(.horizontal, 40)

            // Capture Controls
            HStack {
                // Gallery Button
                Button(action: {
                    showingPhotoLibrary = true
                }) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(Color.gray.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                Spacer()

                // Capture Button
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
                            .fill(Color.white)
                            .frame(width: 80, height: 80)

                        if selectedMode == .video && isRecording {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.red)
                                .frame(width: 32, height: 32)
                        } else {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.purple, .blue],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 60, height: 60)
                        }
                    }
                }

                Spacer()

                // Placeholder for balance
                Color.clear
                    .frame(width: 50, height: 50)
            }
            .padding(.horizontal, 40)

            // Device Info
            HStack {
                Spacer()
                Text("iPhone M")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.trailing, 20)
            }
        }
        .padding(.bottom, 30)
        .background(Color.black)
    }

    // MARK: - Recording Functions

    private func startRecording() {
        isRecording = true
        recordingTime = 0
        cameraManager.startRecording()

        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            recordingTime += 0.1
            if recordingTime >= 3.0 {
                stopRecording()
            }
        }
    }

    private func stopRecording() {
        isRecording = false
        timer?.invalidate()
        timer = nil
        cameraManager.stopRecording()
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
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
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

            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { image, _ in
                    DispatchQueue.main.async {
                        print("PhotoPicker: Setting selectedImage")
                        self.parent.selectedImage = image as? UIImage
                        print("PhotoPicker: selectedImage set to \(self.parent.selectedImage != nil)")
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
            print("Video saved to: \(outputFileURL)")
        }
    }
}

#Preview {
    CaptureView()
}
