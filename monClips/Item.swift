//
//  Item.swift
//  monClips
//
//  Created by Matheus Diniz  on 27/04/26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
