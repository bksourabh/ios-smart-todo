//
//  SpeechRecognizer.swift
//  smart todo
//
//  Created by Sourabh Mazumder on 4/1/2026.
//

import Foundation
import Speech
import AVFoundation
import Combine

@MainActor
final class SpeechRecognizer: ObservableObject {
    enum RecognizerError: Error, LocalizedError {
        case notAuthorized
        case notAvailable
        case audioSessionError
        case recognitionFailed
        case noSpeechDetected

        var errorDescription: String? {
            switch self {
            case .notAuthorized:
                return "Speech recognition not authorized. Please enable it in Settings."
            case .notAvailable:
                return "Speech recognition is not available on this device."
            case .audioSessionError:
                return "Failed to set up audio session."
            case .recognitionFailed:
                return "Speech recognition failed. Please try again."
            case .noSpeechDetected:
                return "No speech detected. Please try again."
            }
        }
    }

    @Published var transcript: String = ""
    @Published var isRecording: Bool = false
    @Published var error: RecognizerError?

    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))

    var isAvailable: Bool {
        speechRecognizer?.isAvailable ?? false
    }

    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    func checkAuthorizationStatus() -> SFSpeechRecognizerAuthorizationStatus {
        SFSpeechRecognizer.authorizationStatus()
    }

    func startRecording() async throws {
        // Check authorization
        var authStatus = checkAuthorizationStatus()
        if authStatus == .notDetermined {
            let granted = await requestAuthorization()
            if !granted {
                throw RecognizerError.notAuthorized
            }
            authStatus = checkAuthorizationStatus()
        }

        guard authStatus == .authorized else {
            throw RecognizerError.notAuthorized
        }

        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            throw RecognizerError.notAvailable
        }

        // Reset state
        transcript = ""
        error = nil

        // Set up audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            throw RecognizerError.audioSessionError
        }

        // Create and configure recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw RecognizerError.recognitionFailed
        }

        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.addsPunctuation = true

        // Create audio engine
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            throw RecognizerError.audioSessionError
        }

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }

        // Start recognition task
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor in
                guard let self = self else { return }

                if let result = result {
                    self.transcript = result.bestTranscription.formattedString
                }

                if let error = error {
                    // Check if it's a cancellation (user stopped) or actual error
                    let nsError = error as NSError
                    if nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 1110 {
                        // No speech detected - this is not a critical error
                        if self.transcript.isEmpty {
                            self.error = .noSpeechDetected
                        }
                    } else if nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 216 {
                        // Recognition was cancelled - not an error
                    } else {
                        self.error = .recognitionFailed
                    }
                    self.stopRecording()
                } else if result?.isFinal ?? false {
                    self.stopRecording()
                }
            }
        }

        // Start audio engine
        audioEngine.prepare()
        try audioEngine.start()

        isRecording = true
    }

    func stopRecording() {
        // Prevent multiple stops
        guard isRecording else { return }

        isRecording = false

        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()

        audioEngine = nil
        recognitionRequest = nil
        recognitionTask = nil

        // Deactivate audio session
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func reset() {
        stopRecording()
        transcript = ""
        error = nil
    }
}

// MARK: - Voice Command Parser

struct ParsedTaskCommand {
    var title: String?
    var dueDate: Date?
    var notificationType: String? // "time" or "location"
    var notificationMinutes: Int?
    var locationName: String?
    var locationDistance: Int?

    var validationErrors: [String] {
        var errors: [String] = []

        if title == nil || title?.isEmpty == true {
            errors.append("Could not identify task title. Please include what the task is about.")
        }

        if dueDate == nil && notificationType != "location" {
            errors.append("Could not identify due date. Please mention when the task is due (e.g., 'tomorrow at 3pm', 'in 2 hours').")
        }

        if let date = dueDate {
            let fiveMinutesFromNow = Date().addingTimeInterval(5 * 60)
            if date <= fiveMinutesFromNow {
                errors.append("Due date must be at least 5 minutes from now.")
            }
        }

        if notificationType == "location" && (locationName == nil || locationName?.isEmpty == true) {
            errors.append("Location-based notification requires a location name.")
        }

        return errors
    }

    var isValid: Bool {
        validationErrors.isEmpty
    }
}

