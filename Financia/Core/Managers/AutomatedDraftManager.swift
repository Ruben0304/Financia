import Foundation
import Combine
import SwiftData

@MainActor
final class AutomatedDraftManager: ObservableObject {
    static let shared = AutomatedDraftManager()

    @Published private(set) var drafts: [AutomatedTransactionDraft] = []
    @Published var lastError: String?

    private let container = PersistenceManager.shared.container
    private let api = APIClient.shared
    private let endpoint = "/automated-drafts/"

    private init() {
        loadFromCache()
        Task { await refreshFromBackend() }
    }

    private func loadFromCache() {
        let context = ModelContext(container)
        do {
            drafts = try context.fetch(FetchDescriptor<AutomatedTransactionDraftEntity>())
                .map(Self.makeDraft(from:)).sorted { $0.updatedAt > $1.updatedAt }
        } catch { print("AutomatedDraftManager cache read failed: \(error)") }
    }

    func refreshFromBackend() async {
        do {
            let remote: [AutomatedTransactionDraft] = try await api.getList(endpoint)
            drafts = remote.sorted { $0.updatedAt > $1.updatedAt }
            replaceCache(with: drafts)
        } catch APIError.networkUnavailable {
        } catch { lastError = error.localizedDescription }
    }

    func loadDrafts() { Task { await refreshFromBackend() } }

    // MARK: - Import (de-duplicating)

    func importPayload(_ payload: AutomatedDraftImportPayload) {
        let now = Date()
        let trimmedMessage = payload.rawMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty, payload.amount > 0 else { return }

        if let i = drafts.firstIndex(where: { matchesExistingDraft($0, payload: payload) }) {
            var d = drafts[i]
            d.sourceKind = payload.sourceKind
            d.type = payload.typeOverride ?? payload.sourceKind.defaultTransactionType
            d.amount = payload.amount
            d.currency = payload.currency
            d.occurredAt = payload.occurredAt
            d.rawMessage = trimmedMessage
            d.suggestedName = payload.suggestedName
            d.counterpartyName = payload.counterpartyName
            d.note = payload.note
            d.externalIdentifier = payload.externalIdentifier
            d.updatedAt = now
            drafts[i] = d
            drafts.sort { $0.updatedAt > $1.updatedAt }
            insertCache(d)
            pushUpdate(d)
        } else {
            let d = AutomatedTransactionDraft(
                sourceKind: payload.sourceKind, type: payload.typeOverride,
                amount: payload.amount, currency: payload.currency,
                occurredAt: payload.occurredAt, rawMessage: trimmedMessage,
                suggestedName: payload.suggestedName, counterpartyName: payload.counterpartyName,
                note: payload.note, externalIdentifier: payload.externalIdentifier,
                createdAt: now, updatedAt: now
            )
            drafts.append(d)
            drafts.sort { $0.updatedAt > $1.updatedAt }
            insertCache(d)
            pushCreate(d)
        }
    }

    func importPayloads(_ payloads: [AutomatedDraftImportPayload]) { payloads.forEach(importPayload) }

    @discardableResult
    func importRawMessage(_ rawMessage: String, occurredAt: Date = Date()) async -> Bool {
        guard let payload = await AutomatedDraftMessageParser.parse(message: rawMessage, occurredAt: occurredAt) else { return false }
        importPayload(payload)
        return true
    }

    @discardableResult
    func importJSONString(_ jsonString: String) -> Bool {
        guard let data = jsonString.data(using: .utf8) else { return false }
        return importPayloadData(data)
    }

