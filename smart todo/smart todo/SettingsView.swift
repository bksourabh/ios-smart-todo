//
//  SettingsView.swift
//  smart todo
//
//  Created by Sourabh Mazumder on 4/1/2026.
//

import SwiftUI
import CoreLocation

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var notificationManager: NotificationManager
    @ObservedObject private var locationManager = LocationManager.shared

    var body: some View {
        List {
            // Notification Status Section
            Section {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(statusColor.opacity(0.15))
                            .frame(width: 44, height: 44)
                        Image(systemName: statusIcon)
                            .font(.system(size: 18))
                            .foregroundColor(statusColor)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Push Notifications")
                            .font(.headline)
                        Text(statusText)
                            .font(.subheadline)
                            .foregroundColor(statusColor)
                    }

                    Spacer()

                    if notificationManager.authorizationStatus == .authorized {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 22))
                    }
                }
                .padding(.vertical, 4)

                if notificationManager.authorizationStatus != .authorized {
                    if notificationManager.authorizationStatus == .notDetermined {
                        Button(action: {
                            Task {
                                _ = await notificationManager.requestAuthorization()
                            }
                        }) {
                            HStack {
                                Image(systemName: "bell.badge")
                                Text("Enable Notifications")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    if notificationManager.authorizationStatus == .denied {
                        Button(action: {
                            notificationManager.openSettings()
                        }) {
                            HStack {
                                Image(systemName: "gear")
                                Text("Open Settings to Enable")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            } header: {
                Text("Notifications")
            } footer: {
                Text("Receive reminders when tasks are due or when you're near a saved location.")
            }

            // Location Status Section
            Section {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(locationStatusColor.opacity(0.15))
                            .frame(width: 44, height: 44)
                        Image(systemName: "location.fill")
                            .font(.system(size: 18))
                            .foregroundColor(locationStatusColor)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Location Access")
                            .font(.headline)
                        Text(locationStatusText)
                            .font(.subheadline)
                            .foregroundColor(locationStatusColor)
                    }

                    Spacer()

                    if locationManager.authorizationStatus == .authorizedAlways {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 22))
                    }
                }
                .padding(.vertical, 4)

                if locationManager.authorizationStatus != .authorizedAlways {
                    Button(action: {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        HStack {
                            Image(systemName: "gear")
                            Text("Open Settings")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.bordered)
                }
            } header: {
                Text("Location")
            } footer: {
                Text("\"Always Allow\" is required for location-based task reminders to work in the background.")
            }

            // Notification Types Section
            Section {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(0.15))
                            .frame(width: 40, height: 40)
                        Image(systemName: "clock.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.orange)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Time-Based")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("Reminders at specific times")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemName: "checkmark")
                        .foregroundColor(.green)
                        .font(.system(size: 14, weight: .semibold))
                }

                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.purple.opacity(0.15))
                            .frame(width: 40, height: 40)
                        Image(systemName: "location.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.purple)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Location-Based")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("Reminders when near places")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if locationManager.isLocationBasedNotificationsAvailable {
                        Image(systemName: "checkmark")
                            .foregroundColor(.green)
                            .font(.system(size: 14, weight: .semibold))
                    } else {
                        Text("Needs Setup")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            } header: {
                Text("Reminder Types")
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            notificationManager.checkAuthorizationStatus()
            locationManager.checkAuthorizationStatus()
        }
    }

    // MARK: - Notification Status Helpers

    private var statusText: String {
        switch notificationManager.authorizationStatus {
        case .authorized:
            return "Enabled"
        case .denied:
            return "Disabled in Settings"
        case .notDetermined:
            return "Not Set Up"
        case .provisional:
            return "Provisional"
        case .ephemeral:
            return "Ephemeral"
        @unknown default:
            return "Unknown"
        }
    }

    private var statusIcon: String {
        switch notificationManager.authorizationStatus {
        case .authorized:
            return "bell.badge.fill"
        case .denied:
            return "bell.slash.fill"
        default:
            return "bell.fill"
        }
    }

    private var statusColor: Color {
        switch notificationManager.authorizationStatus {
        case .authorized:
            return .green
        case .denied:
            return .red
        default:
            return .orange
        }
    }

    // MARK: - Location Status Helpers

    private var locationStatusText: String {
        switch locationManager.authorizationStatus {
        case .authorizedAlways:
            return "Always Allowed"
        case .authorizedWhenInUse:
            return "While Using App"
        case .denied, .restricted:
            return "Disabled"
        case .notDetermined:
            return "Not Set Up"
        @unknown default:
            return "Unknown"
        }
    }

    private var locationStatusColor: Color {
        switch locationManager.authorizationStatus {
        case .authorizedAlways:
            return .green
        case .authorizedWhenInUse:
            return .orange
        case .denied, .restricted:
            return .red
        default:
            return .orange
        }
    }
}



