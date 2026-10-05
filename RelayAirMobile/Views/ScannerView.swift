import AVFoundation
import PhotosUI
import SwiftUI

enum ScannerViewType {
    case camera
    case result
}

struct ScannerView: View {
    @Environment(RelayNavigationStore.self) private var navigation
    @State private var viewType: ScannerViewType = .camera
    @State private var camera = ScannerCamera()
    @State private var cameraShouldRun = true
    @State private var cameraIsReady = false
    @State private var cameraPreviewIsReady = false
    @State private var cameraPreviewOpacity = 0.0
    @State private var isExpandingToCamera = false
    @State private var cameraMessage: String?
    @State private var isCapturing = false
    @State private var images: [ScannerImage] = []
    @State private var focusedImageID: UUID?
    @State private var replacementID: UUID?
    @State private var placeholderID: UUID?
    @State private var focusBeforeAddingID: UUID?
    @State private var pendingCameraImageID: UUID?
    @State private var cameraImageID = UUID()
    @State private var transitionImage: ScannerImage?
    @State private var transitionFrame: CGRect = .zero
    @State private var transitionCornerRadius: CGFloat = 0
    @State private var transitionOpacity = 1.0
    @State private var pendingResultImageID: UUID?
    @State private var cameraFrame: CGRect = .zero
    @State private var resultViewportFrame: CGRect = .zero
    @State private var imageFrames: [UUID: CGRect] = [:]
    @State private var isTransitioning = false
    @State private var gallerySelection: [PhotosPickerItem] = []
    /// Photos restacked vertically for extraction. Adding or replacing a photo is off
    /// here: the camera transitions measure cards in the horizontal row.
    @State private var isExtracting = false
    /// Browse controls (bottom bar, add, replace). Trails `isExtracting`: it only flips
    /// once the layout switch has finished, so the controls change after the photos
    /// have settled rather than while they are still moving.
    @State private var showsResultControls = true