final class VoiceCommandParser {
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    func parse(_ text: String) -> ParsedTaskCommand {
        var command = ParsedTaskCommand()

        let lowercased = text.lowercased()

        // Detect notification type
        if lowercased.contains("location") || lowercased.contains("near") || lowercased.contains("arrive") || lowercased.contains("when i get to") || lowercased.contains("when i reach") {
            command.notificationType = "location"
            command.locationName = extractLocationName(from: text)
            command.locationDistance = extractDistance(from: lowercased)
        } else {
            command.notificationType = "time"
            command.notificationMinutes = extractNotificationMinutes(from: lowercased)
        }

        // Extract due date
        command.dueDate = extractDueDate(from: lowercased)

        // Extract title (the main task description)
        command.title = extractTitle(from: text)

        return command
    }

    private func extractTitle(from text: String) -> String? {
        var title = text

        // Remove common command prefixes
        let prefixes = [
            "add a task to", "add task to", "add a task", "add task",
            "create a task to", "create task to", "create a task", "create task",
            "remind me to", "remind me", "set a reminder to", "set reminder to",
            "i need to", "i want to", "i have to"
        ]

        for prefix in prefixes {
            if title.lowercased().hasPrefix(prefix) {
                title = String(title.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                break
            }
        }

        // Remove date/time phrases
        let datePatterns = [
            "tomorrow at \\d{1,2}(:\\d{2})?(\\s)?(am|pm)?",
            "today at \\d{1,2}(:\\d{2})?(\\s)?(am|pm)?",
            "at \\d{1,2}(:\\d{2})?(\\s)?(am|pm)?",
            "in \\d+ (hour|hours|minute|minutes|min|mins)",
            "by \\d{1,2}(:\\d{2})?(\\s)?(am|pm)?",
            "due (tomorrow|today|tonight)",
            "tomorrow", "tonight"
        ]

        for pattern in datePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                title = regex.stringByReplacingMatches(in: title, options: [], range: NSRange(title.startIndex..., in: title), withTemplate: "")
            }
        }

        // Remove notification phrases
        let notificationPatterns = [
            "notify me \\d+ (minute|minutes|min|mins) before",
            "remind me \\d+ (minute|minutes|min|mins) before",
            "alert me \\d+ (minute|minutes|min|mins) before",
            "with (a )?notification",
            "notify me when (i |i'm )?near",
            "notify me when (i |i'm )?(at|arrive|reach|get to)",
            "when (i |i'm )?near",
            "when (i |i'm )?(arrive at|reach|get to)",
            "\\d+ (metre|metres|meter|meters|m) (away|from)"
        ]

