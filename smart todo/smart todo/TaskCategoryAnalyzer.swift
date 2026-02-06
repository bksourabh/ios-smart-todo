//
//  TaskCategoryAnalyzer.swift
//  smart todo
//
//  Created by Sourabh Mazumder on 6/2/2026.
//

import Foundation
import CoreData

/// Represents a category of locations that can fulfill a task
enum LocationCategory: String, CaseIterable {
    case pharmacy = "pharmacy"
    case fuelStation = "fuel_station"
    case supermarket = "supermarket"
    case grocery = "grocery"
    case restaurant = "restaurant"
    case bank = "bank"
    case postOffice = "post_office"
    case hardware = "hardware"
    case electronics = "electronics"
    case clothing = "clothing"

    /// Display name for the category (used in labels)
    var displayName: String {
        switch self {
        case .pharmacy: return "Pharmacies"
        case .fuelStation: return "Fuel Stations"
        case .supermarket: return "Supermarkets"
        case .grocery: return "Grocery Stores"
        case .restaurant: return "Restaurants"
        case .bank: return "Banks"
        case .postOffice: return "Post Offices"
        case .hardware: return "Hardware Stores"
        case .electronics: return "Electronics Stores"
        case .clothing: return "Clothing Stores"
        }
    }

    /// Singular display name
    var singularDisplayName: String {
        switch self {
        case .pharmacy: return "Pharmacy"
        case .fuelStation: return "Fuel Station"
        case .supermarket: return "Supermarket"
        case .grocery: return "Grocery Store"
        case .restaurant: return "Restaurant"
        case .bank: return "Bank"
        case .postOffice: return "Post Office"
        case .hardware: return "Hardware Store"
        case .electronics: return "Electronics Store"
        case .clothing: return "Clothing Store"
        }
    }

    /// SF Symbol icon for the category
    var icon: String {
        switch self {
        case .pharmacy: return "cross.case.fill"
        case .fuelStation: return "fuelpump.fill"
        case .supermarket: return "cart.fill"
        case .grocery: return "basket.fill"
        case .restaurant: return "fork.knife"
        case .bank: return "building.columns.fill"
        case .postOffice: return "envelope.fill"
        case .hardware: return "hammer.fill"
        case .electronics: return "desktopcomputer"
        case .clothing: return "tshirt.fill"
        }
    }

    /// Keywords that indicate this category
    var keywords: [String] {
        switch self {
        case .pharmacy:
            return ["medicine", "medicines", "medication", "medications", "prescription", "prescriptions",
                    "pharmacy", "pharmacies", "chemist", "drug", "drugs", "drugstore", "tablets", "pills",
                    "paracetamol", "aspirin", "bandage", "first aid", "vitamins", "supplements",
                    "health", "medical", "antibiotics", "cough syrup", "inhaler"]
        case .fuelStation:
            return ["fuel", "petrol", "gas", "gasoline", "diesel", "fill up", "refuel", "tank",
                    "shell", "bp", "caltex", "mobil", "ampol", "7-eleven fuel", "servo",
                    "service station", "petrol station", "gas station", "fuel station"]
        case .supermarket:
            return ["supermarket", "grocery", "groceries", "shopping", "woolworths", "coles",
                    "aldi", "iga", "costco", "walmart", "tesco", "sainsbury", "asda",
                    "buy food", "weekly shop", "food shopping"]
        case .grocery:
            return ["milk", "bread", "eggs", "butter", "cheese", "vegetables", "veggies",
                    "fruits", "fruit", "meat", "chicken", "fish", "rice", "pasta", "cereal",
                    "snacks", "drinks", "beverages", "juice", "water", "soda", "coffee", "tea"]
        case .restaurant:
            return ["restaurant", "dine", "dining", "eat out", "dinner", "lunch", "breakfast",
                    "cafe", "coffee shop", "takeaway", "takeout", "food court", "mcdonald",
                    "kfc", "hungry jack", "subway", "pizza", "sushi", "thai", "chinese", "indian"]
        case .bank:
            return ["bank", "banking", "atm", "cash", "withdraw", "deposit", "transfer",
                    "commonwealth", "westpac", "anz", "nab", "hsbc", "citibank",
                    "cheque", "check", "account", "loan"]
        case .postOffice:
            return ["post office", "mail", "postage", "stamp", "stamps", "parcel", "package",
                    "send letter", "courier", "australia post", "usps", "royal mail",
                    "fedex", "ups", "dhl", "shipping"]
        case .hardware:
            return ["hardware", "bunnings", "home depot", "lowes", "mitre 10", "tools",
                    "screws", "nails", "paint", "timber", "lumber", "plumbing", "electrical",
                    "garden", "gardening", "plants", "soil", "fertilizer", "diy", "renovation"]
        case .electronics:
            return ["electronics", "jb hi-fi", "harvey norman", "best buy", "computer",
                    "laptop", "phone", "mobile", "tablet", "ipad", "charger", "cable",
                    "headphones", "speaker", "tv", "television", "gaming", "playstation", "xbox"]
        case .clothing:
            return ["clothes", "clothing", "shirt", "pants", "jeans", "dress", "shoes",
                    "jacket", "coat", "underwear", "socks", "hat", "cap", "fashion",
                    "h&m", "zara", "uniqlo", "target", "kmart", "big w", "myer", "david jones"]
        }
    }
}