    var body: some View {
        ZStack {
            // The preview and moving photo share the full screen, including safe areas.
            GeometryReader { screen in
                let screenFrame = screen.frame(in: .global)

                ZStack(alignment: .topLeading) {

                        ScannerCameraPreview(session: camera.session) {
                            guard cameraShouldRun else { return }
                            cameraPreviewIsReady = true
                            revealCameraWhenReady()
                        }
                        .frame(width: screen.size.width, height: screen.size.height)
                        .opacity(cameraPreviewOpacity)



                    if let transitionImage {
                        ScannerMovingImage(
                            image: transitionImage.image,
                            originX: transitionFrame.minX - screenFrame.minX,
                            originY: transitionFrame.minY - screenFrame.minY,
                            width: transitionFrame.width,
                            height: transitionFrame.height,
                            cornerRadius: transitionCornerRadius,
                            opacity: transitionOpacity
                        )


                    }
                }

                .frame(width: screen.size.width, height: screen.size.height)
                .onGeometryChange(for: CGRect.self, of: { $0.frame(in: .global) }) { _, frame in
                    if !frame.isEmpty { cameraFrame = frame }
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .zIndex(transitionImage == nil ? 0 : 2)

            if viewType == .camera && (cameraPreviewOpacity >= 1 || cameraMessage != nil) {
                ScannerCameraScreen(
                    isReady: cameraIsReady && !isCapturing && !isTransitioning && transitionImage == nil,
                    canChooseGallery: !isTransitioning && transitionImage == nil,
                    message: cameraMessage,
                    gallerySelection: $gallerySelection,
                    gallerySelectionLimit: replacementID == nil ? 10 : 1,
                    onCapture: capturePhoto
                )
                .transition(.blurReplace)
//                .opacity(cameraMessage != nil ? 1 : cameraPreviewOpacity)
                .allowsHitTesting(viewType == .camera && !isTransitioning)
                .accessibilityHidden(viewType != .camera)
                .zIndex(1)
            }




            ScannerResultsScreen(
                images: images,
                hiddenImageID: transitionImage?.id,
                pendingCameraImageID: pendingCameraImageID,
                focusedImageID: $focusedImageID,
                isExtracting: isExtracting,
                showsControls: showsResultControls,
                onExtract: { setExtracting(true) },
                onViewportFrameChange: { frame in
                    guard !frame.isEmpty else { return }
                    resultViewportFrame = frame
                    startPendingResultTransitionIfPossible()
                    startPendingCameraTransitionIfPossible()
                },
                onImageFrameChange: { id, frame in
                    guard !frame.isEmpty else { return }
                    imageFrames[id] = frame
                    startPendingResultTransitionIfPossible()
                    startPendingCameraTransitionIfPossible()
                },
                onRetry: { openCamera(replacing: $0) }
            )
            .opacity(viewType == .result ? 1 : 0)
            .allowsHitTesting(viewType == .result && !isTransitioning)
            .accessibilityHidden(viewType != .result)
            .zIndex(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .relayAppBackground()
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .top) {
            HStack {
                CircularButton(icon: "chevron.left", action: goBack)
                    .accessibilityLabel("Back")

                Spacer()

                if viewType == .result && showsResultControls {
                    CircularButton(icon: "plus") { openCamera(replacing: nil) }
                        .accessibilityLabel("Add another image")
                }
            }
            .disabled(isTransitioning)
            .opacity(isTransitioning ? 0 : 1)
            .padding(.horizontal, 16)
        }
        .task(id: cameraShouldRun) {
            if cameraShouldRun {
                cameraIsReady = false
                cameraPreviewIsReady = false
                cameraPreviewOpacity = 0
                cameraMessage = nil
                do {
                    let ready = try await camera.start()
                    guard !Task.isCancelled, cameraShouldRun else { return }
                    cameraIsReady = ready
                } catch {
                    if !Task.isCancelled {
                        cameraMessage = error.localizedDescription
                    }
                }
                revealCameraWhenReady()
            } else {
                cameraIsReady = false
                await camera.stop()
            }
        }
        .onDisappear {
            Task { await camera.stop() }
        }
        .onChange(of: gallerySelection) { _, selectedItems in
            guard !selectedItems.isEmpty else { return }
            Task { await importImages(selectedItems) }
        }

    }

    /// Scroll to the first photo, then switch layout, then show or hide the controls.
    /// At the first photo the scroll offset is zero, so swapping the scroll axis has no
    /// position to throw away and the cards move in one clean motion.
    private func setExtracting(_ extracting: Bool) {
        withAnimation(.smooth(duration: 0.35)) {
            focusedImageID = images.first?.id
        } completion: {
            withAnimation(ScannerResultsScreen.layoutAnimation) {
                isExtracting = extracting
            } completion: {
                withAnimation(.smooth(duration: 0.25)) {
                    showsResultControls = !isExtracting
                }
            }
        }
    }

    private func goBack() {
        guard !isTransitioning, transitionImage == nil else { return }
        if isExtracting {
            setExtracting(false)
            return
        }
        if viewType == .camera && !images.isEmpty {
            replacementID = nil
            if let image = images.first(where: { $0.id == focusedImageID }) {
                cameraImageID = image.id
                isTransitioning = true
                Task {
                    await pauseCamera()
                    beginResultTransition(with: image)
                }
            }
        } else {
            navigation.pop()
        }
    }

    private func capturePhoto() {
        guard cameraIsReady, !isCapturing, !isTransitioning, transitionImage == nil else { return }
        isCapturing = true
        Task {
            defer { isCapturing = false }
            guard let image = await camera.capture() else {
                cameraMessage = "Couldn’t capture the photo. Please try again."
                return
            }
            isTransitioning = true
            await pauseCamera()
            insert(image)
        }
    }

    private func importImages(_ selectedItems: [PhotosPickerItem]) async {
        var loadedImages: [UIImage] = []
        for item in selectedItems {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else { continue }
            loadedImages.append(image)
        }
        gallerySelection = []
        guard !loadedImages.isEmpty else { return }
        isTransitioning = true
        await pauseCamera()

        if replacementID != nil {
            insert(loadedImages[0])
        } else if placeholderID != nil {
            images.append(contentsOf: loadedImages.dropFirst().map { ScannerImage(image: $0) })
            insert(loadedImages[0])
        } else {
            let newImages = loadedImages.enumerated().map { index, image in
                ScannerImage(
                    id: index == loadedImages.count - 1 ? cameraImageID : UUID(),
                    image: image
                )
            }
            focusedImageID = cameraImageID
            images.append(contentsOf: newImages)
            if let lastImage = newImages.last {
                beginResultTransition(with: lastImage)
            }
        }
    }

    private func insert(_ image: UIImage) {
        let scannerImage = ScannerImage(id: replacementID ?? cameraImageID, image: image)
        if let index = images.firstIndex(where: { $0.id == scannerImage.id }) {
            images[index] = scannerImage
        } else {
            images.append(scannerImage)
        }
        focusedImageID = scannerImage.id
        replacementID = nil
        if placeholderID == scannerImage.id {
            placeholderID = nil
            focusBeforeAddingID = nil
        }
        beginResultTransition(with: scannerImage)
    }

    private func openCamera(replacing id: UUID?) {
        guard !isTransitioning, viewType == .result, !cameraFrame.isEmpty else { return }

        if let id {
            guard let image = images.first(where: { $0.id == id }),
                  image.image != nil,
                  let startFrame = imageFrames[id], !startFrame.isEmpty else { return }
            replacementID = id
            beginCameraTransition(with: image, from: startFrame)
        } else {
            let placeholder = ScannerImage()
            focusBeforeAddingID = focusedImageID
            placeholderID = placeholder.id
            pendingCameraImageID = placeholder.id
            cameraImageID = placeholder.id
            replacementID = nil
            isTransitioning = true
            isExpandingToCamera = true
            cameraShouldRun = true

            // Center the new slot before using its measured frame for expansion.
            withAnimation(.smooth(duration: 0.25)) {
                images.append(placeholder)
            }
        }
    }

    private func startPendingCameraTransitionIfPossible() {
        guard viewType == .result,
              let id = pendingCameraImageID,
              let image = images.first(where: { $0.id == id }),
              let frame = imageFrames[id], !frame.isEmpty,
              !resultViewportFrame.isEmpty,
              abs(frame.midX - resultViewportFrame.midX) < 2 else { return }
        beginCameraTransition(with: image, from: frame)
    }

    private func beginCameraTransition(with image: ScannerImage, from startFrame: CGRect) {
        pendingCameraImageID = nil
        focusedImageID = image.id
        cameraImageID = image.id
        transitionFrame = startFrame
        transitionCornerRadius = 28
        transitionOpacity = 1
        transitionImage = image
        isTransitioning = true
        isExpandingToCamera = true
        // Warm up behind the card while it expands to fill the screen.
        cameraShouldRun = true

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(20))
            guard viewType == .result, transitionImage?.id == image.id else { return }
            withAnimation(.spring(duration: 0.5, bounce: 0.08), completionCriteria: .removed) {
                viewType = .camera
                transitionFrame = cameraFrame
                transitionCornerRadius = 0
            } completion: {
                guard viewType == .camera, transitionImage?.id == image.id else { return }
                isExpandingToCamera = false
                revealCameraWhenReady()
            }
        }
    }

    private func pauseCamera() async {
        cameraShouldRun = false
        cameraIsReady = false
        cameraPreviewIsReady = false

        await camera.stop()
    }

    private func beginResultTransition(with image: ScannerImage) {
        transitionFrame = cameraFrame
        transitionCornerRadius = 0
        transitionOpacity = 1
        transitionImage = image
        // Keep the frozen preview visible until the full-screen photo covers it.
        cameraPreviewOpacity = 0
        pendingResultImageID = image.id
        startPendingResultTransitionIfPossible()

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            guard pendingResultImageID == image.id else { return }
            guard !resultViewportFrame.isEmpty else {
                pendingResultImageID = nil
                viewType = .result
                finishResultTransition(imageID: image.id)
                return
            }
            let width = min(resultViewportFrame.width - 80, 448)
            let fallbackFrame = CGRect(
                x: resultViewportFrame.midX - width / 2,
                y: resultViewportFrame.midY - 200,
                width: width,
                height: 400
            )
            beginResultAnimation(to: imageFrames[image.id] ?? fallbackFrame, imageID: image.id)
        }
    }

