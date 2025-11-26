//
//  BarcodeScannerView.swift
//  ComicVault
//
//  File created on 10/18/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: Wrapper view for scanning barcodes when available (fallbacks elsewhere).
//
//  Running Edit Log
//  - 10/27/25: Rebuilt for top-tier UX (torch, ROI, zoom, haptics, dedupe).
//  - 11/09/25: Real-device robustness pass (safe session start, ROI timing, debug logging).
//  - 11/09/25: Added UsageStats tracking for scanner_launches.
//
//

import SwiftUI
import AVFoundation
import UIKit

// MARK: - SwiftUI wrapper

/// SwiftUI wrapper around AVCaptureSession that scans common retail barcodes
/// (EAN-13/EAN-8/UPC-E/Code128/Code39/QR). Returns the first value found, then auto-dismisses.
struct BarcodeScannerView: View {
    var onScanned: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var cameraAuth: AVAuthorizationStatus = .notDetermined
    @State private var errorText: String?
    @State private var torchOn = false

    var body: some View {
        ZStack {
            switch cameraAuth {
            case .authorized:
                ScannerRepresentable(
                    torchOn: torchOn,
                    onScanned: { code in
                        Haptics.success()
                        onScanned(code)
                        dismiss()
                    },
                    onError: { err in
                        errorText = err
                    }
                )
                .ignoresSafeArea()

                // Top controls + hint
                VStack {
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Label("Close", systemImage: "xmark.circle.fill")
                                .labelStyle(.iconOnly)
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.95))
                                .padding(8)
                                .background(.black.opacity(0.35), in: Capsule())
                        }

                        Spacer()

                        Button {
                            torchOn.toggle()
                            Haptics.tap(weight: .medium)
                        } label: {
                            Image(systemName: torchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.95))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(.black.opacity(0.35), in: Capsule())
                        }
                        .accessibilityLabel("Toggle Flashlight")
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 18)

                    Spacer()

                    Text("Align the barcode in the frame")
                        .font(.callout.weight(.medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.black.opacity(0.35), in: Capsule())
                        .foregroundStyle(.white.opacity(0.95))
                        .padding(.bottom, 22)
                }

            case .denied, .restricted:
                VStack(spacing: 12) {
                    Image(systemName: "camera.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("Camera Access Needed")
                        .font(.title3).bold()
                    Text("Enable camera in Settings to scan barcodes.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()

            case .notDetermined:
                ProgressView("Requesting Camera Access…")
                    .task {
                        let granted = await AVCaptureDevice.requestAccess(for: .video)
                        cameraAuth = granted ? .authorized : .denied
                    }

            @unknown default:
                Text("Unsupported camera authorization state.")
                    .foregroundStyle(.secondary)
            }

            if let err = errorText {
                VStack {
                    Spacer()
                    Text(err)
                        .font(.footnote)
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                        .padding(.bottom, 20)
                }
                .transition(.opacity)
            }
        }
        .onAppear {
            UsageStats.increment("scanner_launches")
            cameraAuth = AVCaptureDevice.authorizationStatus(for: .video)
        }
        .hideNavBarCompat()
    }
}

// MARK: - Small helper

private extension View {
    @ViewBuilder
    func hideNavBarCompat() -> some View {
        if #available(iOS 16.0, *) {
            self.toolbar(.hidden, for: .navigationBar)
        } else {
            self.navigationBarHidden(true)
        }
    }
}

// MARK: - UIKit bridge

private struct ScannerRepresentable: UIViewControllerRepresentable {
    var torchOn: Bool
    let onScanned: (String) -> Void
    let onError: (String) -> Void

    func makeUIViewController(context: Context) -> ScannerViewController {
        let vc = ScannerViewController()
        vc.onScanned = onScanned
        vc.onError = onError
        return vc
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {
        uiViewController.setTorch(enabled: torchOn)
    }
}

// MARK: - Core Scanner VC

private final class ScannerViewController: UIViewController,
                                           AVCaptureMetadataOutputObjectsDelegate,
                                           UIGestureRecognizerDelegate {

    var onScanned: ((String) -> Void)?
    var onError: ((String) -> Void)?

    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private let metadataOutput = AVCaptureMetadataOutput()

    // Dedupe / throttle
    private var lastScanned: String?
    private var lastScanAt: Date = .distantPast
    private let scanThrottle: TimeInterval = 0.9

    // Zoom
    private var minZoom: CGFloat = 1.0
    private var maxZoom: CGFloat = 4.0

    // Overlay
    private let overlay = ScannerOverlay()

    // Control flags
    private var didConfigureSession = false
    private var didStartSession = false

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureSessionIfNeeded()
        configureGestures()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startSessionIfNeeded()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
        overlay.frame = view.bounds
        updateRectOfInterest()
    }

    deinit {
        if session.isRunning {
            session.stopRunning()
        }
    }

    // MARK: Session

