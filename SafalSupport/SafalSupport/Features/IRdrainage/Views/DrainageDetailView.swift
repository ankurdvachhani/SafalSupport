import SwiftUI
import CoreImage.CIFilterBuiltins

struct DrainageDetailView: View {
    @EnvironmentObject var store: DrainageStore
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var configService = ConfigurationService.shared
    @State private var showingEditView = false
    @State private var showingDeleteAlert = false
    @State private var showingDeleteTimeLimitAlert = false
    @State private var isLoading = false
    @State private var selectedImage: String? = nil
    @State private var errorMessage: String? = nil
    @State private var drainageEntry: DrainageEntry
    @State private var showingCommentSheet = false
    @State private var newCommentText = ""
    @State private var isAddingComment = false
    
    init(entry: DrainageEntry) {
        _drainageEntry = State(initialValue: entry)
    }
    
    private func fetchDrainageDetails() async {
        isLoading = true
        do {
            drainageEntry = try await store.fetchDrainageDetail(id: drainageEntry.id)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                barcodeSection
                if TokenManager.shared.loadCurrentUser()?.role != "Patient"{
                    patientInfoSection
                }
                drainageDetailsSection
                vitalSignsSection
                if drainageEntry.doctorNotified ?? false {
                    doctorNotificationSection
                }
                commentsSection
                imagesSection
            }
            .padding()
        }
        .onAppear {
           
            // Add notification observer
            NotificationCenter.default.addObserver(
                forName: .updateDrainageRecord,
                object: nil,
                queue: .main
            ) { _ in
                Task {
                    await fetchDrainageDetails()
                }
            }
        }
        .navigationTitle("Drainage Entry")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if drainageEntry.userId == TokenManager.shared.getUserId() {
                    menuButton
                }
            }
        }
        .onChange(of: showingEditView) { _, newValue in
            if newValue {
                NavigationManager.shared.navigate(to: .addDrainage(entry: drainageEntry), style: .presentSheet())
                showingEditView = false
            }
        }
        .alert("Delete Entry", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    await deleteEntry()
                }
            }
        } message: {
            Text("Are you sure you want to delete this drainage entry? This action cannot be undone.")
        }
        .alert("Deletion Time Limit", isPresented: $showingDeleteTimeLimitAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            if let timeLimit = configService.drainageDeleteTimeLimit, timeLimit > 0 {
                let timeLimitText = "\(timeLimit) minutes"
                if let remainingTime = getRemainingDeletionTime(drainageEntry) {
                    Text("This drainage entry can only be deleted within \(timeLimitText) of creation. \(remainingTime)")
                } else {
                    Text("This drainage entry can only be deleted within \(timeLimitText) of creation. The deletion time has expired.")
                }
            } else {
                Text("This drainage entry cannot be deleted due to time restrictions.")
            }
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            if let errorMessage = errorMessage {
                Text(errorMessage)
            }
        }
        .sheet(item: $selectedImage) { imageUrl in
            ZoomableImageView(imageUrl: imageUrl)
        }

        .overlay(
            Group {
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.1))
                }
            }
        )
        .task {
            await fetchDrainageDetails()
        }
    }
    
    private var menuButton: some View {
        Menu {
            Button(action: { showingEditView = true }) {
                Label("Edit", systemImage: "pencil")
            }
            
            if canDeleteEntry(drainageEntry) {
                Button(role: .destructive, action: { showingDeleteAlert = true }) {
                    Label("Delete", systemImage: "trash")
                }
            } else {
                Button(action: { showingDeleteTimeLimitAlert = true }) {
                    Label("Delete", systemImage: "trash")
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }
    
    private var patientInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(text: "Patient")
            
            DrainageDetailRow(label: "Patient ID", value: drainageEntry.patientId ?? "")
            
            // Custom patient name row with priority dot
            HStack {
                // Priority color dot (only show if priority exists and is not none)
                if let patientData = drainageEntry.patientData,
                   let priority = patientData.metadata.priority,
                   priority != .none {
                    Circle()
                        .fill(priority.swiftUIColor)
                        .frame(width: 8, height: 8)
                }
                
                Text("Patient Name")
                    .foregroundColor(.secondary)
                Spacer()
                Text(drainageEntry.patientName ?? "")
                    .foregroundColor(.primary)
            }
            .padding(.vertical, 4)
        }
    }
    
    private var drainageDetailsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(text: "Drainage Details")
            
            DrainageDetailRow(label: "Date & Time", value: drainageEntry.recordedAt.formatted())
            DrainageDetailRow(label: "Total Fluid Amount", value: "\(Int(drainageEntry.amount)) \(drainageEntry.amountUnit)")
            
            // Saline Flush Information
            if drainageEntry.isFluidSalineFlush == true {
                DrainageDetailRow(label: "Fluid Saline Flush", value: "Yes")
                if let salineAmount = drainageEntry.fluidSalineFlushAmount, salineAmount > 0 {
                    DrainageDetailRow(label: "Saline Flush Amount", value: "\(Int(salineAmount)) \(drainageEntry.fluidSalineFlushAmountUnit ?? drainageEntry.amountUnit)")
                    
                    // Net Fluid Amount
                    let netAmount = drainageEntry.amount - salineAmount
                    DrainageDetailRow(label: "Net Fluid Amount", value: "\(Int(netAmount)) \(drainageEntry.amountUnit)")
                }
            }
            
            DrainageDetailRow(label: "Location", value: drainageEntry.location)
            DrainageDetailRow(label: "Type of Drainage", value: drainageEntry.drainageType.isEmpty ? "Not specified" : drainageEntry.drainageType)
            DrainageDetailRow(label: "Colour / Appearance", value: drainageEntry.color)
            DrainageDetailRow(label: "Fluid Type", value: drainageEntry.fluidType)
            
            // Consistency (multiple values)
            if !drainageEntry.consistency.isEmpty {
                DrainageDetailRow(label: "Consistency", value: drainageEntry.consistency.joined(separator: ", "))
            }
            
            DrainageDetailRow(label: "Odor", value: drainageEntry.odor.isEmpty ? "Not specified" : drainageEntry.odor)
            
            // Pain Level with visual indicator
            HStack {
                Text("Pain Level")
                    .foregroundColor(.secondary)
                Spacer()
                PainLevelView1(level: drainageEntry.painLevel ?? 0)
            }
            .padding(.vertical, 4)
            
        //    DrainageDetailRow(label: "Temperature", value: String(format: "%.1f°F", drainageEntry.temperature ?? 0))
      //      DrainageDetailRow(label: "Doctor Notified", value: drainageEntry.doctorNotified ?? false ? "Yes" : "No")
            
            if let comments = drainageEntry.comments, !comments.isEmpty {
                CommentsView(comments: comments)
            }
           
        }
    }
    
    private var vitalSignsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(text: "Vital Signs")
            
            // Heart Rate
            if let heartRate = drainageEntry.heartRate {
                DrainageDetailRow(label: "Heart Rate", value: "\(Int(heartRate)) BPM")
            }
            
            // Blood Pressure
            if let bloodPressure = drainageEntry.bloodPressure, !bloodPressure.isEmpty {
                DrainageDetailRow(label: "Blood Pressure", value: bloodPressure)
            }
            
            // Respiratory Rate
            if let respiratoryRate = drainageEntry.respiratoryRate {
                DrainageDetailRow(label: "Respiratory Rate", value: "\(Int(respiratoryRate)) /min")
            }
            
            // Oxygen Saturation
            if let oxygenSaturation = drainageEntry.oxygenSaturation {
                DrainageDetailRow(label: "Oxygen Saturation", value: "\(Int(oxygenSaturation))%")
            }
            
            // Temperature (already in drainage details, but showing here for completeness)
            if let temperature = drainageEntry.temperature {
                DrainageDetailRow(label: "Temperature", value: String(format: "%.1f°F", temperature))
            }
        }
    }
    
    private var doctorNotificationSection: some View {
        HStack {
            Image(systemName: "bell.fill")
                .foregroundColor(.blue)
            Text("Doctor has been notified")
                .foregroundColor(.blue)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionTitle(text: "Comments")
                
                Spacer()
                
                if let commentsArray = drainageEntry.commentsArray, !commentsArray.isEmpty {
                    Text("\(commentsArray.count)")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue)
                        .clipShape(Capsule())
                }
            }
            
            if let commentsArray = drainageEntry.commentsArray, !commentsArray.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(commentsArray) { comment in
                            ModernCommentRowView(comment: comment)
                        }
                    }
                }
                .frame(maxHeight: 200)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "message.circle")
                        .font(.system(size: 50))
                        .foregroundColor(.gray.opacity(0.5))
                    
                    Text("No comments yet")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Be the first to add a comment")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 40)
                .frame(maxWidth: .infinity)
            }
            
            // Comment input bar inside the comments section
            commentInputBar
        }
    }
    
    private var commentInputBar: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: 12) {
                TextField("Add a comment...", text: $newCommentText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(.systemGray6))
                    .cornerRadius(20)
                    .lineLimit(1...4)
                
                Button {
                    Task {
                        await addComment()
                    }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 36))
                        .foregroundColor(newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .blue)
                }
                .disabled(newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isAddingComment)
            }
            .padding(.vertical, 12)
        }
    }
    
    private var barcodeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(text: "Drainage ID Barcode")
            
            if let drainageId = drainageEntry.drainageId, !drainageId.isEmpty {
                VStack(spacing: 12) {
                    BarcodeView(data: drainageId)
                        .frame(height: 80)
                    
                    Text(drainageId)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
            } else {
                Text("No drainage ID available")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
            }
        }
    }
    
    private var imagesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let beforeImageUrls = drainageEntry.beforeImageSign, !beforeImageUrls.isEmpty {
                ImageSectionView(title: "Before Drainage", images: beforeImageUrls, onImageTap: { imageUrl in
                    selectedImage = imageUrl
                })
            }
            
            if let afterImageUrls = drainageEntry.afterImageSign, !afterImageUrls.isEmpty {
                ImageSectionView(title: "After Drainage", images: afterImageUrls, onImageTap: { imageUrl in
                    selectedImage = imageUrl
                })
            }
            
            if let fluidCupImageUrls = drainageEntry.fluidCupImageSign, !fluidCupImageUrls.isEmpty {
                ImageSectionView(title: "Fluid Collection Cup", images: fluidCupImageUrls, onImageTap: { imageUrl in
                    selectedImage = imageUrl
                })
            }
        }
    }
    
    private func deleteEntry() async {
        isLoading = true
        await store.deleteEntry(drainageEntry)
        isLoading = false
        if store.errorMessage == nil {
            presentationMode.wrappedValue.dismiss()
        }
    }
    
    private func addComment() async {
        guard !newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isAddingComment = true
        do {
            try await store.addComment(to: drainageEntry.id, commentText: newCommentText.trimmingCharacters(in: .whitespacesAndNewlines))
            newCommentText = ""
            await fetchDrainageDetails()
        } catch {
            errorMessage = "Failed to add comment: \(error.localizedDescription)"
        }
        isAddingComment = false
    }
    
    /// Check if a drainage entry can be deleted based on the time limit configuration
    private func canDeleteEntry(_ entry: DrainageEntry) -> Bool {
        guard let timeLimitMinutes = configService.drainageDeleteTimeLimit, timeLimitMinutes > 0 else {
            // If no time limit is configured or set to 0, allow deletion
            return true
        }
        
        let currentTime = Date()
        let entryTime = entry.recordedAt
        let timeDifference = currentTime.timeIntervalSince(entryTime)
        let timeLimitSeconds = Double(timeLimitMinutes * 60)
        
        return timeDifference <= timeLimitSeconds
    }
    
    /// Get the remaining time for deletion in a human-readable format
    private func getRemainingDeletionTime(_ entry: DrainageEntry) -> String? {
        guard let timeLimitMinutes = configService.drainageDeleteTimeLimit, timeLimitMinutes > 0 else {
            return nil
        }
        
        let currentTime = Date()
        let entryTime = entry.recordedAt
        let timeDifference = currentTime.timeIntervalSince(entryTime)
        let timeLimitSeconds = Double(timeLimitMinutes * 60)
        let remainingSeconds = timeLimitSeconds - timeDifference
        
        if remainingSeconds <= 0 {
            return "Deletion time expired"
        }
        
        let remainingMinutes = Int(remainingSeconds / 60)
        let remainingSecondsOnly = Int(remainingSeconds.truncatingRemainder(dividingBy: 60))
        
        if remainingMinutes > 0 {
            return "\(remainingMinutes)m \(remainingSecondsOnly)s remaining"
        } else {
            return "\(remainingSecondsOnly)s remaining"
        }
    }
}

