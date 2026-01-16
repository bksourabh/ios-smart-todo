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
                    onLocationSelected: { location, addressString, searchString in
                        latitude = location.latitude
                        longitude = location.longitude
                        address = addressString
                        selectedLocation = location
                        // Populate name with search string if present and name is empty
                        if let searchString = searchString, !searchString.isEmpty, name.isEmpty {
                            name = searchString
                        }
                        showingMap = false
                    },
                    initialLocation: (latitude != 0.0 && longitude != 0.0) ? CLLocationCoordinate2D(latitude: latitude, longitude: longitude) : nil
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
    var onLocationSelected: (CLLocationCoordinate2D, String, String?) -> Void
    var initialLocation: CLLocationCoordinate2D?
    
    @StateObject private var locationManager = LocationManager.shared
    
    init(region: Binding<MKCoordinateRegion>, selectedLocation: Binding<CLLocationCoordinate2D?>, onLocationSelected: @escaping (CLLocationCoordinate2D, String, String?) -> Void, initialLocation: CLLocationCoordinate2D? = nil) {
        self._region = region
        self._selectedLocation = selectedLocation
        self.onLocationSelected = onLocationSelected
        self.initialLocation = initialLocation
    }
    
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
    @State private var hasUserSelectedLocation = false
    @State private var mapPosition: MapCameraPosition = .automatic
    @State private var isNearbySearch = false
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    Map(position: $mapPosition) {
                        ForEach(annotationItems) { pin in
                            Annotation("", coordinate: pin.coordinate) {
                                VStack(spacing: 0) {
                                    Image(systemName: "mappin.circle.fill")
                                        .font(.system(size: 44))
                                        .foregroundStyle(.white, .red)
                                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                                    Image(systemName: "arrowtriangle.down.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(.red)
                                        .offset(y: -5)
                                }
                                .offset(y: -22)
                            }
                        }
                    }
                    .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .including([.restaurant, .cafe, .store, .gasStation, .hospital, .pharmacy])))
                    .onMapCameraChange { context in
                        region = context.region
                    }
                    .mapControls {
                        MapCompass()
                    }
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
                        // Search bar with glass effect
                        HStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                                .font(.system(size: 16, weight: .medium))

                            TextField("Search for a place", text: $searchText)
                                .font(.system(size: 16))
                                .onChange(of: searchText) { oldValue, newValue in
                                    searchTask?.cancel()
                                    if !newValue.isEmpty {
                                        searchTask = Task {
                                            try? await Task.sleep(nanoseconds: 300_000_000)
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

                            if !searchText.isEmpty {
                                Button(action: {
                                    searchText = ""
                                    searchResults = []
                                    showingSearchResults = false
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                        .font(.system(size: 16))
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        
                        // Dropdown suggestions
                        if showingSearchResults || !searchText.isEmpty {
                            VStack(spacing: 0) {
                                // Search Nearby option
                                Button(action: {
                                    searchNearby()
                                }) {
                                    HStack(spacing: 14) {
                                        ZStack {
                                            Circle()
                                                .fill(Color.blue.opacity(0.15))
                                                .frame(width: 36, height: 36)
                                            Image(systemName: "location.fill")
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundColor(.blue)
                                        }
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Search Nearby")
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundColor(.primary)
                                            Text("Find places around you")
                                                .font(.system(size: 12))
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.gray.opacity(0.5))
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
                                }
                                .buttonStyle(PlainButtonStyle())

                                if !searchResults.isEmpty {
                                    Divider()
                                        .padding(.leading, 64)

                                    let sortedResults = sortResultsByDistance(searchResults)
                                    let topResults = Array(sortedResults.prefix(5))
                                    ForEach(topResults) { item in
                                        Button(action: {
                                            selectSearchResult(item)
                                        }) {
                                            HStack(spacing: 14) {
                                                ZStack {
                                                    Circle()
                                                        .fill(Color.gray.opacity(0.12))
                                                        .frame(width: 36, height: 36)
                                                    Image(systemName: "mappin")
                                                        .font(.system(size: 14, weight: .medium))
                                                        .foregroundColor(.secondary)
                                                }
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(item.name ?? "Unknown")
                                                        .font(.system(size: 15, weight: .medium))
                                                        .foregroundColor(.primary)
                                                        .lineLimit(1)
                                                    if let address = item.address {
                                                        Text(formatAddress(address))
                                                            .font(.system(size: 12))
                                                            .foregroundColor(.secondary)
                                                            .lineLimit(1)
                                                    }
                                                }
                                                Spacer()
                                                Text(distanceText(for: item))
                                                    .font(.system(size: 11, weight: .medium))
                                                    .foregroundColor(.secondary)
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 4)
                                                    .background(Color.gray.opacity(0.1))
                                                    .cornerRadius(6)
                                            }
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 10)
                                        }
                                        .buttonStyle(PlainButtonStyle())

                                        if item.id != topResults.last?.id {
                                            Divider()
                                                .padding(.leading, 64)
                                        }
                                    }
                                }
                            }
                            .background(.ultraThinMaterial)
                            .cornerRadius(14)
                            .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 6)
                            .padding(.horizontal, 16)
                            .padding(.top, 6)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                        
                        Spacer()

                        // Zoom controls and current location button
                        HStack {
                            // Current location button
                            Button(action: loadCurrentLocation) {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.blue)
                                    .frame(width: 44, height: 44)
                                    .background(.ultraThinMaterial)
                                    .cornerRadius(10)
                                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                            }
                            .padding(.leading, 16)

                            Spacer()

                            VStack(spacing: 1) {
                                Button(action: zoomIn) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundColor(.primary)
                                        .frame(width: 44, height: 44)
                                }

                                Divider()
                                    .frame(width: 30)

                                Button(action: zoomOut) {
                                    Image(systemName: "minus")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundColor(.primary)
                                        .frame(width: 44, height: 44)
                                }
                            }
                            .background(.ultraThinMaterial)
                            .cornerRadius(10)
                            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                            .padding(.trailing, 16)
                        }

                        // Place details card
                        if !selectedPlaceName.isEmpty || !selectedPlaceAddress.isEmpty {
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(Color.red.opacity(0.15))
                                        .frame(width: 44, height: 44)
                                    Image(systemName: "mappin.circle.fill")
                                        .font(.system(size: 22))
                                        .foregroundColor(.red)
                                }

                                VStack(alignment: .leading, spacing: 3) {
                                    if !selectedPlaceName.isEmpty {
                                        Text(selectedPlaceName)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                    }
                                    if !selectedPlaceAddress.isEmpty {
                                        Text(selectedPlaceAddress)
                                            .font(.system(size: 13))
                                            .foregroundColor(.secondary)
                                            .lineLimit(2)
                                    }
                                }

                                Spacer()
                            }
                            .padding(14)
                            .background(.ultraThinMaterial)
                            .cornerRadius(14)
                            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                        }

                        // Select button
                        Button(action: {
                            selectCurrentLocation()
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                Text("Select This Location")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: isLocationSelected ? [Color.blue, Color.blue.opacity(0.8)] : [Color.gray, Color.gray],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(14)
                            .shadow(color: isLocationSelected ? Color.blue.opacity(0.3) : Color.clear, radius: 8, x: 0, y: 4)
                        }
                        .disabled(!isLocationSelected)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }
            }
            .navigationTitle("Select Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                // Initialize mapPosition from region
                mapPosition = .region(region)

                // If an initial location is provided (e.g., when editing), use it
                if let initialLoc = initialLocation {
                    droppedPinCoordinate = initialLoc
                    selectedLocation = initialLoc
                    hasUserSelectedLocation = true
                    geocodeLocation(coordinate: initialLoc)
                } else {
                    // Only load current location if no initial location is provided
                    loadCurrentLocation()
                }
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
        
        hasUserSelectedLocation = true
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
                        mapPosition = .region(region)
                        // Only set initial location if user hasn't selected one yet
                        if !hasUserSelectedLocation {
                            droppedPinCoordinate = coordinate
                            selectedLocation = coordinate
                            geocodeLocation(coordinate: coordinate)
                        }
                        isFetchingLocation = false
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
        Task {
            do {
                let clLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                guard let request = MKReverseGeocodingRequest(location: clLocation) else {
                    await MainActor.run {
                        self.isGeocoding = false
                        self.selectedPlaceName = "Selected Location"
                        self.selectedPlaceAddress = String(format: "Lat: %.6f, Long: %.6f", coordinate.latitude, coordinate.longitude)
                    }
                    return
                }
                let mapItems = try await request.mapItems
                await MainActor.run {
                    self.isGeocoding = false
                    if let firstItem = mapItems.first {
                        // Get place name
                        if let name = firstItem.name {
                            self.selectedPlaceName = name
                        } else if let address = firstItem.address, let shortAddr = address.shortAddress {
                            self.selectedPlaceName = shortAddr
                        } else {
                            self.selectedPlaceName = "Selected Location"
                        }

                        // Get full address
                        if let address = firstItem.address {
                            self.selectedPlaceAddress = address.fullAddress
                        } else {
                            self.selectedPlaceAddress = String(format: "Lat: %.6f, Long: %.6f", coordinate.latitude, coordinate.longitude)
                        }
                    } else {
                        self.selectedPlaceName = "Selected Location"
                        self.selectedPlaceAddress = String(format: "Lat: %.6f, Long: %.6f", coordinate.latitude, coordinate.longitude)
                    }
                }
            } catch {
                await MainActor.run {
                    self.isGeocoding = false
                    self.selectedPlaceName = "Selected Location"
                    self.selectedPlaceAddress = String(format: "Lat: %.6f, Long: %.6f", coordinate.latitude, coordinate.longitude)
                }
            }
        }
    }

    private func reverseGeocode(coordinate: CLLocationCoordinate2D, completion: @escaping (String) -> Void) {
        Task {
            do {
                let clLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                guard let request = MKReverseGeocodingRequest(location: clLocation) else {
                    await MainActor.run {
                        completion("")
                    }
                    return
                }
                let mapItems = try await request.mapItems
                await MainActor.run {
                    if let firstItem = mapItems.first, let address = firstItem.address {
                        completion(formatAddress(address))
                    } else {
                        completion("")
                    }
                }
            } catch {
                await MainActor.run {
                    completion("")
                }
            }
        }
    }
    
    private func zoomIn() {
        withAnimation {
            region.span.latitudeDelta *= 0.5
            region.span.longitudeDelta *= 0.5
            mapPosition = .region(region)
        }
    }

    private func zoomOut() {
        withAnimation {
            region.span.latitudeDelta = min(region.span.latitudeDelta * 2, 180.0)
            region.span.longitudeDelta = min(region.span.longitudeDelta * 2, 180.0)
            mapPosition = .region(region)
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
                    self.isNearbySearch = false

                    // Move map to first result if available
                    if let firstResult = response.mapItems.first {
                        let coordinate = firstResult.location.coordinate
                        self.region = MKCoordinateRegion(
                            center: coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                        )
                        self.mapPosition = .region(self.region)
                    }
                } else {
                    self.searchResults = []
                    self.showingSearchResults = false
                }
            }
        }
    }

    private func searchNearby() {
        isSearching = true
        isNearbySearch = true
        showingSearchResults = false
        searchResults = []

        Task {
            // Get device's current location first
            var searchCenter = region.center
            if let currentLocation = try? await locationManager.getCurrentLocation() {
                searchCenter = currentLocation.coordinate
            }

            // 50km radius - approximately 0.45 degrees latitude
            let radiusInDegrees = 0.45
            let searchRegion = MKCoordinateRegion(
                center: searchCenter,
                span: MKCoordinateSpan(latitudeDelta: radiusInDegrees * 2, longitudeDelta: radiusInDegrees * 2)
            )

            // Search for various nearby place types
            let searchQueries = ["restaurant", "cafe", "grocery", "supermarket", "pharmacy", "bank", "gas station", "hospital", "hotel", "shopping"]
            var allResults: [MKMapItem] = []

            for query in searchQueries {
                let request = MKLocalSearch.Request()
                request.naturalLanguageQuery = query
                request.region = searchRegion

                let search = MKLocalSearch(request: request)
                do {
                    let response = try await search.start()
                    allResults.append(contentsOf: response.mapItems)
                } catch {
                    print("Search error for \(query): \(error.localizedDescription)")
                }
            }

            await MainActor.run {
                self.isSearching = false

                // Filter to only include results within 50km
                let maxDistance: CLLocationDistance = 50000 // 50km in meters
                let centerLocation = CLLocation(latitude: searchCenter.latitude, longitude: searchCenter.longitude)

                let filteredResults = allResults.filter { item in
                    let itemLocation = CLLocation(latitude: item.location.coordinate.latitude, longitude: item.location.coordinate.longitude)
                    return itemLocation.distance(from: centerLocation) <= maxDistance
                }

                // Remove duplicates based on location
                var uniqueResults: [MKMapItem] = []
                var seenLocations: Set<String> = []
                for item in filteredResults {
                    let key = "\(item.location.coordinate.latitude)-\(item.location.coordinate.longitude)"
                    if !seenLocations.contains(key) {
                        seenLocations.insert(key)
                        uniqueResults.append(item)
                    }
                }

                // Sort by distance (nearest first)
                let sortedResults = uniqueResults.sorted { item1, item2 in
                    let loc1 = CLLocation(latitude: item1.location.coordinate.latitude, longitude: item1.location.coordinate.longitude)
                    let loc2 = CLLocation(latitude: item2.location.coordinate.latitude, longitude: item2.location.coordinate.longitude)
                    return loc1.distance(from: centerLocation) < loc2.distance(from: centerLocation)
                }

                self.searchResults = sortedResults
                self.showingSearchResults = !sortedResults.isEmpty
                self.searchText = ""

                // Update region to show current location
                self.region = MKCoordinateRegion(
                    center: searchCenter,
                    span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
                )
                self.mapPosition = .region(self.region)
            }
        }
    }

    private func sortResultsByDistance(_ results: [MKMapItem]) -> [MKMapItem] {
        let currentCenter = region.center
        return results.sorted { item1, item2 in
            let distance1 = distanceFromCenter(item1.location.coordinate, to: currentCenter)
            let distance2 = distanceFromCenter(item2.location.coordinate, to: currentCenter)
            return distance1 < distance2
        }
    }

    private func distanceFromCenter(_ coordinate: CLLocationCoordinate2D, to center: CLLocationCoordinate2D) -> CLLocationDistance {
        let location1 = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let location2 = CLLocation(latitude: center.latitude, longitude: center.longitude)
        return location1.distance(from: location2)
    }

    private func distanceText(for item: MKMapItem) -> String {
        let distance = distanceFromCenter(item.location.coordinate, to: region.center)
        if distance < 1000 {
            return String(format: "%.0f m", distance)
        } else {
            return String(format: "%.1f km", distance / 1000)
        }
    }

    private func selectSearchResult(_ item: MKMapItem) {
        let coordinate = item.location.coordinate
        hasUserSelectedLocation = true
        mapSelection = item
        droppedPinCoordinate = coordinate
        selectedLocation = coordinate
        region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
        mapPosition = .region(region)
        showingSearchResults = false
        searchText = item.name ?? ""

        // Update place details from search result
        selectedPlaceName = item.name ?? "Selected Location"
        if let address = item.address {
            selectedPlaceAddress = formatAddress(address)
        } else {
            // Fallback to reverse geocoding if address is not available
            geocodeLocation(coordinate: coordinate)
        }
    }
    
    private func selectCurrentLocation() {
        let location: CLLocationCoordinate2D
        let searchString: String? = searchText.isEmpty ? nil : searchText

        // Prioritize user-selected locations over current location
        if let mapItem = mapSelection {
            // User selected a search result
            location = mapItem.location.coordinate
            selectedPlaceName = mapItem.name ?? "Selected Location"
            if let address = mapItem.address {
                selectedPlaceAddress = formatAddress(address)
            } else {
                selectedPlaceAddress = ""
            }
            onLocationSelected(location, selectedPlaceAddress, searchString)
        } else if let droppedPin = droppedPinCoordinate {
            // User tapped on the map
            location = droppedPin
            onLocationSelected(location, selectedPlaceAddress, searchString)
        } else if hasUserSelectedLocation, let selectedLoc = selectedLocation {
            // User has explicitly selected a location
            location = selectedLoc
            onLocationSelected(location, selectedPlaceAddress, searchString)
        } else if let selectedLoc = selectedLocation {
            // Use selected location (from initial load or previous selection)
            location = selectedLoc
            onLocationSelected(location, selectedPlaceAddress, searchString)
        } else {
            // Fallback to center if nothing is selected
            location = region.center
            reverseGeocode(coordinate: location) { addressString in
                self.onLocationSelected(location, addressString, searchString)
            }
        }
    }

    private func formatAddress(_ address: MKAddress) -> String {
        return address.fullAddress
    }
}

struct MapPin: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

extension MKMapItem: @retroactive Identifiable {
    public var id: String {
        return "\(location.coordinate.latitude)-\(location.coordinate.longitude)"
    }
}

#Preview {
    PointOfInterestManagerView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