    private func configureSessionIfNeeded() {
        guard !didConfigureSession else { return }
        didConfigureSession = true

        session.beginConfiguration()
        session.sessionPreset = .hd1280x720

        guard let device = AVCaptureDevice.default(for: .video) else {
            onError?("No camera available.")
            session.commitConfiguration()
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
            } else {
                onError?("Cannot access camera input.")
            }
        } catch {
            onError?("Camera error: \(error.localizedDescription)")
            session.commitConfiguration()
            return
        }

        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: .main)
            metadataOutput.metadataObjectTypes = [
                .ean13, .ean8, .upce,
                .code128, .code39,
                .qr
            ]
        } else {
            onError?("Cannot configure barcode scanner.")
        }

        // Preferred focus mode for barcodes.
        if let device = (session.inputs.first as? AVCaptureDeviceInput)?.device {
            do {
                try device.lockForConfiguration()
                if device.isFocusModeSupported(.continuousAutoFocus) {
                    device.focusMode = .continuousAutoFocus
                }
                device.unlockForConfiguration()
            } catch {
                #if DEBUG
                print("[Scanner] Focus configuration failed: \(error)")
                #endif
            }
        }

        // Preview layer
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(layer)
        previewLayer = layer

        // Overlay (guides + mask)
        overlay.isUserInteractionEnabled = false
        view.addSubview(overlay)

        session.commitConfiguration()
    }

    private func startSessionIfNeeded() {
        guard !didStartSession else { return }
        didStartSession = true

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            self.session.startRunning()

            #if DEBUG
            if !self.session.isRunning {
                print("[Scanner] Warning: capture session failed to start.")
            }
            #endif
        }
    }

    // MARK: Torch

    func setTorch(enabled: Bool) {
        guard let device = (session.inputs.first as? AVCaptureDeviceInput)?.device,
              device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            if enabled {
                try device.setTorchModeOn(level: AVCaptureDevice.maxAvailableTorchLevel)
            } else {
                device.torchMode = .off
            }
            device.unlockForConfiguration()
        } catch {
            onError?("Torch unavailable.")
        }
    }

    // MARK: Zoom (pinch)

    private func configureGestures() {
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        pinch.delegate = self
        view.addGestureRecognizer(pinch)
    }

    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        guard let device = (session.inputs.first as? AVCaptureDeviceInput)?.device else { return }
        switch gesture.state {
        case .began:
            minZoom = 1.0
            maxZoom = min(6.0, device.activeFormat.videoMaxZoomFactor)
        case .changed:
            let desired = device.videoZoomFactor * gesture.scale
            let clamped = max(min(desired, maxZoom), minZoom)
            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = clamped
                device.unlockForConfiguration()
            } catch {
                break
            }
            gesture.scale = 1.0
        default:
            break
        }
    }

    // MARK: Region of Interest

    private func updateRectOfInterest() {
        guard let layer = previewLayer,
              layer.bounds.width > 0,
              layer.bounds.height > 0 else { return }

        let cutout = overlay.cutoutRect
        guard cutout.width > 0, cutout.height > 0 else { return }

        let roi = layer.metadataOutputRectConverted(fromLayerRect: cutout)
        metadataOutput.rectOfInterest = roi
    }

    // MARK: Delegate

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {

        guard let first = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = first.stringValue,
              !value.isEmpty else { return }

        // Throttle & de-dupe so we don't fire multiple times for same code quickly
        let now = Date()
        if value == lastScanned, now.timeIntervalSince(lastScanAt) < scanThrottle {
            return
        }
        lastScanned = value
        lastScanAt = now

        session.stopRunning()
        onScanned?(value)
    }
}

// MARK: - Overlay (masked cutout + corner guides)

private final class ScannerOverlay: UIView {

    // Center cutout sized for common barcodes (width-biased) with safe margins
    var cutoutRect: CGRect = .zero

    override func layoutSubviews() {
        super.layoutSubviews()
        let inset: CGFloat = 24
        let w = bounds.width - inset * 2
        let h = min(bounds.height * 0.22, 220)
        let x = inset
        let y = bounds.midY - h / 2
        cutoutRect = CGRect(x: x, y: y, width: w, height: h)
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        // Dim mask
        ctx.setFillColor(UIColor.black.withAlphaComponent(0.45).cgColor)
        ctx.fill(bounds)

        // Clear cutout
        let path = UIBezierPath(roundedRect: cutoutRect, cornerRadius: 12)
        ctx.setBlendMode(.clear)
        UIColor.clear.setFill()
        path.fill()
        ctx.setBlendMode(.normal)

        // Corner guides
        let guide: CGFloat = 18
        let lineW: CGFloat = 3
        let c = UIColor.white.withAlphaComponent(0.95)

        ctx.setStrokeColor(c.cgColor)
        ctx.setLineWidth(lineW)

        // TL
        drawCorner(ctx, at: cutoutRect.origin, dx: guide, dy: guide)
        // TR
        drawCorner(ctx,
                   at: CGPoint(x: cutoutRect.maxX, y: cutoutRect.minY),
                   dx: -guide, dy: guide)
        // BL
        drawCorner(ctx,
                   at: CGPoint(x: cutoutRect.minX, y: cutoutRect.maxY),
                   dx: guide, dy: -guide)
        // BR
        drawCorner(ctx,
                   at: CGPoint(x: cutoutRect.maxX, y: cutoutRect.maxY),
                   dx: -guide, dy: -guide)
    }

    private func drawCorner(_ ctx: CGContext, at p: CGPoint, dx: CGFloat, dy: CGFloat) {
        // horizontal
        ctx.beginPath()
        ctx.move(to: p)
        ctx.addLine(to: CGPoint(x: p.x + dx, y: p.y))
        ctx.strokePath()
        // vertical
        ctx.beginPath()
        ctx.move(to: p)
        ctx.addLine(to: CGPoint(x: p.x, y: p.y + dy))
        ctx.strokePath()
    }
}
