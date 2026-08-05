import SwiftUI
import AVFoundation

/// Live camera view that reports the first QR code it recognises.
///
/// Uses `AVCaptureMetadataOutput` rather than VisionKit's `DataScannerViewController`
/// so it works on every device that can run the app, not just A12-and-later.
struct QRScannerView: UIViewControllerRepresentable {
    /// Called once per distinct code. The parent decides whether it's valid.
    var onScan: (String) -> Void
    var onError: (String) -> Void

    func makeUIViewController(context: Context) -> ScannerViewController {
        let controller = ScannerViewController()
        controller.onScan = onScan
        controller.onError = onError
        return controller
    }

    func updateUIViewController(_ controller: ScannerViewController, context: Context) {
        controller.onScan = onScan
        controller.onError = onError
    }
}

/// The camera session behind ``QRScannerView``.
final class ScannerViewController: UIViewController {

    var onScan: ((String) -> Void)?
    var onError: ((String) -> Void)?

    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    /// Codes already reported, so holding the camera steady doesn't fire repeatedly.
    private var seen = Set<String>()
    private let sessionQueue = DispatchQueue(label: "com.ladulghanneey.RelayAir.camera")

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureSession()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startIfNeeded()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        // Never hold the camera open behind the user's back.
        sessionQueue.async { [session] in
            if session.isRunning { session.stopRunning() }
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    // MARK: - Session

    private func configureSession() {
        session.beginConfiguration()

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input)
        else {
            session.commitConfiguration()
            onError?("This device has no usable camera.")
            return
        }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else {
            session.commitConfiguration()
            onError?("Couldn't start the QR scanner.")
            return
        }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        // Must be set after the output is attached to the session.
        output.metadataObjectTypes = [.qr]

        session.commitConfiguration()

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.bounds
        view.layer.addSublayer(preview)
        previewLayer = preview
    }

    private func startIfNeeded() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            start()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self else { return }
                    granted ? self.start() : self.onError?("Camera access is needed to scan the pairing code.")
                }
            }
        case .denied, .restricted:
            onError?("Camera access is off. Turn it on in Settings ▸ Relay Air.")
        @unknown default:
            onError?("Camera access is unavailable.")
        }
    }

    private func start() {
        // `startRunning` blocks, so it never belongs on the main thread.
        sessionQueue.async { [session] in
            guard !session.isRunning else { return }
            session.startRunning()
        }
    }
}

extension ScannerViewController: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        for object in metadataObjects {
            guard let readable = object as? AVMetadataMachineReadableCodeObject,
                  readable.type == .qr,
                  let value = readable.stringValue,
                  seen.insert(value).inserted
            else { continue }

            UINotificationFeedbackGenerator().notificationOccurred(.success)
            onScan?(value)
        }
    }
}
