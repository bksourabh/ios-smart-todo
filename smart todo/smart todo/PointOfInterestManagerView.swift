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
                Section(header: Text("Location Details")) {
                    TextField("Location Name", text: $name)
                    
                    if !address.isEmpty {
                        Text(address)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    if latitude != 0.0 && longitude != 0.0 {
                        Text(String(format: "Latitude: %.6f", latitude))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(String(format: "Longitude: %.6f", longitude))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
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
    
    @State private var searchText: String = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var isSearching = false
    @State private var mapSelection: MKMapItem?
    @State private var showingSearchResults = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Map(coordinateRegion: $region, annotationItems: [MapPin(coordinate: region.center)]) { pin in
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
                
                VStack {
                    HStack {
                        TextField("Search for location", text: $searchText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
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
                    
                    if showingSearchResults && !searchResults.isEmpty {
                        List(searchResults) { item in
                            Button(action: {
                                selectSearchResult(item)
                            }) {
                                VStack(alignment: .leading) {
                                    Text(item.name ?? "Unknown")
                                        .font(.headline)
                                    if let address = item.placemark.title {
                                        Text(address)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        .frame(maxHeight: 200)
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .shadow(radius: 5)
                        .padding(.horizontal)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        selectCurrentLocation()
                    }) {
                        Text("Select")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    .padding()
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
        }
    }
    
    private func searchLocation() {
        guard !searchText.isEmpty else { return }
        
        isSearching = true
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        request.region = region
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            DispatchQueue.main.async {
                isSearching = false
                if let error = error {
                    print("Search error: \(error.localizedDescription)")
                    searchResults = []
                    showingSearchResults = false
                    return
                }
                
                if let response = response {
                    searchResults = response.mapItems
                    showingSearchResults = true
                    
                    // Move map to first result if available
                    if let firstResult = response.mapItems.first {
                        let coordinate = firstResult.placemark.coordinate
                        region = MKCoordinateRegion(
                            center: coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                        )
                    }
                } else {
                    searchResults = []
                    showingSearchResults = false
                }
            }
        }
    }
    
    private func selectSearchResult(_ item: MKMapItem) {
        let coordinate = item.placemark.coordinate
        mapSelection = item
        region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
        showingSearchResults = false
        searchText = item.name ?? ""
    }
    
    private func selectCurrentLocation() {
        let location = mapSelection?.placemark.coordinate ?? region.center
        
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
                
                onLocationSelected(location, addressString)
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
