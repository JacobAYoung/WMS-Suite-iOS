//
//  OrderNoteModel.swift
//  WMS Suite
//
//  Created by Jacob Young on 12/19/25.
//


//
//  OrderNoteModel.swift
//  WMS Suite
//
//  Model for order notes display (used before Core Data entity is created)
//

import Foundation

struct OrderNoteModel: Identifiable {
    let id: UUID
    let noteText: String
    let createdDate: Date
    let noteType: OrderNoteType
    let userName: String?
    
    init(noteText: String, noteType: OrderNoteType, userName: String? = nil) {
        self.id = UUID()
        self.noteText = noteText
        self.createdDate = Date()
        self.noteType = noteType
        self.userName = userName
    }
}

enum OrderNoteType: String {
    case general = "general"
    case prioritySet = "priority_set"
    case priorityRemoved = "priority_removed"
    case attentionSet = "attention_set"
    case attentionRemoved = "attention_removed"
    case statusChanged = "status_changed"
    
    var icon: String {
        switch self {
        case .general:
            return "note.text"
        case .prioritySet:
            return "exclamationmark.triangle.fill"
        case .priorityRemoved:
            return "checkmark.circle"
        case .attentionSet:
            return "exclamationmark.circle.fill"
        case .attentionRemoved:
            return "checkmark.circle"
        case .statusChanged:
            return "arrow.triangle.2.circlepath"
        }
    }
    
    var displayText: String {
        switch self {
        case .general:
            return "Note added"
        case .prioritySet:
            return "Marked as priority"
        case .priorityRemoved:
            return "Priority removed"
        case .attentionSet:
            return "Needs attention"
        case .attentionRemoved:
            return "Attention resolved"
        case .statusChanged:
            return "Status changed"
        }
    }
}
