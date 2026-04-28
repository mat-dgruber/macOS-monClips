//
//  Item.swift
//  monClips
//
//  Created by Matheus Diniz  on 27/04/26.
//

import Foundation
import SwiftData

@Model
  final class ClipItem {
      @Attribute(.unique) var text: String
      var timestamp: Date
      var isPinned: Bool // ADICIONE ESTA LINHA
                                                                                
      // E ATUALIZE O INIT PARA:
      init(text: String, timestamp: Date = Date(), isPinned: Bool = false) {
          self.text = text
          self.timestamp = timestamp
          self.isPinned = isPinned
      }
  }