    private func startPendingResultTransitionIfPossible() {
        guard let id = pendingResultImageID,
              let frame = imageFrames[id],
              !frame.isEmpty,
              !resultViewportFrame.isEmpty,
              abs(frame.midX - resultViewportFrame.midX) < 24 else { return }
        beginResultAnimation(to: frame, imageID: id)
    }

    private func beginResultAnimation(to frame: CGRect, imageID id: UUID) {
        pendingResultImageID = nil

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(20))
            guard viewType == .camera, transitionImage?.id == id else { return }
            withAnimation(.spring(duration: 0.5, bounce: 0.08), completionCriteria: .removed) {
                viewType = .result
                transitionFrame = imageFrames[id] ?? frame
                transitionCornerRadius = 28
            } completion: {
                guard viewType == .result else { return }
                finishResultTransition(imageID: id)
            }
        }
    }

    private func finishResultTransition(imageID: UUID) {
        transitionImage = nil
        isTransitioning = false

        // Going back without taking a photo discards the temporary slot.
        if placeholderID == imageID {
            let previousFocus = focusBeforeAddingID
            withAnimation(.smooth(duration: 0.25)) {
                images.removeAll { $0.id == imageID }
                focusedImageID = images.first(where: { $0.id == previousFocus })?.id ?? images.last?.id
            }
            imageFrames.removeValue(forKey: imageID)
            placeholderID = nil
            focusBeforeAddingID = nil
            cameraImageID = UUID()
        }
    }

    private func revealCameraWhenReady() {
        guard viewType == .camera, cameraShouldRun, !isExpandingToCamera,
              cameraPreviewIsReady || cameraMessage != nil else { return }
        let targetOpacity = cameraPreviewIsReady ? 1.0 : 0.0
        guard cameraPreviewOpacity != targetOpacity ||
                (transitionImage != nil && transitionOpacity == 1) else { return }
        let imageID = transitionImage?.id

        withAnimation(.easeInOut(duration: 0.35), completionCriteria: .removed) {
            cameraPreviewOpacity = targetOpacity
            if imageID != nil { transitionOpacity = 0 }
        } completion: {
            guard viewType == .camera, cameraShouldRun,
                  let imageID, transitionImage?.id == imageID else { return }
            transitionImage = nil
            transitionOpacity = 1
            isTransitioning = false
        }
    }
}

