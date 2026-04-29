//
//  Item.swift
//  monClips
//
//  Created by Matheus Diniz  on 27/04/26.
//

import Foundation
import SwiftData

enum ClipType: String, Codable {
    case link
    case image
    case code
    case email
    case text
}

@Model
final class ClipItem {
    @Attribute(.unique) var text: String
    var timestamp: Date
    var isPinned: Bool
    
    var type: ClipType {
        let lowerText = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 1. Image Detection (Direct links to images)
        let imageExtensions = [".jpg", ".jpeg", ".png", ".gif", ".webp", ".bmp", ".tiff"]
        if imageExtensions.contains(where: { lowerText.hasSuffix($0) }) {
            return .image
        }
        
        // 2. Link Detection
        if lowerText.hasPrefix("http") || lowerText.hasPrefix("www.") {
            return .link
        }
        
        // 3. Email Detection
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format:"SELF MATCHES %@", emailRegex)
        if emailPredicate.evaluate(with: text) {
            return .email
        }
        
        // 4. Code Detection (Heuristics)
        let codeKeywords = ["func ", "var ", "let ", "class ", "struct ", "import ", "function ", "const ", "return ", "if ", "else ", "public ", "private "]
        let hasCodeKeyword = codeKeywords.contains { text.contains($0) }
        let hasCodeBrackets = text.contains("{") && text.contains("}")
        let hasSemicolons = text.contains(";")
        
        if hasCodeKeyword || (hasCodeBrackets && hasSemicolons) || (text.components(separatedBy: "\n").count > 2 && hasCodeBrackets) {
            return .code
        }
        
        return .text
    }
                                                                              
    init(text: String, timestamp: Date = Date(), isPinned: Bool = false) {
        self.text = text
        self.timestamp = timestamp
        self.isPinned = isPinned
    }
}