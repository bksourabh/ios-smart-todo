//
//  LocationManager.swift
//  smart todo
//
//  Created by Sourabh Mazumder on 4/1/2026.
//

import Foundation
import CoreLocation
import Combine

final class LocationManager: NSObject, ObservableObject {
    static let shared = LocationManager()
    
    private let locationManager = CLLocationManager()
    
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var currentLocation: CLLocation?
    @Published var locationError: Error?
    
    private var locationContinuation: CheckedContinuation<CLLocation?, Error>?
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        authorizationStatus = locationManager.authorizationStatus
    }
    
    func requestLocationPermission() async -> Bool {
        guard authorizationStatus == .notDetermined else {
            return authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
        }
        
        locationManager.requestWhenInUseAuthorization()
        
        // Wait for authorization status to change
        return await withCheckedContinuation { continuation in
            var cancellable: AnyCancellable?
            cancellable = $authorizationStatus
                .dropFirst()
                .sink { status in
                    cancellable?.cancel()
                    continuation.resume(returning: status == .authorizedWhenInUse || status == .authorizedAlways)
                }
        }
    }
    
    func getCurrentLocation() async throws -> CLLocation? {
        // Check authorization first
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            throw LocationError.notAuthorized
        }
        
        // Check if location services are enabled
        guard CLLocationManager.locationServicesEnabled() else {
            throw LocationError.locationServicesDisabled
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            locationContinuation = continuation
            locationManager.requestLocation()
        }
    }
    
    func checkAuthorizationStatus() {
        authorizationStatus = locationManager.authorizationStatus
    }
}

extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.first {
            currentLocation = location
            locationError = nil
            locationContinuation?.resume(returning: location)
            locationContinuation = nil
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationError = error
        locationContinuation?.resume(throwing: error)
        locationContinuation = nil
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
    }
}

enum LocationError: LocalizedError {
    case notAuthorized
    case locationServicesDisabled
    case locationUnavailable
    
    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Location permission not granted"
        case .locationServicesDisabled:
            return "Location services are disabled"
        case .locationUnavailable:
            return "Location is currently unavailable"
        }
    }
}