// MARK: - Supporting Views
struct SectionTitle: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.headline)
            .foregroundColor(.primary)
            .padding(.top, 8)
    }
}

struct DrainageDetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 4)
    }
}

struct CommentsView: View {
    let comments: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Comments")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text(comments)
                .padding(.top, 2)
        }
        .padding(.vertical, 4)
    }
}

struct ModernCommentRowView: View {
    let comment: DrainageComment
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // User Avatar
            Circle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(String(comment.user?.firstName.prefix(1) ?? "U").uppercased())
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                )
            
            VStack(alignment: .leading, spacing: 6) {
                // User Info Row
                HStack {
                    Text(comment.user?.fullName ?? "Unknown User")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(comment.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Role Badge
                if let role = comment.user?.role, !role.isEmpty {
                    Text(role)
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                }
                
                // Message Bubble
                Text(comment.message)
                    .font(.body)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 4)
    }
}




struct ImageSectionView: View {
    let title: String
    let images: [String]
    let onImageTap: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(images, id: \.self) { imageUrl in
                        AsyncImage(url: URL(string: imageUrl)) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                                    .frame(width: 200, height: 200)
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 200, height: 200)
                                    .clipped()
                                    .cornerRadius(8)
                                    .onTapGesture {
                                        onImageTap(imageUrl)
                                    }
                            case .failure:
                                Image(systemName: "photo")
                                    .font(.largeTitle)
                                    .foregroundColor(.gray)
                                    .frame(width: 200, height: 200)
                            @unknown default:
                                EmptyView()
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(.horizontal)
    }
}