/// Analyzes task titles to determine relevant location categories
class TaskCategoryAnalyzer {

    /// Analyzes a task title and returns matching location categories
    /// - Parameter title: The task title to analyze
    /// - Returns: Array of matching LocationCategory sorted by relevance
    static func analyzeTask(title: String) -> [LocationCategory] {
        let lowercasedTitle = title.lowercased()
        var matches: [(category: LocationCategory, score: Int)] = []

        for category in LocationCategory.allCases {
            var score = 0
            for keyword in category.keywords {
                if lowercasedTitle.contains(keyword) {
                    // Longer keyword matches get higher scores
                    score += keyword.count
                }
            }
            if score > 0 {
                matches.append((category, score))
            }
        }

        // Sort by score (highest first) and return categories
        return matches.sorted { $0.score > $1.score }.map { $0.category }
    }

    /// Finds all POIs that match the given categories
    /// - Parameters:
    ///   - categories: The location categories to match
    ///   - context: The Core Data managed object context
    /// - Returns: Array of matching PointOfInterest objects
    static func findMatchingPOIs(for categories: [LocationCategory], in context: NSManagedObjectContext) -> [PointOfInterest] {
        let fetchRequest: NSFetchRequest<PointOfInterest> = PointOfInterest.fetchRequest()

        do {
            let allPOIs = try context.fetch(fetchRequest)
            var matchingPOIs: [PointOfInterest] = []

            for poi in allPOIs {
                let poiName = (poi.name ?? "").lowercased()

                for category in categories {
                    var isMatch = false

                    // Check if POI name contains any category keywords
                    for keyword in category.keywords {
                        if poiName.contains(keyword) {
                            isMatch = true
                            break
                        }
                    }

                    // Also check common POI naming patterns
                    switch category {
                    case .pharmacy:
                        if poiName.contains("pharmacy") || poiName.contains("chemist") ||
                           poiName.contains("priceline") || poiName.contains("terry white") ||
                           poiName.contains("amcal") || poiName.contains("blooms") ||
                           poiName.contains("cvs") || poiName.contains("walgreens") {
                            isMatch = true
                        }
                    case .fuelStation:
                        if poiName.contains("petrol") || poiName.contains("fuel") ||
                           poiName.contains("shell") || poiName.contains("bp ") ||
                           poiName.contains("caltex") || poiName.contains("ampol") ||
                           poiName.contains("mobil") || poiName.contains("7-eleven") ||
                           poiName.contains("united") || poiName.contains("servo") {
                            isMatch = true
                        }
                    case .supermarket, .grocery:
                        if poiName.contains("woolworths") || poiName.contains("coles") ||
                           poiName.contains("aldi") || poiName.contains("iga") ||
                           poiName.contains("costco") || poiName.contains("supermarket") ||
                           poiName.contains("grocery") || poiName.contains("market") ||
                           poiName.contains("walmart") || poiName.contains("tesco") ||
                           poiName.contains("sainsbury") || poiName.contains("kroger") {
                            isMatch = true
                        }
                    default:
                        break
                    }

                    if isMatch && !matchingPOIs.contains(poi) {
                        matchingPOIs.append(poi)
                        break
                    }
                }
            }

            return matchingPOIs
        } catch {
            print("Error fetching POIs: \(error)")
            return []
        }
    }

    /// Generates a display label for a smart notification task
    /// - Parameters:
    ///   - taskTitle: The original task title
    ///   - category: The detected location category
    ///   - distance: The notification distance in meters
    /// - Returns: A formatted display label
    static func generateSmartLabel(taskTitle: String, category: LocationCategory?, distance: Int) -> String {
        guard let category = category else {
            return taskTitle
        }
        return "\(taskTitle) when \(distance)m away from \(category.displayName)"
    }

    /// Returns the primary category for a task (first match)
    static func primaryCategory(for title: String) -> LocationCategory? {
        return analyzeTask(title: title).first
    }
}
