import Foundation
import SwiftData

@MainActor
final class AutomatedDraftManager: ObservableObject {
    static let shared = AutomatedDraftManager()

    @Published private(set) var drafts: [AutomatedTransactionDraft] = []

    private let container = PersistenceManager.shared.container

    private init() {
        loadDrafts()
    }

    func loadDrafts() {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<AutomatedTransactionDraftEntity>()

        do {
            drafts = try context.fetch(descriptor)
                .map(Self.makeDraft(from:))
                .sorted { $0.updatedAt > $1.updatedAt }
        } catch {
            print("Error loading automated drafts: \(error)")
            drafts = []
        }
    }

    func importPayload(_ payload: AutomatedDraftImportPayload) {
        let now = Date()
        let trimmedMessage = payload.rawMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty, payload.amount > 0 else { return }

        if let index = drafts.firstIndex(where: { matchesExistingDraft($0, payload: payload) }) {
            drafts[index].sourceKind = payload.sourceKind
            drafts[index].type = payload.typeOverride ?? payload.sourceKind.defaultTransactionType
            drafts[index].amount = payload.amount
            drafts[index].currency = payload.currency
            drafts[index].occurredAt = payload.occurredAt
            drafts[index].rawMessage = trimmedMessage
            drafts[index].suggestedName = payload.suggestedName
            drafts[index].counterpartyName = payload.counterpartyName
            drafts[index].note = payload.note
            drafts[index].externalIdentifier = payload.externalIdentifier
            drafts[index].updatedAt = now
        } else {
            drafts.append(
                AutomatedTransactionDraft(
                    sourceKind: payload.sourceKind,
                    type: payload.typeOverride,
                    amount: payload.amount,
                    currency: payload.currency,
                    occurredAt: payload.occurredAt,
                    rawMessage: trimmedMessage,
                    suggestedName: payload.suggestedName,
                    counterpartyName: payload.counterpartyName,
                    note: payload.note,
                    externalIdentifier: payload.externalIdentifier,
                    createdAt: now,
                    updatedAt: now
                )
            )
        }

        drafts.sort { $0.updatedAt > $1.updatedAt }
        saveDrafts()
    }

    func importPayloads(_ payloads: [AutomatedDraftImportPayload]) {
        payloads.forEach(importPayload)
    }

    func importFromURL(_ url: URL) -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return false
        }

        let items = components.queryItems ?? []

        if let payload64 = items.first(where: { $0.name == "payload64" })?.value,
           let data = Self.decodeBase64URLString(payload64) {
            return importPayloadData(data)
        }

        if let payload = items.first(where: { $0.name == "payload" })?.value,
           let data = payload.data(using: .utf8) {
            return importPayloadData(data)
        }

        return false
    }

    func updateSuggestedName(for draftID: UUID, name: String) {
        guard let index = drafts.firstIndex(where: { $0.id == draftID }) else { return }
        drafts[index].suggestedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        drafts[index].updatedAt = Date()
        drafts.sort { $0.updatedAt > $1.updatedAt }
        saveDrafts()
    }

    func deleteDraft(id: UUID) {
        drafts.removeAll { $0.id == id }
        saveDrafts()
    }

    func prefill(for draft: AutomatedTransactionDraft) -> ReceiptPrefill {
        ReceiptPrefill(
            amount: draft.amount,
            date: draft.occurredAt,
            description: draft.resolvedName,
            lugar: nil,
            subitems: [],
            currencyCode: draft.currency.rawValue
        )
    }

    private func importPayloadData(_ data: Data) -> Bool {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if let payload = try? decoder.decode(AutomatedDraftImportPayload.self, from: data) {
            importPayload(payload)
            return true
        }

        if let payloads = try? decoder.decode([AutomatedDraftImportPayload].self, from: data) {
            importPayloads(payloads)
            return true
        }

        return false
    }

    private func saveDrafts() {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<AutomatedTransactionDraftEntity>()

        do {
            let existing = try context.fetch(descriptor)
            existing.forEach { context.delete($0) }
            drafts.map(Self.makeEntity).forEach { context.insert($0) }
            try context.save()
        } catch {
            print("Error saving automated drafts: \(error)")
        }
    }

    private func matchesExistingDraft(_ draft: AutomatedTransactionDraft, payload: AutomatedDraftImportPayload) -> Bool {
        if let externalIdentifier = payload.externalIdentifier,
           !externalIdentifier.isEmpty,
           draft.externalIdentifier == externalIdentifier {
            return true
        }

        return draft.sourceKind == payload.sourceKind &&
            draft.amount == payload.amount &&
            draft.currency == payload.currency &&
            draft.rawMessage == payload.rawMessage
    }

    private static func decodeBase64URLString(_ value: String) -> Data? {
        var normalized = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        let remainder = normalized.count % 4
        if remainder > 0 {
            normalized += String(repeating: "=", count: 4 - remainder)
        }

        return Data(base64Encoded: normalized)
    }

    private static func makeDraft(from entity: AutomatedTransactionDraftEntity) -> AutomatedTransactionDraft {
        AutomatedTransactionDraft(
            id: entity.id,
            sourceKind: AutomatedDraftSourceKind(rawValue: entity.sourceKindRaw) ?? .incomingTransfer,
            type: TransactionType(rawValue: entity.typeRaw) ?? .income,
            amount: entity.amount,
            currency: Currency(rawValue: entity.currencyRaw) ?? .cup,
            occurredAt: entity.occurredAt,
            rawMessage: entity.rawMessage,
            suggestedName: entity.suggestedName,
            counterpartyName: entity.counterpartyName,
            note: entity.note,
            externalIdentifier: entity.externalIdentifier,
            createdAt: entity.createdAt,
            updatedAt: entity.updatedAt
        )
    }

    private static func makeEntity(from draft: AutomatedTransactionDraft) -> AutomatedTransactionDraftEntity {
        AutomatedTransactionDraftEntity(
            id: draft.id,
            sourceKindRaw: draft.sourceKind.rawValue,
            typeRaw: draft.type.rawValue,
            amount: draft.amount,
            currencyRaw: draft.currency.rawValue,
            occurredAt: draft.occurredAt,
            rawMessage: draft.rawMessage,
            suggestedName: draft.suggestedName,
            counterpartyName: draft.counterpartyName,
            note: draft.note,
            externalIdentifier: draft.externalIdentifier,
            createdAt: draft.createdAt,
            updatedAt: draft.updatedAt
        )
    }
}
