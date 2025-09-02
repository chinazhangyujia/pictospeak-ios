//
//  InternalUploadedMaterialsViewModel.swift
//  pictospeak-ios
//
//  Created by AI Assistant.
//

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

    // MARK: - Private Properties

    private let service = InternalUploadedMaterialService.shared
    var contentViewModel: ContentViewModel

    // MARK: - Initialization

    init(contentViewModel: ContentViewModel) {
        self.contentViewModel = contentViewModel
        Task {
            await loadInitialMaterials()
        }
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
        await loadInitialMaterials()
    }

    // MARK: - Private Methods

    /// Loads the initial page of materials
    private func loadInitialMaterials() async {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await service.fetchInternalUploadedMaterials(authToken: contentViewModel.authToken!)
            materials = response.items
            nextCursor = response.nextCursor
            currentIndex = 0

            print("✅ Loaded initial materials: \(materials.count) items")
        } catch {
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
            let response = try await service.fetchInternalUploadedMaterials(authToken: contentViewModel.authToken!, cursor: cursor)

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
}