private struct ScannerImage: Identifiable {
    let id: UUID
    // A nil image reserves a result card for the next capture.
    let image: UIImage?

    init(id: UUID = UUID(), image: UIImage? = nil) {
        self.id = id
        self.image = image
    }
}

private struct ScannerCameraScreen: View {
    @State private var isGalleryPresented = false

    let isReady: Bool
    let canChooseGallery: Bool
    let message: String?
    @Binding var gallerySelection: [PhotosPickerItem]
    let gallerySelectionLimit: Int
    let onCapture: () -> Void

    var body: some View {
        ZStack {
            Color.clear

            if let message {
                Text(message)
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .padding(20)
                    .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 18))
                    .padding(.horizontal, 32)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .bottom) {
            ZStack {
                Button(action: onCapture) {
                    Circle()
                        .fill(.white)
                        .frame(width: 80, height: 80)
                        .padding(7)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .circle)
                .disabled(!isReady)
                .accessibilityLabel("Take photo")

                HStack {
                    CircularButton(icon: "photo.on.rectangle") {
                        isGalleryPresented = true
                    }
                    .photosPicker(
                        isPresented: $isGalleryPresented,
                        selection: $gallerySelection,
                        maxSelectionCount: gallerySelectionLimit,
                        matching: .images
                    )
                    .disabled(!canChooseGallery)
                    .opacity(canChooseGallery ? 1 : 0.4)
                    .accessibilityLabel("Choose from gallery")

                    Spacer()
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)

        }
    }
}

private struct ScannerResultsScreen: View {
    let images: [ScannerImage]
    let hiddenImageID: UUID?
    let pendingCameraImageID: UUID?
    @Binding var focusedImageID: UUID?
    let isExtracting: Bool
    let showsControls: Bool
    let onExtract: () -> Void
    let onViewportFrameChange: (CGRect) -> Void
    let onImageFrameChange: (UUID, CGRect) -> Void
    let onRetry: (UUID) -> Void

    static let layoutAnimation: Animation = .spring(response: 0.85, dampingFraction: 0.86)

    private let cardSpacing: CGFloat = 16
    /// Room for the Back button above the stack (48pt button plus a 16pt gap). Applied
    /// equally top and bottom in both layouts: the row stays centred, and nothing
    /// shifts when the layout switches — a padding change there made the photos jump.
    private let verticalInset: CGFloat = 64

    private var focusedIndex: Int {
        images.firstIndex { $0.id == focusedImageID } ?? 0
    }

