//
//  ShareExtensionModels.swift
//  ShareExtension
//
//  Created by Sourabh Mazumder on 8/3/2026.
//

import Foundation

// MARK: - Location Category (self-contained for extension)

enum ShareLocationCategory: String, CaseIterable, Codable {
    case pharmacy
    case fuelStation = "fuel_station"
    case supermarket
    case grocery
    case restaurant
    case bank
    case postOffice = "post_office"
    case hardware
    case electronics
    case clothing

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
                    "snacks", "drinks", "beverages", "juice", "water", "soda", "coffee", "tea",
                    "tomatoes", "tomato", "onion", "onions", "potato", "potatoes", "flour", "sugar", "salt",
                    "oil", "yogurt", "cream"]
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

    static func primaryCategory(for text: String) -> ShareLocationCategory? {
        let lowered = text.lowercased()
        var best: (category: ShareLocationCategory, score: Int)?
        for category in Self.allCases {
            for keyword in category.keywords {
                if lowered.contains(keyword) {
                    let score = keyword.count
                    if best == nil || score > best!.score {
                        best = (category, score)
                    }
                }
            }
        }
        return best?.category
    }
}

// MARK: - Task Group

struct ShareTaskGroup: Identifiable, Codable {
    let id: UUID
    var groupTitle: String
    var locationCategory: ShareLocationCategory?
    var items: [String]

    init(groupTitle: String, locationCategory: ShareLocationCategory?, items: [String]) {
        self.id = UUID()
        self.groupTitle = groupTitle
        self.locationCategory = locationCategory
        self.items = items
    }

    static func groupByKeywords(_ items: [String]) -> [ShareTaskGroup] {
        var categoryItems: [ShareLocationCategory: [String]] = [:]
        var uncategorized: [String] = []

        for item in items {
            if let category = ShareLocationCategory.primaryCategory(for: item) {
                categoryItems[category, default: []].append(item)
            } else {
                uncategorized.append(item)
            }
        }

        var groups: [ShareTaskGroup] = []

        // Merge grocery and supermarket
        let groceryItems = (categoryItems[.grocery] ?? []) + (categoryItems[.supermarket] ?? [])
        if !groceryItems.isEmpty {
            groups.append(ShareTaskGroup(groupTitle: "Grocery Shopping", locationCategory: .supermarket, items: groceryItems))
            categoryItems.removeValue(forKey: .grocery)
            categoryItems.removeValue(forKey: .supermarket)
        }

        for (category, items) in categoryItems.sorted(by: { $0.value.count > $1.value.count }) {
            groups.append(ShareTaskGroup(
                groupTitle: "\(category.singularDisplayName) Visit",
                locationCategory: category,
                items: items
            ))
        }

        if !uncategorized.isEmpty {
            groups.append(ShareTaskGroup(groupTitle: "Other Tasks", locationCategory: nil, items: uncategorized))
        }

        return groups
    }
}

// MARK: - Shared Import Data (written by extension, read by main app)

struct SharedImportData: Codable {
    let groups: [ShareTaskGroup]
    let timestamp: Date
}

enum SharedStorage {
    static let appGroupID = "group.com.helpingthoughtgames.smart-todo"
    static let importFileName = "PendingImport.json"

    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }

    static func saveImportData(_ data: SharedImportData) -> Bool {
        guard let containerURL = containerURL else { return false }
        let fileURL = containerURL.appendingPathComponent(importFileName)
        do {
            let encoded = try JSONEncoder().encode(data)
            try encoded.write(to: fileURL, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    static func loadImportData() -> SharedImportData? {
        guard let containerURL = containerURL else { return nil }
        let fileURL = containerURL.appendingPathComponent(importFileName)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode(SharedImportData.self, from: data)
        } catch {
            return nil
        }
    }

    static func clearImportData() {
        guard let containerURL = containerURL else { return }
        let fileURL = containerURL.appendingPathComponent(importFileName)
        try? FileManager.default.removeItem(at: fileURL)
    }
}

// MARK: - Text Parsing

enum NotesTextParser {
    static func parseItems(from text: String) -> [String] {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: CharacterSet(charactersIn: "\n,"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .map { line in
                var cleaned = line
                if let range = cleaned.range(of: #"^[\-\*\u2022]\s+"#, options: .regularExpression) {
                    cleaned = String(cleaned[range.upperBound...])
                }
                if let range = cleaned.range(of: #"^\d+[\.\)]\s*"#, options: .regularExpression) {
                    cleaned = String(cleaned[range.upperBound...])
                }
                if let range = cleaned.range(of: #"^\[[ xX]?\]\s*"#, options: .regularExpression) {
                    cleaned = String(cleaned[range.upperBound...])
                }
                return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }
    }
}
