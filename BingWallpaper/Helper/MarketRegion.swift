//
//  MarketRegion.swift
//  BingWallpaper
//
//  Created by AI Assistant on 2026.
//

import Foundation

struct MarketRegion: Identifiable, Hashable {
    let id: String // Market code (e.g., "en-US")
    let name: String // Display name (e.g., "United States")
    let flag: String // Emoji flag
    
    var code: String { id }
    
    static let allRegions: [MarketRegion] = [
        // Global/English
        MarketRegion(id: "en-AU", name: "Australia", flag: "🇦🇺"),
        MarketRegion(id: "en-CA", name: "Canada", flag: "🇨🇦"),
        MarketRegion(id: "en-IN", name: "India", flag: "🇮🇳"),
        MarketRegion(id: "en-GB", name: "United Kingdom", flag: "🇬🇧"),
        MarketRegion(id: "en-US", name: "United States", flag: "🇺🇸"),
        
        // Americas
        MarketRegion(id: "es-AR", name: "Argentina", flag: "🇦🇷"),
        MarketRegion(id: "pt-BR", name: "Brazil", flag: "🇧🇷"),
        MarketRegion(id: "es-CL", name: "Chile", flag: "🇨🇱"),
        MarketRegion(id: "es-CO", name: "Colombia", flag: "🇨🇴"),
        MarketRegion(id: "es-MX", name: "Mexico", flag: "🇲🇽"),
        MarketRegion(id: "es-PE", name: "Peru", flag: "🇵🇪"),
        
        // Europe
        MarketRegion(id: "de-AT", name: "Austria", flag: "🇦🇹"),
        MarketRegion(id: "nl-BE", name: "Belgium (Dutch)", flag: "🇧🇪"),
        MarketRegion(id: "fr-BE", name: "Belgium (French)", flag: "🇧🇪"),
        MarketRegion(id: "bg-BG", name: "Bulgaria", flag: "🇧🇬"),
        MarketRegion(id: "hr-HR", name: "Croatia", flag: "🇭🇷"),
        MarketRegion(id: "cs-CZ", name: "Czech Republic", flag: "🇨🇿"),
        MarketRegion(id: "da-DK", name: "Denmark", flag: "🇩🇰"),
        MarketRegion(id: "fi-FI", name: "Finland", flag: "🇫🇮"),
        MarketRegion(id: "fr-FR", name: "France", flag: "🇫🇷"),
        MarketRegion(id: "de-DE", name: "Germany", flag: "🇩🇪"),
        MarketRegion(id: "el-GR", name: "Greece", flag: "🇬🇷"),
        MarketRegion(id: "hu-HU", name: "Hungary", flag: "🇭🇺"),
        MarketRegion(id: "it-IT", name: "Italy", flag: "🇮🇹"),
        MarketRegion(id: "nl-NL", name: "Netherlands", flag: "🇳🇱"),
        MarketRegion(id: "nb-NO", name: "Norway", flag: "🇳🇴"),
        MarketRegion(id: "pl-PL", name: "Poland", flag: "🇵🇱"),
        MarketRegion(id: "pt-PT", name: "Portugal", flag: "🇵🇹"),
        MarketRegion(id: "ro-RO", name: "Romania", flag: "🇷🇴"),
        MarketRegion(id: "ru-RU", name: "Russia", flag: "🇷🇺"),
        MarketRegion(id: "sr-RS", name: "Serbia", flag: "🇷🇸"),
        MarketRegion(id: "sk-SK", name: "Slovakia", flag: "🇸🇰"),
        MarketRegion(id: "sl-SI", name: "Slovenia", flag: "🇸🇮"),
        MarketRegion(id: "es-ES", name: "Spain", flag: "🇪🇸"),
        MarketRegion(id: "sv-SE", name: "Sweden", flag: "🇸🇪"),
        MarketRegion(id: "fr-CH", name: "Switzerland (French)", flag: "🇨🇭"),
        MarketRegion(id: "de-CH", name: "Switzerland (German)", flag: "🇨🇭"),
        MarketRegion(id: "uk-UA", name: "Ukraine", flag: "🇺🇦"),
        
        // Asia Pacific
        MarketRegion(id: "zh-CN", name: "China", flag: "🇨🇳"),
        MarketRegion(id: "zh-HK", name: "Hong Kong", flag: "🇭🇰"),
        MarketRegion(id: "zh-TW", name: "Taiwan", flag: "🇹🇼"),
        MarketRegion(id: "id-ID", name: "Indonesia", flag: "🇮🇩"),
        MarketRegion(id: "ja-JP", name: "Japan", flag: "🇯🇵"),
        MarketRegion(id: "ko-KR", name: "Korea", flag: "🇰🇷"),
        MarketRegion(id: "ms-MY", name: "Malaysia", flag: "🇲🇾"),
        MarketRegion(id: "en-PH", name: "Philippines", flag: "🇵🇭"),
        MarketRegion(id: "en-SG", name: "Singapore", flag: "🇸🇬"),
        MarketRegion(id: "th-TH", name: "Thailand", flag: "🇹🇭"),
        MarketRegion(id: "vi-VN", name: "Vietnam", flag: "🇻🇳"),
        
        // Middle East & Africa
        MarketRegion(id: "ar-EG", name: "Egypt", flag: "🇪🇬"),
        MarketRegion(id: "he-IL", name: "Israel", flag: "🇮🇱"),
        MarketRegion(id: "ar-SA", name: "Saudi Arabia", flag: "🇸🇦"),
        MarketRegion(id: "en-ZA", name: "South Africa", flag: "🇿🇦"),
        MarketRegion(id: "tr-TR", name: "Turkey", flag: "🇹🇷"),
        MarketRegion(id: "ar-AE", name: "UAE", flag: "🇦🇪")
    ]
    
    /// Popular regions for quick access
    static let popularRegions: [MarketRegion] = [
        region(for: "en-US")!,
        region(for: "en-GB")!,
        region(for: "de-DE")!,
        region(for: "fr-FR")!,
        region(for: "ja-JP")!,
        region(for: "zh-CN")!,
        region(for: "ko-KR")!,
        region(for: "vi-VN")!
    ]
    
    static func region(for code: String) -> MarketRegion? {
        return allRegions.first { $0.id == code }
    }
    
    var displayName: String {
        return "\(flag) \(name)"
    }
}