struct ZoomableImageView: View {
    let imageUrl: String
    @Environment(\.presentationMode) var presentationMode
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                AsyncImage(url: URL(string: imageUrl)) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .scaleEffect(scale)
                            .offset(offset)
                            .gesture(
                                SimultaneousGesture(
                                    MagnificationGesture()
                                        .onChanged { value in
                                            let delta = value / lastScale
                                            lastScale = value
                                            scale = min(max(scale * delta, 1), 4)
                                        }
                                        .onEnded { _ in
                                            lastScale = 1.0
                                        },
                                    DragGesture()
                                        .onChanged { value in
                                            offset = CGSize(
                                                width: lastOffset.width + value.translation.width,
                                                height: lastOffset.height + value.translation.height
                                            )
                                        }
                                        .onEnded { _ in
                                            lastOffset = offset
                                        }
                                )
                            )
                            .onTapGesture(count: 2) {
                                withAnimation {
                                    scale = scale > 1 ? 1 : 2
                                    if scale == 1 {
                                        offset = .zero
                                        lastOffset = .zero
                                    }
                                }
                            }
                    case .failure:
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .background(Color.black)
        }
    }
}

// MARK: - Barcode View
struct BarcodeView: View {
    let data: String
    
    var body: some View {
        if let barcodeImage = generateBarcode(from: data) {
            Image(uiImage: barcodeImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity)
        } else {
            Text("Failed to generate barcode")
                .foregroundColor(.secondary)
        }
    }
    
