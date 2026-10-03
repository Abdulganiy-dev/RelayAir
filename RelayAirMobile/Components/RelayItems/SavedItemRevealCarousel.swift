import SwiftUI

struct SavedItemRevealCarousel: View {
    let items: [RelayItem]
    let onSelect: (RelayItem) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("wantsHaptics") private var wantsHaptics = true

    private let revealThreshold: CGFloat = 0.06
    private let revealDuration: TimeInterval = 1

    @State private var currentIndex = 0
    @State private var dragOffset: CGFloat = 0
    @State private var revealProgress: CGFloat = 0
    @State private var activeNeighborIndex: Int?
    @State private var isSettling = false
    @State private var settlingTargetIndex: Int?
    @State private var transitionGeneration = 0
    @State private var shakeTrigger = 0
    @State private var hasShakenThisDrag = false

    var body: some View {
        GeometryReader { geometry in
            accessibleSurface(pageWidth: geometry.size.width)
        }
        .onChange(of: items.map(\.id)) { previousIDs, newIDs in
            let selectedID = previousIDs.indices.contains(currentIndex) ? previousIDs[currentIndex] : nil
            currentIndex = selectedID.flatMap { newIDs.firstIndex(of: $0) }
                ?? min(currentIndex, max(newIDs.count - 1, 0))
            dragOffset = 0
            revealProgress = 0
            activeNeighborIndex = nil
            isSettling = false
            settlingTargetIndex = nil
            transitionGeneration += 1
            hasShakenThisDrag = false
        }
    }

    private func cardLayers() -> some View {
        ZStack {
            if let neighboringIndex = activeNeighborIndex,
               items.indices.contains(neighboringIndex) {
                AnimatedRevealCard(item: items[neighboringIndex], progress: revealProgress)
            }

            if items.indices.contains(currentIndex) {
                PeelingRevealCard(
                    item: items[currentIndex],
                    progress: revealProgress,
                    direction: activeNeighborIndex.map { $0 > currentIndex ? 1 : -1 } ?? 1,
                    reduceMotion: reduceMotion
                )
            }
        }
        .keyframeAnimator(initialValue: CGFloat.zero, trigger: shakeTrigger) { content, offset in
            content.offset(x: offset)
        } keyframes: { _ in
            KeyframeTrack {
                LinearKeyframe(-12, duration: 0.06)
                LinearKeyframe(12, duration: 0.1)
                LinearKeyframe(-8, duration: 0.08)
                LinearKeyframe(8, duration: 0.08)
                LinearKeyframe(0, duration: 0.06)
            }
        }
    }

    private func interactiveSurface(pageWidth: CGFloat) -> some View {
        cardLayers()
            .onTapGesture(perform: selectCurrentItem)
            .hapticFeedback(style: .light)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .simultaneousGesture(swipeGesture(pageWidth: pageWidth))
   
    }

