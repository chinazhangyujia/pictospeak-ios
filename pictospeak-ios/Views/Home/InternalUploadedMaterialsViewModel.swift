//
//  InternalUploadedMaterialsViewModel.swift
//  pictospeak-ios
//
//  Created by AI Assistant.
//

import AVFoundation
import Foundation
import SwiftUI

@MainActor
class InternalUploadedMaterialsViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var materials: [Material] = []
    @Published var currentIndex: Int = 0
    @Published var nextCursor: String?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // MARK: - Cache

    var videoPlayerCache: [UUID: AVPlayer] = [:]
    var imageCache: [UUID: UIImage] = [:]

    // MARK: - Private Properties

    private let service = InternalUploadedMaterialService.shared
    private var loadingTask: Task<Void, Never>?

    // MARK: - Initialization

    init() {
        // Don't auto-load in init - let the view control when to load
    }

    // MARK: - Public Methods

    /// Sets the current index and automatically loads next page if needed
    /// - Parameter index: The new index to set
    func setCurrentIndex(_ index: Int) {
        currentIndex = index

        // Check if we need to load the next page
        if shouldLoadNextPage() {
            Task {
                await loadNextPage()
            }
        }
    }

    /// Manually refresh the materials list
    func refresh() async {
        // Cancel any existing loading task
        loadingTask?.cancel()

        // Create new loading task
        loadingTask = Task {
            await loadInitialMaterials()
        }

        await loadingTask?.value
    }

    /// Load initial materials (public method for view to call)
    func loadInitialMaterials() async {
        // Cancel any existing loading task
        loadingTask?.cancel()

        // Create new loading task
        loadingTask = Task {
            await loadInitialMaterialsInternal()
        }

        await loadingTask?.value
    }

    // MARK: - Private Methods

    /// Loads the initial page of materials (internal implementation)
    private func loadInitialMaterialsInternal() async {
        isLoading = true
        errorMessage = nil

        do {
            // Check if task was cancelled
            if Task.isCancelled { return }

            let response = try await service.fetchInternalUploadedMaterials()

            // Check if task was cancelled after the request
            if Task.isCancelled { return }

            materials = response.items
            nextCursor = response.nextCursor
            currentIndex = 0
            // Preload first 10 materials
            preloadFirstFewMaterials()
        } catch {
            // Check if task was cancelled
            if Task.isCancelled { return }

            errorMessage = "Failed to load materials: \(error.localizedDescription)"
            print("❌ Error loading initial materials: \(error)")
        }

        isLoading = false
    }

    /// Loads the next page of materials and appends to the existing list
    private func loadNextPage() async {
        guard let cursor = nextCursor, !isLoading else { return }

        isLoading = true
        errorMessage = nil

        do {
            let response = try await service.fetchInternalUploadedMaterials(cursor: cursor)

            // Append new materials to existing list
            materials.append(contentsOf: response.items)
            nextCursor = response.nextCursor

            print("✅ Loaded next page: \(response.items.count) additional items. Total: \(materials.count)")
        } catch {
            errorMessage = "Failed to load next page: \(error.localizedDescription)"
            print("❌ Error loading next page: \(error)")
        }

        isLoading = false
    }

    /// Determines if the next page should be loaded based on current index and cursor availability
    private func shouldLoadNextPage() -> Bool {
        // Load next page when:
        // 1. Current index is approaching the end of the list (within 2 items)
        // 2. There's a next cursor available
        // 3. Not currently loading
        return currentIndex >= materials.count - 2 &&
            nextCursor != nil &&
            !isLoading
    }

    /// Preload the first 10 materials to improve initial playback performance
    private func preloadFirstFewMaterials() {
        let itemsToPreload = materials.prefix(10)

        for material in itemsToPreload {
            if material.type == .video {
                if videoPlayerCache[material.id] == nil, let url = URL(string: material.materialUrl) {
                    let player = AVPlayer(url: url)
                    player.actionAtItemEnd = .none
                    player.isMuted = true // Mute preloaded videos by default
                    videoPlayerCache[material.id] = player
                }
            } else if material.type == .image {
                if imageCache[material.id] == nil, let url = URL(string: material.materialUrl) {
                    URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
                        if let data = data, let image = UIImage(data: data) {
                            Task { @MainActor [weak self] in
                                self?.imageCache[material.id] = image
                            }
                        }
                    }.resume()
                }
            }
        }
    }

    // MARK: - Computed Properties

    /// Returns the current material being viewed
    var currentMaterial: Material? {
        guard currentIndex >= 0, currentIndex < materials.count else {
            return nil
        }
        return materials[currentIndex]
    }

    /// Returns whether there are more materials available
    var hasMoreMaterials: Bool {
        return nextCursor != nil
    }

    /// Returns whether the current index is valid
    var isCurrentIndexValid: Bool {
        return currentIndex >= 0 && currentIndex < materials.count
    }

    deinit {
        loadingTask?.cancel()
    }
}