        for pattern in notificationPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                title = regex.stringByReplacingMatches(in: title, options: [], range: NSRange(title.startIndex..., in: title), withTemplate: "")
            }
        }

        // Remove location notification phrases
        let locationPatterns = [
            "location based notification",
            "location notification",
            "geo notification"
        ]

        for pattern in locationPatterns {
            title = title.replacingOccurrences(of: pattern, with: "", options: .caseInsensitive)
        }

        // Clean up extra spaces and punctuation
        title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        title = title.replacingOccurrences(of: "  ", with: " ")

        // Remove trailing prepositions
        let trailingWords = ["to", "at", "by", "in", "on", "with", "for", "and", "the", "a", "an"]
        for word in trailingWords {
            if title.lowercased().hasSuffix(" \(word)") {
                title = String(title.dropLast(word.count + 1))
            }
        }

        title = title.trimmingCharacters(in: .whitespacesAndNewlines)

        // Capitalize first letter
        if !title.isEmpty {
            title = title.prefix(1).uppercased() + title.dropFirst()
        }

        return title.isEmpty ? nil : title
    }

    private func extractDueDate(from text: String) -> Date? {
        let calendar = Calendar.current
        let now = Date()

        // Check for "in X hours/minutes"
        if let regex = try? NSRegularExpression(pattern: "in (\\d+) (hour|hours)", options: .caseInsensitive),
           let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)),
           let hoursRange = Range(match.range(at: 1), in: text) {
            if let hours = Int(text[hoursRange]) {
                return calendar.date(byAdding: .hour, value: hours, to: now)
            }
        }

        if let regex = try? NSRegularExpression(pattern: "in (\\d+) (minute|minutes|min|mins)", options: .caseInsensitive),
           let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)),
           let minutesRange = Range(match.range(at: 1), in: text) {
            if let minutes = Int(text[minutesRange]) {
                return calendar.date(byAdding: .minute, value: minutes, to: now)
            }
        }

        // Check for "tomorrow at X"
        if text.contains("tomorrow") {
            var targetDate = calendar.date(byAdding: .day, value: 1, to: now)!

            if let time = extractTime(from: text) {
                targetDate = calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: targetDate)!
            } else {
                // Default to 9 AM tomorrow
                targetDate = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: targetDate)!
            }

            return targetDate
        }

        // Check for "today at X" or just "at X"
        if text.contains("today") || text.contains("at ") {
            if let time = extractTime(from: text) {
                var targetDate = calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: now)!

                // If the time is in the past, assume tomorrow
                if targetDate <= now {
                    targetDate = calendar.date(byAdding: .day, value: 1, to: targetDate)!
                }

                return targetDate
            }
        }

        // Check for "tonight"
        if text.contains("tonight") {
            return calendar.date(bySettingHour: 20, minute: 0, second: 0, of: now)
        }

        return nil
    }

    private func extractTime(from text: String) -> (hour: Int, minute: Int)? {
        // Match patterns like "3pm", "3:30pm", "15:30", "3 pm"
        let patterns = [
            "(\\d{1,2}):(\\d{2})\\s*(am|pm)",
            "(\\d{1,2})\\s*(am|pm)",
            "(\\d{1,2}):(\\d{2})"
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)) {

                if let hourRange = Range(match.range(at: 1), in: text) {
                    var hour = Int(text[hourRange]) ?? 0
                    var minute = 0

                    // Check for minutes
                    if match.numberOfRanges > 2, let minuteRange = Range(match.range(at: 2), in: text) {
                        let minuteStr = String(text[minuteRange])
                        if minuteStr != "am" && minuteStr != "pm" {
                            minute = Int(minuteStr) ?? 0
                        }
                    }

                    // Check for AM/PM
                    let matchedText = String(text[Range(match.range, in: text)!]).lowercased()
                    if matchedText.contains("pm") && hour < 12 {
                        hour += 12
                    } else if matchedText.contains("am") && hour == 12 {
                        hour = 0
                    }

                    return (hour, minute)
                }
            }
        }

        return nil
    }

    private func extractNotificationMinutes(from text: String) -> Int? {
        // Match patterns like "notify me 10 minutes before", "remind 5 mins before"
        let patterns = [
            "(\\d+)\\s*(minute|minutes|min|mins)\\s*(before|prior|earlier)",
            "notify.*?(\\d+)\\s*(minute|minutes|min|mins)",
            "remind.*?(\\d+)\\s*(minute|minutes|min|mins)"
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)),
               let minutesRange = Range(match.range(at: 1), in: text) {
                if let minutes = Int(text[minutesRange]) {
                    return min(max(minutes, 1), 60) // Clamp between 1 and 60
                }
            }
        }

        return nil
    }

    private func extractLocationName(from text: String) -> String? {
        // Try to extract location name from phrases like "near home", "when I get to office", "at the gym"
        let patterns = [
            "near\\s+(?:the\\s+)?([\\w\\s]+?)(?:\\s+\\d|$|,|\\.|notify|remind|with)",
            "(?:at|arrive at|reach|get to)\\s+(?:the\\s+)?([\\w\\s]+?)(?:\\s+\\d|$|,|\\.|notify|remind|with)",
            "location\\s+(?:called\\s+|named\\s+)?([\\w\\s]+?)(?:\\s+\\d|$|,|\\.|notify|remind|with)"
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)),
               let locationRange = Range(match.range(at: 1), in: text) {
                let location = String(text[locationRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !location.isEmpty {
                    return location.prefix(1).uppercased() + location.dropFirst()
                }
            }
        }

        return nil
    }

    private func extractDistance(from text: String) -> Int? {
        // Match patterns like "15 metres", "20 meters", "10 m"
        let pattern = "(\\d+)\\s*(metre|metres|meter|meters|m)\\s*(away|from)?"

        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)),
           let distanceRange = Range(match.range(at: 1), in: text) {
            if let distance = Int(text[distanceRange]) {
                return min(max(distance, 1), 50) // Clamp between 1 and 50
            }
        }

        return nil
    }
}
