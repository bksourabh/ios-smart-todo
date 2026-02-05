//
//  VoiceInputTaskView.swift
//  smart todo
//
//  Created by Sourabh Mazumder on 4/1/2026.
//

import SwiftUI
import CoreData

struct VoiceInputTaskView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var notificationManager: NotificationManager
    @ObservedObject private var locationManager = LocationManager.shared

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \PointOfInterest.name, ascending: true)],
        animation: .default)
    private var pointsOfInterest: FetchedResults<PointOfInterest>

    @StateObject private var speechRecognizer = SpeechRecognizer()
    private let voiceParser = VoiceCommandParser()

    private var isLocationNotificationsEnabled: Bool {
        return locationManager.isLocationBasedNotificationsAvailable
    }

    @State private var parsedCommand: ParsedTaskCommand?
    @State private var showingPreview = false
    @State private var errorMessage: String?
    @State private var isProcessing = false

    // Editable fields for preview
    @State private var editedTitle: String = ""
    @State private var editedDueDate: Date = Date().addingTimeInterval(6 * 60)
    @State private var editedNotificationType: String = "time"
    @State private var editedNotificationMinutes: Int = 5
    @State private var editedLocationDistance: Int = 15
    @State private var selectedPOI: PointOfInterest?

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if showingPreview {
                    previewContent
                } else {
                    recordingContent
                }
            }
            .navigationTitle("Voice Input")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        if speechRecognizer.isRecording {
                            speechRecognizer.stopRecording()
                        }
                        dismiss()
                    }
                }

                if showingPreview {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") {
                            saveTask()
                        }
                        .disabled(editedTitle.isEmpty)
                    }
                }
            }
        }
    }

    // MARK: - Recording Content

    private var recordingContent: some View {
        VStack(spacing: 32) {
            Spacer()

            // Microphone animation
            ZStack {
                // Outer pulsing circle
                Circle()
                    .fill(Color.red.opacity(0.1))
                    .frame(width: 180, height: 180)
                    .scaleEffect(speechRecognizer.isRecording ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: speechRecognizer.isRecording)

                // Middle circle
                Circle()
                    .fill(Color.red.opacity(0.2))
                    .frame(width: 140, height: 140)
                    .scaleEffect(speechRecognizer.isRecording ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true).delay(0.1), value: speechRecognizer.isRecording)

                // Main button
                Button(action: toggleRecording) {
                    ZStack {
                        Circle()
                            .fill(speechRecognizer.isRecording ? Color.red : Color.blue)
                            .frame(width: 100, height: 100)
                            .shadow(color: (speechRecognizer.isRecording ? Color.red : Color.blue).opacity(0.4), radius: 10, x: 0, y: 5)

                        Image(systemName: speechRecognizer.isRecording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                    }
                }
            }

            // Status text
            VStack(spacing: 8) {
                Text(speechRecognizer.isRecording ? "Listening..." : "Tap to start speaking")
                    .font(.headline)
                    .foregroundColor(speechRecognizer.isRecording ? .red : .primary)

                Text(speechRecognizer.isRecording ? "Speak your task details" : "Add a task using your voice")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // Live transcript
            if !speechRecognizer.transcript.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "text.quote")
                            .foregroundColor(.blue)
                        Text("What I heard:")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }

                    Text(speechRecognizer.transcript)
                        .font(.body)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(12)
                }
                .padding(.horizontal, 24)
            }

            // Error message
            if let error = errorMessage ?? speechRecognizer.error?.localizedDescription {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.orange)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(10)
                .padding(.horizontal, 24)
            }

            // Example phrases
            if !speechRecognizer.isRecording && speechRecognizer.transcript.isEmpty && errorMessage == nil && speechRecognizer.error == nil {
                examplePhrases
            }

            Spacer()

            // Process button (when transcript is available)
            if !speechRecognizer.transcript.isEmpty && !speechRecognizer.isRecording {
                Button(action: processTranscript) {
                    HStack {
                        if isProcessing {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "sparkles")
                        }
                        Text(isProcessing ? "Processing..." : "Process Task")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.blue)
                    .cornerRadius(14)
                }
                .disabled(isProcessing)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }

            // Try again button (when there's an error and no transcript)
            if speechRecognizer.transcript.isEmpty && !speechRecognizer.isRecording && (errorMessage != nil || speechRecognizer.error != nil) {
                Button(action: {
                    errorMessage = nil
                    speechRecognizer.reset()
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Try Again")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.blue)
                    .cornerRadius(14)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
    }

    // MARK: - Preview Content

    private var previewContent: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Task parsed successfully!")
                            .font(.headline)
                    }

                    Text("Review and edit the details below before saving.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }

            Section(header: Text("Task Details")) {
                TextField("Task Title", text: $editedTitle)
            }

            Section(header: Text("Notification Type")) {
                if isLocationNotificationsEnabled {
                    Picker("Type", selection: $editedNotificationType) {
                        Text("Time-based").tag("time")
                        Text("Location-based").tag("location")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Time-based")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                        .padding(.vertical, 4)

                        HStack(spacing: 8) {
                            Image(systemName: "location.slash.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                            Text("Location-based notifications require \"Always Allow\" location permission.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 4)
                    }
                }
            }

            if editedNotificationType == "time" || !isLocationNotificationsEnabled {
                Section(header: Text("Due Date")) {
                    DatePicker("Due Date", selection: $editedDueDate, in: Date().addingTimeInterval(5 * 60 + 1)..., displayedComponents: [.date, .hourAndMinute])
                }

                Section(header: Text("Notification")) {
                    Picker("Notify Before", selection: $editedNotificationMinutes) {
                        Text("No notification").tag(0)
                        ForEach(1...60, id: \.self) { minutes in
                            Text("\(minutes) minute\(minutes == 1 ? "" : "s")").tag(minutes)
                        }
                    }
                }
            } else if isLocationNotificationsEnabled {
                Section(header: Text("Location Settings")) {
                    Picker("Distance", selection: $editedLocationDistance) {
                        ForEach(1...50, id: \.self) { distance in
                            Text("\(distance) metre\(distance == 1 ? "" : "s")").tag(distance)
                        }
                    }

                    if pointsOfInterest.isEmpty {
                        Text("No points of interest available")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Picker("Location", selection: $selectedPOI) {
                            Text("Select a location").tag(nil as PointOfInterest?)
                            ForEach(pointsOfInterest) { poi in
                                Text(poi.name ?? "Unnamed").tag(poi as PointOfInterest?)
                            }
                        }
                    }
                }
            }

            Section {
                Button(action: {
                    showingPreview = false
                    parsedCommand = nil
                    errorMessage = nil
                }) {
                    HStack {
                        Image(systemName: "mic.fill")
                        Text("Record Again")
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    // MARK: - Example Phrases

    private var examplePhrases: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Try saying:")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            VStack(spacing: 12) {
                examplePhrase(
                    icon: "clock",
                    color: .orange,
                    text: "\"Remind me to buy groceries tomorrow at 5pm\""
                )

                examplePhrase(
                    icon: "location.fill",
                    color: .purple,
                    text: "\"Add task to pick up dry cleaning when I'm near the mall\""
                )

                examplePhrase(
                    icon: "bell.fill",
                    color: .blue,
                    text: "\"Create task to call mom at 3pm, notify me 10 minutes before\""
                )
            }
        }
        .padding(.horizontal, 24)
    }

    private func examplePhrase(icon: String, color: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)

            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
                .italic()

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
    }

    // MARK: - Actions

    private func toggleRecording() {
        if speechRecognizer.isRecording {
            speechRecognizer.stopRecording()
        } else {
            errorMessage = nil
            speechRecognizer.reset()
            Task {
                do {
                    try await speechRecognizer.startRecording()
                } catch let error as SpeechRecognizer.RecognizerError {
                    await MainActor.run {
                        errorMessage = error.localizedDescription
                    }
                } catch {
                    await MainActor.run {
                        errorMessage = "Failed to start recording: \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    private func processTranscript() {
        isProcessing = true
        errorMessage = nil

        // Parse the transcript
        let command = voiceParser.parse(speechRecognizer.transcript)

        // Check for validation errors
        if !command.validationErrors.isEmpty && command.title == nil {
            errorMessage = command.validationErrors.first
            isProcessing = false
            return
        }

        // Populate editable fields
        editedTitle = command.title ?? ""
        // Only use location type if it's available
        let detectedType = command.notificationType ?? "time"
        editedNotificationType = (detectedType == "location" && !isLocationNotificationsEnabled) ? "time" : detectedType

        if let dueDate = command.dueDate {
            editedDueDate = dueDate
        } else {
            editedDueDate = Date().addingTimeInterval(60 * 60) // Default 1 hour from now
        }

        editedNotificationMinutes = command.notificationMinutes ?? 5
        editedLocationDistance = command.locationDistance ?? 15

        // Try to match location name with POI
        if let locationName = command.locationName {
            selectedPOI = pointsOfInterest.first { poi in
                (poi.name ?? "").lowercased().contains(locationName.lowercased())
            }
        }

        parsedCommand = command
        showingPreview = true
        isProcessing = false
    }

    private func saveTask() {
        // Validate
        guard !editedTitle.isEmpty else { return }

        // Force time-based if location notifications are not available
        let effectiveNotificationType = isLocationNotificationsEnabled ? editedNotificationType : "time"

        if effectiveNotificationType == "location" && selectedPOI == nil && !pointsOfInterest.isEmpty {
            errorMessage = "Please select a location for location-based notification"
            return
        }

        // Create task
        let newTask = TodoTask(context: viewContext)
        newTask.id = UUID()
        newTask.createdAt = Date()
        newTask.isCompleted = false
        newTask.title = editedTitle
        newTask.notificationType = effectiveNotificationType

        if effectiveNotificationType == "time" {
            newTask.dateType = "dueDate"
            newTask.dueDate = editedDueDate
            newTask.notificationMinutes = Int16(editedNotificationMinutes)
            newTask.locationNotificationDistance = 0
            newTask.notificationLocation = nil
        } else if effectiveNotificationType == "location" {
            newTask.dateType = "location"
            newTask.dueDate = nil
            newTask.notificationMinutes = 0
            newTask.locationNotificationDistance = Int16(editedLocationDistance)
            newTask.notificationLocation = selectedPOI
        }

        do {
            try viewContext.save()
            notificationManager.scheduleNotification(for: newTask)
            dismiss()
        } catch {
            errorMessage = "Failed to save task: \(error.localizedDescription)"
        }
    }
}

// MARK: - Voice Input Button (for ContentView)

struct VoiceInputButton: View {
    @Binding var showingVoiceInput: Bool

    var body: some View {
        Button(action: {
            showingVoiceInput = true
        }) {
            ZStack {
                Circle()
                    .fill(Color.red)
                    .frame(width: 56, height: 56)
                    .shadow(color: Color.red.opacity(0.4), radius: 8, x: 0, y: 4)

                Image(systemName: "mic.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
            }
        }
    }
}