    var body: some View {
        GeometryReader { geometry in
            let cardWidth = min(geometry.size.width - 80, 448)
        
            let cardHeight:CGFloat =  400
            let axis: Axis = isExtracting ? .vertical : .horizontal
            // AnyLayout keeps each card's identity across the switch, so the photos
            // glide from the row into the stack instead of being rebuilt.
            let layout = isExtracting
                ? AnyLayout(VStackLayout(spacing: cardSpacing))
                : AnyLayout(HStackLayout(spacing: cardSpacing))

            ScrollViewReader { scrollProxy in
                
                // One scroll view for both layouts. Changing its axis rebuilt it and made
                // the photos jump on the first frame of the switch. `.basedOnSize` keeps it
                // to whichever side overflows: sideways for the row, down for the stack.
                ScrollView([.horizontal, .vertical]) {
                    layout {
                        ForEach(images) { item in
                            ScannerImageCard(
                                image: item.image,
                                isHidden: hiddenImageID == item.id,
                                width: cardWidth,
                                height: cardHeight,
                                showsRetry: showsControls,
                                onFrameChange: { onImageFrameChange(item.id, $0) },
                                onRetry: { onRetry(item.id) }
                            )
                            .id(item.id)
                            .scrollTransition(.interactive, axis: axis) { view, phase in
                                view
                                    .scaleEffect(phase.isIdentity ? 1 : 0.85)
                                    .blur(radius: phase.isIdentity ? 0 : 5)
                            }
                        }
                    }
                    .scrollTargetLayout()
                    // Fill the height so the row sits centred, as a horizontal-only
                    // scroll view centred it.
                    .frame(minHeight: isExtracting ? nil : geometry.size.height - verticalInset * 2)
                }
                .scrollBounceBehavior(.basedOnSize)
                .contentMargins(.horizontal, (geometry.size.width - cardWidth) / 2, for: .scrollContent)
                
                .safeAreaPadding(.vertical, verticalInset)
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: $focusedImageID)
                .scrollIndicators(.hidden)
                .task(id: pendingCameraImageID) {
                    guard let id = pendingCameraImageID else { return }
                    // Wait until the inserted card is registered as a scroll target.
                    try? await Task.sleep(for: .milliseconds(50))
                    guard !Task.isCancelled else { return }
                    withAnimation(.smooth(duration: 0.25)) {
                        scrollProxy.scrollTo(id, anchor: .center)
                    }
                }
                .overlay(alignment: .bottom) {
                    if showsControls {
                        resultControls
                    }
                }
            }
        }
        .onGeometryChange(for: CGRect.self, of: { $0.frame(in: .global) }) { _, frame in
            onViewportFrameChange(frame)
        }
    }

    /// Browse-mode controls. Gone while extracting, so the stack runs to the bottom edge.
    private var resultControls: some View {
        HStack(spacing: 12) {
            CircularButton(icon: "chevron.left") { moveFocus(by: -1) }
                .accessibilityLabel("Previous image")
                .disabled(focusedIndex == 0)
                .opacity(focusedIndex == 0 ? 0.4 : 1)

            Button {
                onExtract()
            } label: {
                Text("Extract Data")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
            }
            .buttonStyle(.plain)
            .glassEffect(
                .regular.tint(AppColors.lightColors.primaryPrimaryDefault).interactive(),
                in: .capsule
            )
            .hapticFeedback()

            CircularButton(icon: "chevron.right") { moveFocus(by: 1) }
                .accessibilityLabel("Next image")
                .disabled(focusedIndex >= images.count - 1)
                .opacity(focusedIndex >= images.count - 1 ? 0.4 : 1)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func moveFocus(by offset: Int) {
        let nextIndex = focusedIndex + offset
        guard images.indices.contains(nextIndex) else { return }
        withAnimation(.smooth(duration: 0.35)) {
            focusedImageID = images[nextIndex].id
        }
    }
}

private struct ScannerImageCard: View {
    let image: UIImage?
    let isHidden: Bool
    let width: CGFloat
    var height: CGFloat = 400
    var showsRetry = true
    let onFrameChange: (CGRect) -> Void
    let onRetry: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)

        ScannerImageContent(image: image, width: width, height: height)
            .clipShape(shape)
            .compositingGroup()
            .shadow(color: .black.opacity(0.15), radius: 15, x: 0, y: 4)
            .opacity(isHidden ? 0 : 1)
            .onGeometryChange(for: CGRect.self, of: { $0.frame(in: .global) }) { _, frame in
                onFrameChange(frame)
            }
            .overlay(alignment: .bottomTrailing) {
                if showsRetry, !isHidden, image != nil {
                    CircularButton(icon: "arrow.clockwise", iconColor: .white, glassEffect: .clear,action: onRetry)
                        .accessibilityLabel("Replace image")
                        .padding()
                }
            }
            .frame(maxHeight: .infinity)
    }
}