    private func accessibleSurface(pageWidth: CGFloat) -> some View {
        let itemName = items.indices.contains(currentIndex) ? items[currentIndex].displayName : "Saved items"

        return interactiveSurface(pageWidth: pageWidth)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: itemName))
            .accessibilityValue(Text("\(currentIndex + 1) of \(items.count)"))
            .accessibilityAddTraits(.isButton)
            .accessibilityAction {
                selectCurrentItem()
            }
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment:
                    settle(on: currentIndex + 1)
                case .decrement:
                    settle(on: currentIndex - 1)
                @unknown default:
                    break
                }
            }
            .accessibilityHidden(items.isEmpty)
    }

    private func progress(for offset: CGFloat, pageWidth: CGFloat) -> CGFloat {
        let distance = abs(offset) / max(pageWidth, 1)
        return min(max((distance - revealThreshold) / (1 - revealThreshold), 0), 1)
    }

    private func swipeGesture(pageWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }

                if isSettling {
                    finishTransition(on: settlingTargetIndex)
                }

                guard items.indices.contains(currentIndex) else { return }
                let direction = value.translation.width > 0 ? 1 : -1

                guard items.indices.contains(currentIndex + direction) else {
                    dragOffset = 0
                    activeNeighborIndex = nil
                    revealProgress = 0
                    if !hasShakenThisDrag {
                        hasShakenThisDrag = true
                        shakeCard()
                    }
                    return
                }

                let neighborIndex = currentIndex + direction
                if activeNeighborIndex != neighborIndex {
                    activeNeighborIndex = neighborIndex
                    revealProgress = 0
                }
                dragOffset = min(max(value.translation.width, -pageWidth), pageWidth)
                withAnimation(.interactiveSpring(response: 0.15, dampingFraction: 0.86)) {
                    revealProgress = progress(for: dragOffset, pageWidth: pageWidth)
                }
            }
            .onEnded { _ in
                hasShakenThisDrag = false
                guard !isSettling, dragOffset != 0 else { return }

                let direction = dragOffset > 0 ? 1 : -1

                if abs(dragOffset) >= pageWidth * revealThreshold {
                    settle(on: currentIndex + direction)
                } else {
                    animateTransition(to: 0, targetIndex: nil, duration: 0.22)
                }
            }
    }

    private func settle(on targetIndex: Int) {
        guard !isSettling else { return }
        guard items.indices.contains(targetIndex) else {
            if !items.isEmpty { shakeCard() }
            return
        }
        activeNeighborIndex = targetIndex
        if wantsHaptics {
            HapticService.shared.generateFeedback(style: .heavy)
        }
        animateTransition(to: 1, targetIndex: targetIndex, duration: revealDuration)
    }

    private func animateTransition(to progress: CGFloat, targetIndex: Int?, duration: TimeInterval) {
        transitionGeneration += 1
        let generation = transitionGeneration
        isSettling = true
        settlingTargetIndex = targetIndex
        withAnimation(.smooth(duration: duration), completionCriteria: .removed) {
            revealProgress = progress
        } completion: {
            guard isSettling, transitionGeneration == generation else { return }
            finishTransition(on: targetIndex)
        }
    }

    private func finishTransition(on targetIndex: Int?) {
        transitionGeneration += 1
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            if let targetIndex, items.indices.contains(targetIndex) { currentIndex = targetIndex }
            activeNeighborIndex = nil
            revealProgress = 0
            dragOffset = 0
            isSettling = false
            settlingTargetIndex = nil
        }
    }

    private func selectCurrentItem() {
        finishTransition(on: settlingTargetIndex)

        guard items.indices.contains(currentIndex), !isSettling else { return }
        onSelect(items[currentIndex])
    }

    private func shakeCard() {
        shakeTrigger += 1
        if wantsHaptics {
            HapticService.shared.generateFeedback(style: .medium)
        }
    }
}

private struct AnimatedRevealCard: View, Animatable {
    let item: RelayItem
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        SavedItemCard(item: item, nameOpacity: Double(nameProgress))
    }

    private var nameProgress: CGFloat {
        min(max((clampedProgress - 0.7) / 0.18, 0), 1)
    }

    private var clampedProgress: CGFloat {
        guard progress.isFinite else { return 0 }
        return min(max(progress, 0), 1)
    }
}

private struct PeelingRevealCard: View, Animatable {
    let item: RelayItem
    var progress: CGFloat
    let direction: Float
    let reduceMotion: Bool

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        SavedItemCard(item: item)
            .layerEffect(
                ShaderLibrary.cardPeel(
                    .float(Float(clampedProgress)),
                    .float(direction),
                    .float(Float(EditableCard.standard.width))
                ),
                maxSampleOffset: CGSize(width: 9, height: 9),
                isEnabled: !reduceMotion
            )
//            .opacity(reduceMotion ? 1 - clampedProgress : 1)
    }

    private var clampedProgress: CGFloat {
        guard progress.isFinite else { return 0 }
        return min(max(progress, 0), 1)
    }
}
