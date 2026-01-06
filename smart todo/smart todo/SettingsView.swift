//
//  SettingsView.swift
//  smart todo
//
//  Created by Sourabh Mazumder on 4/1/2026.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var notificationManager: NotificationManager
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Notifications")) {
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(statusText)
                            .foregroundColor(statusColor)
                    }
                    
                    Text("Get notified when tasks are due today")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if notificationManager.authorizationStatus != .authorized {
                        Button(action: {
                            Task {
                                _ = await notificationManager.requestAuthorization()
                            }
                        }) {
                            Text("Enable Notifications")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    
                    if notificationManager.authorizationStatus == .denied {
                        Button(action: {
                            notificationManager.openSettings()
                        }) {
                            Text("Open Settings")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                
                Section(header: Text("About")) {
                    HStack {
                        Text("Notifications are sent for tasks due on the current day. You can manage notification permissions in iOS Settings.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                notificationManager.checkAuthorizationStatus()
            }
        }
    }
    
    private var statusText: String {
        switch notificationManager.authorizationStatus {
        case .authorized:
            return "Enabled"
        case .denied:
            return "Disabled"
        case .notDetermined:
            return "Not Set"
        case .provisional:
            return "Provisional"
        case .ephemeral:
            return "Ephemeral"
        @unknown default:
            return "Unknown"
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
}

