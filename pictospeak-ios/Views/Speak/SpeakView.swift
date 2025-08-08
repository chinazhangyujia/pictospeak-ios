//
//  SpeakView.swift
//  pictospeak-ios
//
//  Created by Yujia Zhang on 8/4/25.
//

import AVFoundation
import SwiftUI

struct SpeakView: View {
    @Environment(\.dismiss) private var dismiss
    let selectedImage: UIImage
    let mediaType: MediaType
    @State private var isRecording = false
    @State private var audioRecorder: AVAudioRecorder?
    @State private var recordingURL: URL?
    @State private var recordingTimer: Timer?
    @State private var recordingTime: TimeInterval = 0
    @State private var showFeedbackView = false
    @State private var recordedAudioData: Data?

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                // Background Image
                Image(uiImage: selectedImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                    .clipped()
                    .ignoresSafeArea()

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
        }
        .onDisappear {
            stopRecording()
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
                        showFeedbackView = true
                    } catch {
                        print("Failed to read audio data: \(error)")
                    }
                }
            }
        }
        .background(
            NavigationLink(
                destination: FeedbackView(
                    showFeedbackView: $showFeedbackView,
                    selectedImage: selectedImage,
                    audioData: recordedAudioData ?? Data(),
                    mediaType: mediaType
                )
                .navigationBarHidden(true)
                .navigationBarBackButtonHidden(true),
                isActive: $showFeedbackView
            ) {
                EmptyView()
            }
            .hidden()
        )
    }

    // MARK: - Top Section

    private var topSection: some View {
        HStack {
            Button(action: {
                dismiss()
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
            let audioFilename = documentsPath.appendingPathComponent("recording.wav")
            recordingURL = audioFilename

            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatLinearPCM),
                AVSampleRateKey: 12000,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsFloatKey: false,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            ]

            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
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
}

#Preview {
    // Create a sample image for preview
    let sampleImage = UIImage(systemName: "photo") ?? UIImage()
    SpeakView(selectedImage: sampleImage, mediaType: .image)
}