    func importFromURL(_ url: URL) -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return false }
        let items = components.queryItems ?? []
        if let payload64 = items.first(where: { $0.name == "payload64" })?.value,
           let data = Self.decodeBase64URLString(payload64) { return importPayloadData(data) }
        if let payload = items.first(where: { $0.name == "payload" })?.value,
           let data = payload.data(using: .utf8) { return importPayloadData(data) }
        return false
    }

    func updateSuggestedName(for draftID: UUID, name: String) {
        guard let i = drafts.firstIndex(where: { $0.id == draftID }) else { return }
        var d = drafts[i]
        d.suggestedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        d.updatedAt = Date()
        drafts[i] = d
        drafts.sort { $0.updatedAt > $1.updatedAt }
        insertCache(d)
        pushUpdate(d)
    }

    func deleteDraft(id: UUID) {
        guard let d = drafts.first(where: { $0.id == id }) else { return }
        drafts.removeAll { $0.id == id }
        deleteCache(id: id)
        Task { [weak self] in
            guard let self else { return }
            do { _ = try await self.api.delete("\(self.endpoint)\(id.uuidString)") }
            catch {
                self.drafts.append(d)
                self.insertCache(d)
                self.lastError = error.localizedDescription
            }
        }
    }

    func prefill(for draft: AutomatedTransactionDraft) -> ReceiptPrefill {
        ReceiptPrefill(amount: draft.amount, date: draft.occurredAt, description: draft.resolvedName,
                       lugar: nil, subitems: [], currencyCode: draft.currency.rawValue)
    }

    // MARK: - Backend writes

    private func pushCreate(_ draft: AutomatedTransactionDraft) {
        Task { [weak self] in
            guard let self else { return }
            do { let _: Empty = try await self.api.post(self.endpoint, body: draft) }
            catch { self.lastError = error.localizedDescription }
        }
    }

    private func pushUpdate(_ draft: AutomatedTransactionDraft) {
        Task { [weak self] in
            guard let self else { return }
            do { let _: Empty = try await self.api.put("\(self.endpoint)\(draft.id.uuidString)", body: draft) }
            catch { self.lastError = error.localizedDescription }
        }
    }

    // MARK: - Helpers

    private func importPayloadData(_ data: Data) -> Bool {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let payload = try? decoder.decode(AutomatedDraftImportPayload.self, from: data) {
            importPayload(payload); return true
        }
        if let payloads = try? decoder.decode([AutomatedDraftImportPayload].self, from: data) {
            importPayloads(payloads); return true
        }
        return false
    }

    private func matchesExistingDraft(_ draft: AutomatedTransactionDraft, payload: AutomatedDraftImportPayload) -> Bool {
        if let externalIdentifier = payload.externalIdentifier, !externalIdentifier.isEmpty,
           draft.externalIdentifier == externalIdentifier { return true }
        return draft.sourceKind == payload.sourceKind && draft.amount == payload.amount &&
               draft.currency == payload.currency && draft.rawMessage == payload.rawMessage
    }

    private static func decodeBase64URLString(_ value: String) -> Data? {
        var normalized = value.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        let remainder = normalized.count % 4
        if remainder > 0 { normalized += String(repeating: "=", count: 4 - remainder) }
        return Data(base64Encoded: normalized)
    }

    // MARK: - Cache

    private func replaceCache(with items: [AutomatedTransactionDraft]) {
        let context = ModelContext(container)
        do {
            try context.fetch(FetchDescriptor<AutomatedTransactionDraftEntity>()).forEach { context.delete($0) }
            items.map(Self.makeEntity).forEach { context.insert($0) }
            try context.save()
        } catch { print("AutomatedDraftManager cache replace failed: \(error)") }
    }

    private func insertCache(_ d: AutomatedTransactionDraft) {
        let context = ModelContext(container); let id = d.id
        do {
            try context.fetch(FetchDescriptor<AutomatedTransactionDraftEntity>(predicate: #Predicate { $0.id == id })).forEach { context.delete($0) }
            context.insert(Self.makeEntity(from: d))
            try context.save()
        } catch {}
    }

    private func deleteCache(id: UUID) {
        let context = ModelContext(container)
        do {
            try context.fetch(FetchDescriptor<AutomatedTransactionDraftEntity>(predicate: #Predicate { $0.id == id })).forEach { context.delete($0) }
            try context.save()
        } catch {}
    }

    private static func makeDraft(from e: AutomatedTransactionDraftEntity) -> AutomatedTransactionDraft {
        AutomatedTransactionDraft(
            id: e.id, sourceKind: AutomatedDraftSourceKind(rawValue: e.sourceKindRaw) ?? .incomingTransfer,
            type: TransactionType(rawValue: e.typeRaw) ?? .income,
            amount: e.amount, currency: Currency(rawValue: e.currencyRaw) ?? .cup,
            occurredAt: e.occurredAt, rawMessage: e.rawMessage,
            suggestedName: e.suggestedName, counterpartyName: e.counterpartyName,
            note: e.note, externalIdentifier: e.externalIdentifier,
            createdAt: e.createdAt, updatedAt: e.updatedAt
        )
    }

    private static func makeEntity(from d: AutomatedTransactionDraft) -> AutomatedTransactionDraftEntity {
        AutomatedTransactionDraftEntity(
            id: d.id, sourceKindRaw: d.sourceKind.rawValue, typeRaw: d.type.rawValue,
            amount: d.amount, currencyRaw: d.currency.rawValue,
            occurredAt: d.occurredAt, rawMessage: d.rawMessage,
            suggestedName: d.suggestedName, counterpartyName: d.counterpartyName,
            note: d.note, externalIdentifier: d.externalIdentifier,
            createdAt: d.createdAt, updatedAt: d.updatedAt
        )
    }
}
