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

            if cameraPreviewOpacity >= 1 {
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
                focusedImageID: $focusedImageID,
                onViewportFrameChange: { frame in
                    guard !frame.isEmpty else { return }
                    resultViewportFrame = frame
                    startPendingResultTransitionIfPossible()
                },
                onImageFrameChange: { id, frame in
                    guard !frame.isEmpty else { return }
                    imageFrames[id] = frame
                    startPendingResultTransitionIfPossible()
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
        .safeAreaBar(edge: .top) {
            HStack {
                CircularButton(icon: "chevron.left", action: goBack)
                    .accessibilityLabel("Back")

                Spacer()

                if viewType == .result {
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

    private func goBack() {
        guard !isTransitioning, transitionImage == nil else { return }
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
        let scannerImage: ScannerImage
        if let replacementID,
           let index = images.firstIndex(where: { $0.id == replacementID }) {
            scannerImage = ScannerImage(id: replacementID, image: image)
            images[index] = scannerImage
            focusedImageID = replacementID
        } else {
            scannerImage = ScannerImage(id: cameraImageID, image: image)
            images.append(scannerImage)
            focusedImageID = scannerImage.id
        }
        replacementID = nil
        beginResultTransition(with: scannerImage)
    }

    private func openCamera(replacing id: UUID?) {
        guard !isTransitioning,
              let image = images.first(where: { $0.id == (id ?? focusedImageID) }),
              let startFrame = imageFrames[image.id],
              !startFrame.isEmpty,
              !cameraFrame.isEmpty else { return }

        focusedImageID = image.id
        replacementID = id
        cameraImageID = image.id
        transitionFrame = startFrame
        transitionCornerRadius = 28
        transitionOpacity = 1
        transitionImage = image
        isTransitioning = true
        isExpandingToCamera = true
        // Warm up behind the photo while it expands to fill the screen.
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
                if id == nil { cameraImageID = UUID() }
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
                transitionImage = nil
                isTransitioning = false
                viewType = .result
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
                transitionImage = nil
                isTransitioning = false
            }
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
    let image: UIImage

    init(id: UUID = UUID(), image: UIImage) {
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
        .safeAreaBar(edge: .bottom) {
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
    @Binding var focusedImageID: UUID?
    let onViewportFrameChange: (CGRect) -> Void
    let onImageFrameChange: (UUID, CGRect) -> Void
    let onRetry: (UUID) -> Void

    private var focusedIndex: Int {
        images.firstIndex { $0.id == focusedImageID } ?? 0
    }

    var body: some View {
        GeometryReader { geometry in
            let cardWidth = min(geometry.size.width - 80, 448)

            ScrollView(.horizontal) {
                HStack(spacing: 16) {
                    ForEach(images) { item in
                        ScannerImageCard(
                            image: item.image,
                            isHidden: hiddenImageID == item.id,
                            width: cardWidth,
                            onFrameChange: { onImageFrameChange(item.id, $0) },
                            onRetry: { onRetry(item.id) }
                        )
                        .scrollTransition(.interactive, axis: .horizontal) { view, phase in
                            view
                                .scaleEffect(phase.isIdentity ? 1 : 0.85)
                                .blur(radius: phase.isIdentity ? 0 : 5)
                        }
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, (geometry.size.width - cardWidth) / 2, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $focusedImageID)
            .scrollIndicators(.hidden)
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 12) {
                    CircularButton(icon: "chevron.left") { moveFocus(by: -1) }
                        .accessibilityLabel("Previous image")
                        .disabled(focusedIndex == 0)
                        .opacity(focusedIndex == 0 ? 0.4 : 1)

                    Button {} label: {
                        Text("Done")
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
            }
        }
        .onGeometryChange(for: CGRect.self, of: { $0.frame(in: .global) }) { _, frame in
            onViewportFrameChange(frame)
        }
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
    let image: UIImage
    let isHidden: Bool
    let width: CGFloat
    let onFrameChange: (CGRect) -> Void
    let onRetry: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)

        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: width, height: 400)
            .clipShape(shape)
            .compositingGroup()
            .shadow(color: .black.opacity(0.15), radius: 15, x: 0, y: 4)
            .opacity(isHidden ? 0 : 1)
            .onGeometryChange(for: CGRect.self, of: { $0.frame(in: .global) }) { _, frame in
                onFrameChange(frame)
            }
            .overlay(alignment: .bottomTrailing) {
                if !isHidden {
                    CircularButton(icon: "arrow.clockwise", iconColor: .white, action: onRetry)
                        .accessibilityLabel("Replace image")
                        .padding()
                }
            }
            .frame(maxHeight: .infinity)
    }
}

@Animatable
private struct ScannerMovingImage: View {
    @AnimatableIgnored var image: UIImage
    var originX: CGFloat
    var originY: CGFloat
    var width: CGFloat
    var height: CGFloat
    var cornerRadius: CGFloat
    var opacity: Double

    var body: some View {
        // Fill the interpolated viewport on every frame of the animation.
        let imageAspectRatio = image.size.width / max(image.size.height, 1)
        let filledWidth = max(width, height * imageAspectRatio)
        let filledHeight = max(height, width / imageAspectRatio)

        Image(uiImage: image)
            .resizable()
            .frame(width: filledWidth, height: filledHeight)
            .frame(width: width, height: height)
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
