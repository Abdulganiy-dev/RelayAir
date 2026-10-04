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
    @State private var cameraIsReady = false
    @State private var cameraMessage: String?
    @State private var isCapturing = false
    @State private var images: [ScannerImage] = []
    @State private var focusedImageID: UUID?
    @State private var replacementID: UUID?
    @State private var gallerySelection: [PhotosPickerItem] = []

    var body: some View {
        ZStack {
            VStack{
                switch viewType {
                case .camera:
                    ScannerCameraScreen(
                        session: camera.session,
                        isReady: cameraIsReady && !isCapturing,
                        message: cameraMessage,
                        gallerySelection: $gallerySelection,
                        gallerySelectionLimit: replacementID == nil ? 10 : 1,
                        onCapture: capturePhoto
                    )
                case .result:
                    ScannerResultsScreen(images: images, focusedImageID: $focusedImageID) { id in
                        focusedImageID = id
                        replacementID = id
                        withAnimation(.easeInOut(duration: 0.25)) {
                            viewType = .camera
                        }
                    }
                }
            }
            .transition(.scale(scale: 1).combined(with: .opacity))
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
                    CircularButton(icon: "plus") {
                        replacementID = nil
                        withAnimation(.easeInOut(duration: 0.25)) {
                            viewType = .camera
                        }
                    }
                    .accessibilityLabel("Add another image")
                }
            }
            .padding(.horizontal, 16)
        }
        .task(id: viewType) {
            if viewType == .camera {
                cameraIsReady = false
                cameraMessage = nil
                do {
                    cameraIsReady = try await camera.start()
                } catch {
                    if !Task.isCancelled {
                        cameraMessage = error.localizedDescription
                    }
                }
            } else {
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
        if viewType == .camera && !images.isEmpty {
            replacementID = nil
            withAnimation(.easeInOut(duration: 0.25)) {
                viewType = .result
            }
        } else {
            navigation.pop()
        }
    }

    private func capturePhoto() {
        guard cameraIsReady, !isCapturing else { return }
        isCapturing = true
        Task {
            defer { isCapturing = false }
            guard let image = await camera.capture() else {
                cameraMessage = "Couldn’t capture the photo. Please try again."
                return
            }
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

        if replacementID != nil {
            insert(loadedImages[0])
        } else {
            let newImages = loadedImages.map { ScannerImage(image: $0) }
            focusedImageID = newImages.first?.id
            images.append(contentsOf: newImages)
            withAnimation(.easeInOut(duration: 0.25)) {
                viewType = .result
            }
        }
    }

    private func insert(_ image: UIImage) {
        if let replacementID,
           let index = images.firstIndex(where: { $0.id == replacementID }) {
            images[index] = ScannerImage(id: replacementID, image: image)
            focusedImageID = replacementID
        } else {
            let newImage = ScannerImage(image: image)
            images.append(newImage)
            focusedImageID = newImage.id
        }
        replacementID = nil
        withAnimation(.easeInOut(duration: 0.25)) {
            viewType = .result
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

    let session: AVCaptureSession
    let isReady: Bool
    let message: String?
    @Binding var gallerySelection: [PhotosPickerItem]
    let gallerySelectionLimit: Int
    let onCapture: () -> Void

    var body: some View {
        ZStack {
            ScannerCameraPreview(session: session)
                .ignoresSafeArea()

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
    @Binding var focusedImageID: UUID?
    let onRetry: (UUID) -> Void

    private var focusedIndex: Int {
        images.firstIndex { $0.id == focusedImageID } ?? 0
    }

    var body: some View {
        GeometryReader { geometry in
            let cardWidth = min(geometry.size.width - 48, 480)

            ScrollView(.horizontal) {
                LazyHStack(spacing: 16) {
                    ForEach(images) { item in
                        ScannerImageCard(
                            image: item.image,
                            width: cardWidth,
                            height: geometry.size.height - 48,
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
    let width: CGFloat
    let height: CGFloat
    let onRetry: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)

        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .clipShape(shape)
            .compositingGroup()
            .shadow(color: .black.opacity(0.15), radius: 15, x: 0, y: 4)
            .overlay(alignment: .bottomTrailing) {
                CircularButton(icon: "arrow.clockwise",iconColor: .white, action: onRetry)
                    .accessibilityLabel("Replace image")
                    .padding()
            }
            .frame(width: width, height: 400)
            .frame(maxHeight: .infinity)
    }
}

private struct ScannerCameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {
        view.previewLayer.session = session
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
