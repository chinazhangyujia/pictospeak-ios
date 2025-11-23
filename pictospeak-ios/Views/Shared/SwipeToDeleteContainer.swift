//
//  SwipeToDeleteContainer.swift
//  pictospeak-ios
//
//  Created by AI Assistant.
//

import SwiftUI

struct SwipeToDeleteContainer<Content: View>: View {
    let content: Content
    let onDelete: () async -> Void
    let isEnabled: Bool
    let cornerRadius: CGFloat
    let onTap: (() -> Void)? // Added tap handler

    init(isEnabled: Bool = true, cornerRadius: CGFloat = 0, onDelete: @escaping () async -> Void, onTap: (() -> Void)? = nil, @ViewBuilder content: () -> Content) {
        self.isEnabled = isEnabled
        self.cornerRadius = cornerRadius
        self.onDelete = onDelete
        self.onTap = onTap
        self.content = content()
    }

    @State private var offset: CGFloat = 0
    @State private var isDeleting = false
    @State private var isSwiped = false

    private let buttonWidth: CGFloat = 80

    var body: some View {
        ZStack(alignment: .trailing) {
            // Content Layer
            // We use zIndex to keep it visually on top, but define it first so the button (defined second)
            // has a chance to catch touches if the content doesn't block them.
            // However, in ZStack, hit testing follows z-order (visual order).
            // So we must rely on the content moving out of the way.

            content
                .offset(x: offset)
                // IMPORTANT: Remove .contentShape(Rectangle()) here because it extends the hit-test area
                // to the original bounds even when offset (in some container contexts), blocking the button.
                // We rely on the content having its own shape/background.
                .zIndex(1)
                .onTapGesture {
                    // If swiped open, close it. Otherwise perform tap action.
                    if isSwiped {
                        withAnimation(.spring()) {
                            offset = 0
                            isSwiped = false
                        }
                    } else {
                        onTap?()
                    }
                }
                .gesture(
                    isEnabled ?
                        DragGesture(minimumDistance: 20, coordinateSpace: .local)
                        .onChanged { gesture in
                            // Only capture horizontal swipes
                            if abs(gesture.translation.width) > abs(gesture.translation.height) {
                                if gesture.translation.width < 0 {
                                    // Swiping left (reveal delete)
                                    self.offset = gesture.translation.width
                                } else if isSwiped {
                                    // Swiping right (hide delete)
                                    // Start from -buttonWidth and add positive translation
                                    let newOffset = -buttonWidth + gesture.translation.width
                                    self.offset = min(0, newOffset)
                                }
                            }
                        }
                        .onEnded { gesture in
                            // Determine snap point based on threshold
                            if abs(gesture.translation.width) > abs(gesture.translation.height) {
                                withAnimation(.spring()) {
                                    if offset < -buttonWidth / 2 {
                                        offset = -buttonWidth
                                        isSwiped = true
                                    } else {
                                        offset = 0
                                        isSwiped = false
                                    }
                                }
                            } else {
                                // If it was a vertical drag that ended, reset just in case
                                withAnimation(.spring()) {
                                    if isSwiped {
                                        offset = -buttonWidth
                                    } else {
                                        offset = 0
                                    }
                                }
                            }
                        } : nil
                )

            // Delete Button Layer
            Button(action: {
                print("🗑️ Delete button tapped")
                Task {
                    isDeleting = true
                    await onDelete()
                    withAnimation {
                        isDeleting = false
                        offset = 0
                        isSwiped = false
                    }
                }
            }) {
                ZStack {
                    Color.red

                    if isDeleting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "trash.fill")
                            .foregroundColor(.white)
                            .font(.title2)
                    }
                }
                .frame(width: buttonWidth)
            }
            .frame(width: buttonWidth)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            // Only show when swiped slightly to avoid visual glitches
            .opacity(offset < -5 ? 1 : 0)
            .padding(.trailing, 0)
            .zIndex(0) // Visually behind content
        }
    }
}
