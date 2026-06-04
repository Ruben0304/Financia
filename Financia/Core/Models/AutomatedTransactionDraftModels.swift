import Foundation

enum AutomatedDraftSourceKind: String, Codable, CaseIterable {
    case incomingTransfer
    case outgoingTransfer
    case mobileTopUp

    var title: String {
        switch self {
        case .incomingTransfer:
            return "Transferencia recibida"
        case .outgoingTransfer:
            return "Transferencia enviada"
        case .mobileTopUp:
            return "Recarga movil"
        }
    }

    var defaultTransactionType: TransactionType {
        switch self {
        case .incomingTransfer:
            return .income
        case .outgoingTransfer, .mobileTopUp:
            return .expense
        }
    }

    var systemImage: String {
        switch self {
        case .incomingTransfer:
            return "arrow.down.left.circle.fill"
        case .outgoingTransfer:
            return "arrow.up.right.circle.fill"
        case .mobileTopUp:
            return "iphone.and.arrow.forward"
        }
    }
}

struct AutomatedTransactionDraft: Identifiable, Codable, Hashable {
    var id: UUID
    var sourceKind: AutomatedDraftSourceKind
    var type: TransactionType
    var amount: Double
    var currency: Currency
    var occurredAt: Date
    var rawMessage: String
    var suggestedName: String?
    var counterpartyName: String?
    var note: String?
    var externalIdentifier: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        sourceKind: AutomatedDraftSourceKind,
        type: TransactionType? = nil,
        amount: Double,
        currency: Currency,
        occurredAt: Date,
        rawMessage: String,
        suggestedName: String? = nil,
        counterpartyName: String? = nil,
        note: String? = nil,
        externalIdentifier: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.sourceKind = sourceKind
        self.type = type ?? sourceKind.defaultTransactionType
        self.amount = amount
        self.currency = currency
        self.occurredAt = occurredAt
        self.rawMessage = rawMessage
        self.suggestedName = suggestedName
        self.counterpartyName = counterpartyName
        self.note = note
        self.externalIdentifier = externalIdentifier
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var resolvedName: String {
        let trimmedName = suggestedName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedName.isEmpty {
            return trimmedName
        }

        let trimmedCounterparty = counterpartyName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedCounterparty.isEmpty {
            return trimmedCounterparty
        }

        return sourceKind.title
    }
}

struct AutomatedDraftImportPayload: Codable {
    var sourceKind: AutomatedDraftSourceKind
    var amount: Double
    var currency: Currency
    var occurredAt: Date
    var rawMessage: String
    var suggestedName: String?
    var counterpartyName: String?
    var note: String?
    var externalIdentifier: String?
    var typeOverride: TransactionType?
}
