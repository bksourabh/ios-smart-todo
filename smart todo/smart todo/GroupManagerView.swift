//
//  GroupManagerView.swift
//  smart todo
//
//  Created by Sourabh Mazumder on 4/1/2026.
//

import SwiftUI
import CoreData
import CoreLocation
import UIKit

struct GroupManagerView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Group.createdAt, ascending: true)],
        animation: .default)
    private var groups: FetchedResults<Group>
    
    @State private var showingAddGroup = false
    @State private var editingGroup: Group?
    
    var body: some View {
        NavigationView {
            List {
                if groups.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "folder")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("No groups yet")
                            .font(.title3)
                            .foregroundColor(.gray)
                        Text("Tap the + button to create your first group")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    ForEach(groups) { group in
                        HStack {
                            Image(systemName: "folder.fill")
                                .foregroundColor(.blue)
                            Text(group.name ?? "Unnamed Group")
                                .font(.body)
                            Spacer()
                            if let taskCount = group.tasks?.count, taskCount > 0 {
                                Text("\(taskCount)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.secondary.opacity(0.2))
                                    .cornerRadius(8)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            editingGroup = group
                            showingAddGroup = true
                        }
                    }
                    .onDelete(perform: deleteGroups)
                }
            }
            .navigationTitle("Groups")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        editingGroup = nil
                        showingAddGroup = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddGroup) {
                AddEditGroupView(group: editingGroup)
            }
        }
    }
    
    private func deleteGroups(offsets: IndexSet) {
        withAnimation {
            offsets.map { groups[$0] }.forEach(viewContext.delete)
            
            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

struct AddEditGroupView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    var group: Group?
    
    @StateObject private var locationManager = LocationManager.shared
    
    @State private var name: String = ""
    @State private var notifyWhenAwayFromLocation: Bool = false
    @State private var locationNotificationDistance: Int = 15
    @State private var latitude: Double = 0.0
    @State private var longitude: Double = 0.0
    @State private var isFetchingLocation: Bool = false
    @State private var locationError: String?
    @State private var showLocationPermissionAlert: Bool = false
    
    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespaces)
    }
    
    private var isNameValid: Bool {
        !trimmedName.isEmpty && trimmedName.count <= 5
    }
    
    private var nameBinding: Binding<String> {
        Binding(
            get: { name },
            set: { newValue in
                if newValue.count <= 5 {
                    name = newValue
                } else {
                    name = String(newValue.prefix(5))
                }
            }
        )
    }
    
    private var locationDisplayText: String {
        if latitude != 0.0 && longitude != 0.0 {
            return String(format: "Lat: %.6f, Long: %.6f", latitude, longitude)
        } else {
            return "No location set"
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Group Details"), footer: Text(trimmedName.count > 5 ? "Group name must be 5 characters or less" : "").foregroundColor(.red)) {
                    TextField("Group Name (max 5 characters)", text: nameBinding)
                    if trimmedName.count > 0 {
                        Text("\(trimmedName.count)/5 characters")
                            .font(.caption)
                            .foregroundColor(trimmedName.count > 5 ? .red : .secondary)
                    }
                }
                
                Section(header: Text("Location Notifications")) {
                    Toggle(isOn: $notifyWhenAwayFromLocation) {
                        Text("Notify when \(locationNotificationDistance) metres away from current location")
                    }
                    .onChange(of: notifyWhenAwayFromLocation) { oldValue, newValue in
                        if newValue {
                            handleLocationToggleEnabled()
                        }
                    }
                    
                    if notifyWhenAwayFromLocation {
                        Picker("Distance (metres)", selection: $locationNotificationDistance) {
                            ForEach(1...50, id: \.self) { distance in
                                Text("\(distance)").tag(distance)
                            }
                        }
                        
                        if isFetchingLocation {
                            HStack {
                                ProgressView()
                                Text("Getting location...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } else if let error = locationError {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        } else if latitude != 0.0 && longitude != 0.0 {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Current Location:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(locationDisplayText)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                }
            }
            .navigationTitle(group == nil ? "New Group" : "Edit Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveGroup()
                    }
                    .disabled(!isNameValid)
                }
            }
            .onAppear {
                if let group = group {
                    name = group.name ?? ""
                    notifyWhenAwayFromLocation = group.notifyWhenAwayFromLocation
                    let savedDistance = Int(group.locationNotificationDistance)
                    locationNotificationDistance = savedDistance > 0 ? savedDistance : 15
                    latitude = group.latitude
                    longitude = group.longitude
                }
                locationManager.checkAuthorizationStatus()
            }
            .alert("Location Permission Required", isPresented: $showLocationPermissionAlert) {
                Button("Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) {
                    notifyWhenAwayFromLocation = false
                }
            } message: {
                Text("Please enable location services in Settings to use location-based notifications.")
            }
        }
    }
    
    private func handleLocationToggleEnabled() {
        Task {
            // Check authorization status
            locationManager.checkAuthorizationStatus()
            
            if locationManager.authorizationStatus == .notDetermined {
                // Request permission
                let granted = await locationManager.requestLocationPermission()
                if !granted {
                    await MainActor.run {
                        showLocationPermissionAlert = true
                        notifyWhenAwayFromLocation = false
                    }
                    return
                }
            } else if locationManager.authorizationStatus != .authorizedWhenInUse && locationManager.authorizationStatus != .authorizedAlways {
                // Permission denied or restricted
                await MainActor.run {
                    showLocationPermissionAlert = true
                    notifyWhenAwayFromLocation = false
                }
                return
            }
            
            // Get current location
            await MainActor.run {
                isFetchingLocation = true
                locationError = nil
            }
            
            do {
                if let location = try await locationManager.getCurrentLocation() {
                    await MainActor.run {
                        latitude = location.coordinate.latitude
                        longitude = location.coordinate.longitude
                        isFetchingLocation = false
                        locationError = nil
                    }
                } else {
                    await MainActor.run {
                        isFetchingLocation = false
                        locationError = "Unable to get location"
                    }
                }
            } catch {
                await MainActor.run {
                    isFetchingLocation = false
                    locationError = error.localizedDescription
                }
            }
        }
    }
    
    private func saveGroup() {
        withAnimation {
            guard isNameValid else { return }
            
            let groupToSave: Group
            if let existingGroup = group {
                groupToSave = existingGroup
            } else {
                groupToSave = Group(context: viewContext)
                groupToSave.id = UUID()
                groupToSave.createdAt = Date()
            }
            
            groupToSave.name = trimmedName
            groupToSave.notifyWhenAwayFromLocation = notifyWhenAwayFromLocation
            groupToSave.locationNotificationDistance = Int16(locationNotificationDistance)
            
            if notifyWhenAwayFromLocation && latitude != 0.0 && longitude != 0.0 {
                groupToSave.latitude = latitude
                groupToSave.longitude = longitude
            } else {
                groupToSave.latitude = 0.0
                groupToSave.longitude = 0.0
            }
            
            do {
                try viewContext.save()
                dismiss()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

#Preview {
    GroupManagerView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