private struct ScannerImageContent: View {
    let image: UIImage?
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        ZStack {
            if let image {
                let aspectRatio = image.size.width / max(image.size.height, 1)
                Image(uiImage: image)
                    .resizable()
                    .frame(
                        width: max(width, height * aspectRatio),
                        height: max(height, width / aspectRatio)
                    )
                    .accessibilityLabel("Photo")
            } else {
                Color(uiColor: .secondarySystemBackground)
                    .accessibilityLabel("New photo")
            }
        }
        .frame(width: width, height: height)
    }
}

@Animatable
private struct ScannerMovingImage: View {
    @AnimatableIgnored var image: UIImage?
    var originX: CGFloat
    var originY: CGFloat
    var width: CGFloat
    var height: CGFloat
    var cornerRadius: CGFloat
    var opacity: Double

    var body: some View {
        // Use the same content for the result card and every interpolated frame.
        ScannerImageContent(image: image, width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .compositingGroup()
            .shadow(
                color: .black.opacity(0.15 * cornerRadius / 28),
                radius: 15 * cornerRadius / 28,
                x: 0,
                y: 4 * cornerRadius / 28
            )
            .opacity(opacity)
            .position(x: originX + width / 2, y: originY + height / 2)
            .transaction { $0.animation = nil }
    }
}

private struct ScannerCameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    let onReadyForDisplay: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onReadyForDisplay: onReadyForDisplay)
    }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        view.backgroundColor = .black
        context.coordinator.observe(view.previewLayer)
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {
        context.coordinator.onReadyForDisplay = onReadyForDisplay
        view.previewLayer.session = session
    }

    @MainActor
    final class Coordinator {
        var onReadyForDisplay: () -> Void
        private var readinessObservation: NSKeyValueObservation?

        init(onReadyForDisplay: @escaping () -> Void) {
            self.onReadyForDisplay = onReadyForDisplay
        }

        func observe(_ previewLayer: AVCaptureVideoPreviewLayer) {
            readinessObservation = previewLayer.observe(\.isPreviewing, options: [.initial, .new]) { [weak self] layer, _ in
                guard layer.isPreviewing else { return }
                Task { @MainActor [weak self] in
                    self?.onReadyForDisplay()
                }
            }
        }
    }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

        var previewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}

private actor ScannerCamera {
    nonisolated(unsafe) let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var isConfigured = false
    private var photoDelegate: ScannerPhotoDelegate?

    func start() async throws -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            break
        case .notDetermined:
            guard await AVCaptureDevice.requestAccess(for: .video) else {
                throw ScannerCameraError.permissionDenied
            }
        default:
            throw ScannerCameraError.permissionDenied
        }

        try Task.checkCancellation()

        if !isConfigured {
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let input = try? AVCaptureDeviceInput(device: device) else {
                throw ScannerCameraError.unavailable
            }
            session.beginConfiguration()
            session.sessionPreset = .photo
            guard session.canAddInput(input), session.canAddOutput(photoOutput) else {
                session.commitConfiguration()
                throw ScannerCameraError.unavailable
            }
            session.addInput(input)
            session.addOutput(photoOutput)
            session.commitConfiguration()
            isConfigured = true
        }

        if !session.isRunning { session.startRunning() }
        if Task.isCancelled {
            stop()
            return false
        }
        return session.isRunning
    }

    func stop() {
        if session.isRunning { session.stopRunning() }
    }

    func capture() async -> UIImage? {
        guard session.isRunning else { return nil }
        return await withCheckedContinuation { continuation in
            let delegate = ScannerPhotoDelegate { [weak self] image in
                continuation.resume(returning: image)
                Task { await self?.clearPhotoDelegate() }
            }
            photoDelegate = delegate
            photoOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: delegate)
        }
    }

    private func clearPhotoDelegate() {
        photoDelegate = nil
    }
}

private nonisolated final class ScannerPhotoDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    let completion: (UIImage?) -> Void

    init(completion: @escaping (UIImage?) -> Void) {
        self.completion = completion
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        let image = error == nil ? photo.fileDataRepresentation().flatMap(UIImage.init(data:)) : nil
        completion(image)
    }
}

private enum ScannerCameraError: LocalizedError {
    case permissionDenied
    case unavailable

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            "Allow camera access in Settings to take a photo, or choose one from your gallery."
        case .unavailable:
            "Camera unavailable. Choose an image from your gallery."
        }
    }
}
