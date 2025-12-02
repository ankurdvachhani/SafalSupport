import SwiftUI
import AVFoundation
import UIKit

// MARK: - Record Type Enum
enum RecordType: String, CaseIterable {
    case drainage = "DG"
    case incident = "IC"
    case report = "R"
    
    var displayName: String {
        switch self {
        case .drainage: return "Drainage"
        case .incident: return "Incident"
        case .report: return "Report"
        }
    }
    
    var icon: String {
        switch self {
        case .drainage: return "drop.fill"
        case .incident: return "note.text.badge.plus"
        case .report: return "doc.text"
        }
    }
}

struct BarcodeScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var scannerViewModel = BarcodeScannerViewModel()
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isScanning = true
    @State private var detectedRecordType: RecordType?
    @State private var showingRecordFoundAlert = false
    
    var body: some View {
        ZStack {
            // Camera preview
            CameraPreviewView(session: scannerViewModel.session)
                .ignoresSafeArea()
            
            // Overlay UI
            VStack {
                // Top bar
                topBar
                
                Spacer()
                
                // Scanning area indicator
                scanningArea
                
                Spacer()
                
                // Bottom instructions
                bottomInstructions
            }
        }
        .onAppear {
            scannerViewModel.requestCameraPermission()
        }
        .onReceive(scannerViewModel.$scannedCode) { code in
            if let code = code {
                handleScannedCode(code)
            }
        }
        .onReceive(scannerViewModel.$errorMessage) { error in
            if let error = error {
                alertMessage = error
                showingAlert = true
            }
        }
        .alert("Scanner Error", isPresented: $showingAlert) {
            Button("OK") {
                scannerViewModel.errorMessage = nil
            }
        } message: {
            Text(alertMessage)
        }
        .alert("Record Found", isPresented: $showingRecordFoundAlert) {
            Button("View Details") {
                if let code = scannerViewModel.scannedCode, let recordType = detectedRecordType {
                    navigateToRecordDetail(code: code, recordType: recordType)
                }
            }
            Button("Scan Again", role: .cancel) {
                scannerViewModel.resetScanner()
                detectedRecordType = nil
            }
        } message: {
            if let recordType = detectedRecordType {
                Text("\(recordType.displayName) record found. Would you like to view the details?")
            } else {
                Text("Record found. Would you like to view the details?")
            }
        }
    }
    
    private var topBar: some View {
        HStack {
            Button(action: {
                dismiss()
            }) {
                Image(systemName: "xmark")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
            }
            
            Spacer()
            
            Text("Scan Barcode")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            Spacer()
            
            Button(action: {
                scannerViewModel.toggleTorch()
            }) {
                Image(systemName: scannerViewModel.isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }
    
    private var scanningArea: some View {
        VStack(spacing: 20) {
            // Scanning frame
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white, lineWidth: 3)
                    .frame(width: 280, height: 180)
                    .background(Color.clear)
                
                // Scanning line animation
                if isScanning {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color.clear, Color.dynamicAccent, Color.clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 2)
                        .frame(width: 260)
                        .offset(y: -90)
                        .animation(
                            Animation.easeInOut(duration: 2)
                                .repeatForever(autoreverses: true),
                            value: isScanning
                        )
                }
            }
            
            // Status text
            Text(scannerViewModel.statusMessage)
                .font(.headline)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
    
    private var bottomInstructions: some View {
        VStack(spacing: 16) {
            Text("Position the barcode within the frame")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
            
            Text("Supported formats: DG-*, IC-*, R-*")
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(.bottom, 40)
    }
    
    private func handleScannedCode(_ code: String) {
        // Detect record type based on prefix
        if let recordType = detectRecordType(from: code) {
            detectedRecordType = recordType
            scannerViewModel.statusMessage = "\(recordType.displayName) detected: \(code)"
            showingRecordFoundAlert = true
        } else {
            scannerViewModel.statusMessage = "Invalid barcode format"
            alertMessage = "Invalid barcode format. Expected DG-*, IC-*, or R-*"
            showingAlert = true
        }
    }
    
    private func detectRecordType(from code: String) -> RecordType? {
        // Check if the code starts with any of our record type prefixes
        for recordType in RecordType.allCases {
            if code.uppercased().hasPrefix(recordType.rawValue) {
                return recordType
            }
        }
        return nil
    }
    
    private func navigateToRecordDetail(code: String, recordType: RecordType) {
        Task {
            do {
                switch recordType {
                case .drainage:
                    await navigateToDrainageDetail(drainageId: code)
                case .incident:
                    await navigateToIncidentDetail(incidentId: code)
                case .report:
                    await navigateToReportDetail(reportId: code)
                }
            } catch {
                await MainActor.run {
                    alertMessage = "Failed to fetch \(recordType.displayName.lowercased()) details: \(error.localizedDescription)"
                    showingAlert = true
                }
            }
        }
    }
    
    private func navigateToDrainageDetail(drainageId: String) async {
        do {
            // Fetch the actual drainage details from the API
            let drainageStore = DrainageStore()
            let drainageEntry = try await drainageStore.fetchDrainageDetail(id: drainageId)
            
            // Navigate to drainage detail with the fetched data
            await MainActor.run {
                NavigationManager.shared.navigate(
                    to: .drainageDetail(entry: drainageEntry),
                    style: .push(withAccentColor: Color.dynamicAccent)
                )
                
                // Dismiss the scanner
                dismiss()
            }
        } catch {
            await MainActor.run {
                alertMessage = "Drainage record not found or error occurred: \(error.localizedDescription)"
                showingAlert = true
            }
        }
    }
    
    private func navigateToIncidentDetail(incidentId: String) async {
        do {
            // Fetch the actual incident details from the API
            let incidentStore = IncidentStore()
            let incident = try await incidentStore.fetchIncidentDetail(id: incidentId)
            
            // Navigate to incident detail with the fetched data
            await MainActor.run {
                NavigationManager.shared.navigate(
                    to: .incidentDetail(incident: incident),
                    style: .push(withAccentColor: Color.dynamicAccent)
                )
                
                // Dismiss the scanner
                dismiss()
            }
        } catch {
            await MainActor.run {
                alertMessage = "Incident record not found or error occurred: \(error.localizedDescription)"
                showingAlert = true
            }
        }
    }
    
    private func navigateToReportDetail(reportId: String) async {
        do {
            // Fetch the report details first
            let reportStore = IncidentReportStore()
            let report = try await reportStore.fetchReportDetail(id: reportId)
            let reportUrl = try await reportStore.downloadReport(reportId: reportId)
            
            // Navigate to report view with the PDF URL
            await MainActor.run {
                // Navigate to report list and show the PDF
                NavigationManager.shared.navigate(
                    to: .incidentReportList,
                    style: .push(withAccentColor: Color.dynamicAccent)
                )
                
                // Post notification to show the PDF for this specific report
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    NotificationCenter.default.post(
                        name: .ShowReportPDFNotification,
                        object: ["report": report, "url": reportUrl]
                    )
                }
                
                // Dismiss the scanner
                dismiss()
            }
        } catch {
            await MainActor.run {
                alertMessage = "Report not found or error occurred: \(error.localizedDescription)"
                showingAlert = true
            }
        }
    }
}

// MARK: - Notification Extension
extension Notification.Name {
    static let ShowReportPDFNotification = Notification.Name("ShowReportPDF")
}

// MARK: - Camera Preview View
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
        
        // Ensure the preview layer is properly configured
        DispatchQueue.main.async {
            previewLayer.frame = view.bounds
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let previewLayer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            DispatchQueue.main.async {
                previewLayer.frame = uiView.bounds
            }
        }
    }
}

