//
//  PointOfInterestManagerView.swift
//  smart todo
//
//  Created by Sourabh Mazumder on 4/1/2026.
//

import SwiftUI
import CoreData
import MapKit
import CoreLocation

struct PointOfInterestManagerView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \PointOfInterest.createdAt, ascending: false)],
        animation: .default)
    private var pointsOfInterest: FetchedResults<PointOfInterest>
    
    @State private var showingAddPOI = false
    @State private var editingPOI: PointOfInterest?
    
    var body: some View {
        NavigationView {
            List {
                if pointsOfInterest.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "mappin.circle")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("No points of interest yet")
                            .font(.title3)
                            .foregroundColor(.gray)
                        Text("Tap the + button to add your first point of interest")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    ForEach(pointsOfInterest) { poi in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundColor(.red)
                                Text(poi.name ?? "Unnamed Location")
                                    .font(.headline)
                            }
                            if let address = poi.address, !address.isEmpty {
                                Text(address)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Text(String(format: "Lat: %.6f, Long: %.6f", poi.latitude, poi.longitude))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            editingPOI = poi
                            showingAddPOI = true
                        }
                    }
                    .onDelete(perform: deletePointsOfInterest)
                }
            }
            .navigationTitle("Points of Interest")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        editingPOI = nil
                        showingAddPOI = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddPOI) {
                AddEditPointOfInterestView(poi: editingPOI)
            }
        }
    }
    
    private func deletePointsOfInterest(offsets: IndexSet) {
        withAnimation {
            offsets.map { pointsOfInterest[$0] }.forEach(viewContext.delete)
            
            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

struct AddEditPointOfInterestView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    var poi: PointOfInterest?
    
    @State private var name: String = ""
    @State private var address: String = ""
    @State private var latitude: Double = 0.0
    @State private var longitude: Double = 0.0
    @State private var selectedLocation: CLLocationCoordinate2D?
    @State private var showingMap = false
    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    
    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespaces)
    }
    
    private var isNameValid: Bool {
        !trimmedName.isEmpty
    }
    
    private var isLocationValid: Bool {
        latitude != 0.0 && longitude != 0.0
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Location Name")) {
                    TextField("Location Name", text: $name)
                }
                
                Section(header: Text("Select Location")) {
                    Button(action: {
                        showingMap = true
                    }) {
                        HStack {
                            Image(systemName: "map")
                            Text("Choose Location on Map")
                        }
                    }
                }
                
                // Only show location details after a location is selected
                if isLocationValid {
                    Section(header: Text("Location Details")) {
                        if !address.isEmpty {
                            Text(address)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Text(String(format: "Latitude: %.6f", latitude))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(String(format: "Longitude: %.6f", longitude))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle(poi == nil ? "New Point of Interest" : "Edit Point of Interest")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        savePointOfInterest()
                    }
                    .disabled(!isNameValid || !isLocationValid)
                }
            }
            .onAppear {
                if let poi = poi {
                    name = poi.name ?? ""
                    address = poi.address ?? ""
                    latitude = poi.latitude
                    longitude = poi.longitude
                    if latitude != 0.0 && longitude != 0.0 {
                        mapRegion = MKCoordinateRegion(
                            center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                        )
                    }
                }
            }
            .sheet(isPresented: $showingMap) {
                MapLocationPickerView(
                    region: $mapRegion,
                    selectedLocation: $selectedLocation,
                    onLocationSelected: { location, addressString in
                        latitude = location.latitude
                        longitude = location.longitude
                        address = addressString
                        selectedLocation = location
                        showingMap = false
                    }
                )
            }
        }
    }
    
    private func savePointOfInterest() {
        withAnimation {
            guard isNameValid && isLocationValid else { return }
            
            let poiToSave: PointOfInterest
            if let existingPOI = poi {
                poiToSave = existingPOI
            } else {
                poiToSave = PointOfInterest(context: viewContext)
                poiToSave.id = UUID()
                poiToSave.createdAt = Date()
            }
            
            poiToSave.name = trimmedName
            poiToSave.address = address.isEmpty ? nil : address
            poiToSave.latitude = latitude
            poiToSave.longitude = longitude
            
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

struct MapLocationPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var region: MKCoordinateRegion
    @Binding var selectedLocation: CLLocationCoordinate2D?
    var onLocationSelected: (CLLocationCoordinate2D, String) -> Void
    
    @StateObject private var locationManager = LocationManager.shared
    
    @State private var searchText: String = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var isSearching = false
    @State private var mapSelection: MKMapItem?
    @State private var showingSearchResults = false
    @State private var droppedPinCoordinate: CLLocationCoordinate2D?
    @State private var selectedPlaceName: String = ""
    @State private var selectedPlaceAddress: String = ""
    @State private var isFetchingLocation = false
    @State private var isGeocoding = false
    @State private var searchTask: Task<Void, Never>?
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    Map(coordinateRegion: $region, annotationItems: annotationItems) { pin in
                        MapMarker(coordinate: pin.coordinate, tint: .red)
                    }
                    .overlay(
                        VStack {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.red)
                                .offset(y: -20)
                            Spacer()
                        }
                    )
                    .overlay(
                        // Transparent overlay to capture taps
                        Color.clear
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onEnded { value in
                                        handleMapTap(at: value.location, in: geometry.size)
                                    }
                            )
                    )
                    
                    VStack(spacing: 0) {
                        HStack {
                            TextField("Search for location", text: $searchText)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .onChange(of: searchText) { oldValue, newValue in
                                    // Cancel previous search task
                                    searchTask?.cancel()
                                    
                                    // Perform search as user types (with debounce)
                                    if !newValue.isEmpty {
                                        searchTask = Task {
                                            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
                                            if !Task.isCancelled {
                                                await MainActor.run {
                                                    searchLocation()
                                                }
                                            }
                                        }
                                    } else {
                                        showingSearchResults = false
                                        searchResults = []
                                    }
                                }
                                .onSubmit {
                                    searchLocation()
                                }
                            Button(action: searchLocation) {
                                Image(systemName: "magnifyingglass")
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .shadow(radius: 5)
                        .padding()
                        
                        // Dropdown suggestions
                        if showingSearchResults && !searchResults.isEmpty {
                            let topResults = Array(searchResults.prefix(5))
                            VStack(spacing: 0) {
                                ForEach(topResults) { item in
                                    Button(action: {
                                        selectSearchResult(item)
                                    }) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(item.name ?? "Unknown")
                                                .font(.headline)
                                                .foregroundColor(.primary)
                                            if let address = item.placemark.title {
                                                Text(address)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    
                                    if item.id != topResults.last?.id {
                                        Divider()
                                            .padding(.leading, 12)
                                    }
                                }
                            }
                            .background(Color(.systemBackground))
                            .cornerRadius(10)
                            .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                            .padding(.horizontal)
                            .padding(.top, -10)
                            .zIndex(1)
                        }
                        
                        Spacer()
                        
                        // Place details above Select button
                        if !selectedPlaceName.isEmpty || !selectedPlaceAddress.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                if !selectedPlaceName.isEmpty {
                                    Text(selectedPlaceName)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                }
                                if !selectedPlaceAddress.isEmpty {
                                    Text(selectedPlaceAddress)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(10)
                            .shadow(radius: 5)
                            .padding(.horizontal)
                        }
                        
                        // Zoom controls
                        HStack {
                            Spacer()
                            VStack(spacing: 8) {
                                Button(action: zoomIn) {
                                    Image(systemName: "plus")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                        .frame(width: 44, height: 44)
                                        .background(Color(.systemBackground))
                                        .cornerRadius(8)
                                        .shadow(radius: 2)
                                }
                                
                                Button(action: zoomOut) {
                                    Image(systemName: "minus")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                        .frame(width: 44, height: 44)
                                        .background(Color(.systemBackground))
                                        .cornerRadius(8)
                                        .shadow(radius: 2)
                                }
                            }
                            .padding(.trailing)
                        }
                        .padding(.top)
                        
                        Button(action: {
                            selectCurrentLocation()
                        }) {
                            Text("Select")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(isLocationSelected ? Color.blue : Color.gray)
                                .cornerRadius(10)
                        }
                        .disabled(!isLocationSelected)
                        .padding()
                    }
                }
            }
            .navigationTitle("Select Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadCurrentLocation()
            }
        }
    }
    
    private var annotationItems: [MapPin] {
        if let coordinate = droppedPinCoordinate ?? selectedLocation {
            return [MapPin(coordinate: coordinate)]
        }
        return []
    }
    
    private var isLocationSelected: Bool {
        droppedPinCoordinate != nil || selectedLocation != nil || mapSelection != nil
    }
    
    private func handleMapTap(at location: CGPoint, in size: CGSize) {
        // Convert tap location to coordinate
        let mapWidth = size.width
        let mapHeight = size.height
        
        let latDelta = region.span.latitudeDelta
        let lonDelta = region.span.longitudeDelta
        
        // Calculate the coordinate offset from center
        // Note: Y is inverted in screen coordinates (top is 0, bottom is height)
        let latOffset = (location.y - mapHeight / 2) / mapHeight * latDelta
        let lonOffset = (location.x - mapWidth / 2) / mapWidth * lonDelta
        
        let coordinate = CLLocationCoordinate2D(
            latitude: region.center.latitude - latOffset,
            longitude: region.center.longitude + lonOffset
        )
        
        droppedPinCoordinate = coordinate
        selectedLocation = coordinate
        mapSelection = nil
        selectedPlaceName = ""
        selectedPlaceAddress = ""
        geocodeLocation(coordinate: coordinate)
    }
    
    private func loadCurrentLocation() {
        Task {
            await MainActor.run {
                isFetchingLocation = true
            }
            
            locationManager.checkAuthorizationStatus()
            
            if locationManager.authorizationStatus == .notDetermined {
                let granted = await locationManager.requestLocationPermission()
                if !granted {
                    await MainActor.run {
                        isFetchingLocation = false
                    }
                    return
                }
            } else if locationManager.authorizationStatus != .authorizedWhenInUse && locationManager.authorizationStatus != .authorizedAlways {
                await MainActor.run {
                    isFetchingLocation = false
                }
                return
            }
            
            do {
                if let location = try await locationManager.getCurrentLocation() {
                    let coordinate = location.coordinate
                    await MainActor.run {
                        region = MKCoordinateRegion(
                            center: coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                        )
                        droppedPinCoordinate = coordinate
                        selectedLocation = coordinate
                        isFetchingLocation = false
                        geocodeLocation(coordinate: coordinate)
                    }
                } else {
                    await MainActor.run {
                        isFetchingLocation = false
                    }
                }
            } catch {
                await MainActor.run {
                    isFetchingLocation = false
                }
            }
        }
    }
    
    private func geocodeLocation(coordinate: CLLocationCoordinate2D) {
        isGeocoding = true
        let geocoder = CLGeocoder()
        let clLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        geocoder.reverseGeocodeLocation(clLocation) { placemarks, error in
            DispatchQueue.main.async {
                self.isGeocoding = false
                if let placemark = placemarks?.first {
                    // Get place name
                    if let name = placemark.name {
                        self.selectedPlaceName = name
                    } else if let thoroughfare = placemark.thoroughfare {
                        self.selectedPlaceName = thoroughfare
                    } else {
                        self.selectedPlaceName = "Selected Location"
                    }
                    
                    // Get full address
                    let components = [
                        placemark.subThoroughfare,
                        placemark.thoroughfare,
                        placemark.locality,
                        placemark.administrativeArea,
                        placemark.postalCode,
                        placemark.country
                    ].compactMap { $0 }
                    self.selectedPlaceAddress = components.joined(separator: ", ")
                } else {
                    self.selectedPlaceName = "Selected Location"
                    self.selectedPlaceAddress = String(format: "Lat: %.6f, Long: %.6f", coordinate.latitude, coordinate.longitude)
                }
            }
        }
    }
    
    private func zoomIn() {
        withAnimation {
            region.span.latitudeDelta *= 0.5
            region.span.longitudeDelta *= 0.5
        }
    }
    
    private func zoomOut() {
        withAnimation {
            region.span.latitudeDelta = min(region.span.latitudeDelta * 2, 180.0)
            region.span.longitudeDelta = min(region.span.longitudeDelta * 2, 180.0)
        }
    }
    
    private func searchLocation() {
        guard !searchText.isEmpty else {
            searchResults = []
            showingSearchResults = false
            return
        }
        
        isSearching = true
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        request.region = region
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            DispatchQueue.main.async {
                self.isSearching = false
                if let error = error {
                    print("Search error: \(error.localizedDescription)")
                    self.searchResults = []
                    self.showingSearchResults = false
                    return
                }
                
                if let response = response {
                    self.searchResults = response.mapItems
                    self.showingSearchResults = !response.mapItems.isEmpty
                    
                    // Move map to first result if available
                    if let firstResult = response.mapItems.first {
                        let coordinate = firstResult.placemark.coordinate
                        self.region = MKCoordinateRegion(
                            center: coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                        )
                    }
                } else {
                    self.searchResults = []
                    self.showingSearchResults = false
                }
            }
        }
    }
    
    private func selectSearchResult(_ item: MKMapItem) {
        let coordinate = item.placemark.coordinate
        mapSelection = item
        droppedPinCoordinate = coordinate
        selectedLocation = coordinate
        region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
        showingSearchResults = false
        searchText = item.name ?? ""
        
        // Update place details from search result
        selectedPlaceName = item.name ?? "Selected Location"
        if let address = item.placemark.title {
            selectedPlaceAddress = address
        } else {
            // Fallback to reverse geocoding if title is not available
            geocodeLocation(coordinate: coordinate)
        }
    }
    
    private func selectCurrentLocation() {
        let location: CLLocationCoordinate2D
        
        if let mapItem = mapSelection {
            location = mapItem.placemark.coordinate
            selectedPlaceName = mapItem.name ?? "Selected Location"
            if let address = mapItem.placemark.title {
                selectedPlaceAddress = address
            } else {
                selectedPlaceAddress = ""
            }
            onLocationSelected(location, selectedPlaceAddress)
        } else if let droppedPin = droppedPinCoordinate {
            location = droppedPin
            onLocationSelected(location, selectedPlaceAddress)
        } else if let selectedLoc = selectedLocation {
            location = selectedLoc
            onLocationSelected(location, selectedPlaceAddress)
        } else {
            // Fallback to center if nothing is selected
            location = region.center
            let geocoder = CLGeocoder()
            let clLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
            
            geocoder.reverseGeocodeLocation(clLocation) { placemarks, error in
                DispatchQueue.main.async {
                    var addressString = ""
                    if let placemark = placemarks?.first {
                        let components = [
                            placemark.subThoroughfare,
                            placemark.thoroughfare,
                            placemark.locality,
                            placemark.administrativeArea,
                            placemark.postalCode,
                            placemark.country
                        ].compactMap { $0 }
                        addressString = components.joined(separator: ", ")
                    }
                    
                    self.onLocationSelected(location, addressString)
                }
            }
        }
    }
}

struct MapPin: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

extension MKMapItem: Identifiable {
    public var id: String {
        return "\(placemark.coordinate.latitude)-\(placemark.coordinate.longitude)"
    }
}

#Preview {
    PointOfInterestManagerView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