    private func generateBarcode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.code128BarcodeGenerator()
        
        filter.message = Data(string.utf8)
        filter.quietSpace = 7.0
        
        guard let outputImage = filter.outputImage else { return nil }
        
        let transform = CGAffineTransform(scaleX: 3, y: 3)
        let scaledImage = outputImage.transformed(by: transform)
        
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }
        
        return UIImage(cgImage: cgImage)
    }
}
struct PainLevelView1: View {
    let level: Int
    
    private var painColor: Color {
        switch level {
        case 0...2: return .gray
        case 3...5: return .yellow
        case 6...8: return .orange
        default: return .red
        }
    }
    
    private var backgroundColor: Color {
        switch level {
        case 0...2: return .gray.opacity(0.2)
        case 3...5: return .yellow.opacity(0.2)
        case 6...8: return .orange.opacity(0.2)
        default: return .red.opacity(0.2)
        }
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Text("\(level)")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(painColor)
                .frame(width: 20, alignment: .center)
            
            ZStack(alignment: .leading) {
                Capsule()
                    .frame(width: 40, height: 6)
                    .foregroundColor(Color.gray.opacity(0.3))
                
                Capsule()
                    .frame(width: CGFloat(min(level, 10)) * 4, height: 6)
                    .foregroundColor(painColor)
            }
        }
        .frame(maxWidth: 50)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(backgroundColor)
        .cornerRadius(8)
    }
}

#Preview {
    NavigationView {
        DrainageDetailView(entry: DrainageEntry(
            id: "1",
            userId: "1",
            patientId: "PAT-001",
            patientName: "John Doe",
            patientData: nil, // Preview data doesn't include patient data
            amount: 150,
            amountUnit: "ml",
            location: "Right Chest",
            fluidType: "Blood",
            color: "Red",
            comments: "Test comment",
            odorPresent: false,
            painLevel: 3,
            temperature: 37.2,
            doctorNotified: false,
            recordedAt: Date(),
            createdAt: Date(),
            updatedAt: Date(),
            beforeImage: ["https://example.com/image1.jpg"],
            afterImage: ["https://example.com/image2.jpg"],
            fluidCupImage: ["https://example.com/image3.jpg"],
            access: [],
            accessData: []
        ))
        .environmentObject(DrainageStore())
    }
}

#Preview("Zoomable Image") {
    ZoomableImageView(imageUrl: "https://example.com/image.jpg")
}

extension String: Identifiable {
    public var id: String { self }
}