// MARK: - Barcode Scanner ViewModel
@MainActor
class BarcodeScannerViewModel: NSObject, ObservableObject {
    @Published var scannedCode: String?
    @Published var errorMessage: String?
    @Published var showingSuccessAlert = false
    @Published var isTorchOn = false
    @Published var statusMessage = "Ready to scan"
    
    let session = AVCaptureSession()
    private var videoOutput = AVCaptureVideoDataOutput()
    private var metadataOutput = AVCaptureMetadataOutput()
    private var captureDevice: AVCaptureDevice?
    
    override init() {
        super.init()
        setupSession()
    }
    
    private func setupSession() {
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            errorMessage = "Camera not available"
            return
        }
        
        captureDevice = videoCaptureDevice
        
        do {
            let videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
            
            if session.canAddInput(videoInput) {
                session.addInput(videoInput)
            } else {
                errorMessage = "Unable to add video input"
                return
            }
            
            if session.canAddOutput(metadataOutput) {
                session.addOutput(metadataOutput)
                metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
                metadataOutput.metadataObjectTypes = [.code128]
            } else {
                errorMessage = "Unable to add metadata output"
                return
            }
            
            // Configure session for high quality
            session.sessionPreset = .high
            
        } catch {
            errorMessage = "Error setting up camera: \(error.localizedDescription)"
        }
    }
    
    func requestCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            startSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    DispatchQueue.main.async {
                        self?.startSession()
                    }
                } else {
                    DispatchQueue.main.async {
                        self?.errorMessage = "Camera access denied"
                    }
                }
            }
        case .denied, .restricted:
            errorMessage = "Camera access denied"
        @unknown default:
            errorMessage = "Unknown camera authorization status"
        }
    }
    
    func startSession() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            if !self.session.isRunning {
                self.session.startRunning()
                DispatchQueue.main.async {
                    self.statusMessage = "Camera ready"
                }
            }
        }
    }
    
    func stopSession() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.stopRunning()
        }
    }
    
    func toggleTorch() {
        guard let device = captureDevice else { return }
        
        do {
            try device.lockForConfiguration()
            
            if device.hasTorch {
                if device.torchMode == .on {
                    device.torchMode = .off
                    isTorchOn = false
                } else {
                    try device.setTorchModeOn(level: 1.0)
                    isTorchOn = true
                }
            }
            
            device.unlockForConfiguration()
        } catch {
            errorMessage = "Unable to toggle torch: \(error.localizedDescription)"
        }
    }
    
    func resetScanner() {
        scannedCode = nil
        showingSuccessAlert = false
        statusMessage = "Ready to scan"
    }
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate
extension BarcodeScannerViewModel: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
           let stringValue = metadataObject.stringValue {
            scannedCode = stringValue
            statusMessage = "Code detected: \(stringValue)"
        }
    }
}

#Preview {
    BarcodeScannerView()
} 


