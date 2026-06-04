import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

enum AutomatedDraftMessageParser {
    static func parse(message rawMessage: String, occurredAt: Date = Date()) async -> AutomatedDraftImportPayload? {
        let trimmedMessage = rawMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else { return nil }

        if let aiPayload = await parseWithAppleIntelligence(message: trimmedMessage, occurredAt: occurredAt) {
            return aiPayload
        }

        return parseWithRegex(message: trimmedMessage, occurredAt: occurredAt)
    }

    private static func parseWithRegex(message: String, occurredAt: Date) -> AutomatedDraftImportPayload? {
        let normalized = normalizeWhitespace(in: message)

        if normalized.localizedCaseInsensitiveContains("La Transferencia fue completada") {
            guard
                let amount = extractAmount(after: "Monto:", in: normalized),
                let externalIdentifier = extractValue(after: "Nro. Transaccion:", endingBeforeAnyOf: ["Saldo restante:", "Saldo Restante:", "."], in: normalized)
            else {
                return nil
            }

            let beneficiary = extractValue(after: "Beneficiario:", endingBeforeAnyOf: ["Ordenante:", "Monto:", "Nro. Transaccion:"], in: normalized)

            return AutomatedDraftImportPayload(
                sourceKind: .outgoingTransfer,
                amount: amount,
                currency: .cup,
                occurredAt: occurredAt,
                rawMessage: message,
                suggestedName: AutomatedDraftSourceKind.outgoingTransfer.title,
                counterpartyName: beneficiary,
                note: beneficiary.map { "Beneficiario \($0)" },
                externalIdentifier: externalIdentifier,
                typeOverride: .expense
            )
        }

        if normalized.localizedCaseInsensitiveContains("La recarga se realizo con exito") {
            guard
                let amount = extractAmount(after: "Monto Pagado:", in: normalized),
                let externalIdentifier = extractValue(after: "Id transaccion:", endingBeforeAnyOf: ["Saldo Restante:", "Gracias por utilizar", "."], in: normalized)
            else {
                return nil
            }

            let phone = extractValue(after: "Telefono:", endingBeforeAnyOf: ["Id transaccion:", "Saldo Restante:"], in: normalized)

            return AutomatedDraftImportPayload(
                sourceKind: .mobileTopUp,
                amount: amount,
                currency: .cup,
                occurredAt: occurredAt,
                rawMessage: message,
                suggestedName: AutomatedDraftSourceKind.mobileTopUp.title,
                counterpartyName: phone,
                note: phone.map { "Telefono \($0)" },
                externalIdentifier: externalIdentifier,
                typeOverride: .expense
            )
        }

        if normalized.localizedCaseInsensitiveContains("le ha realizado una transferencia a la cuenta") {
            guard
                let amount = extractTransferReceivedAmount(in: normalized),
                let externalIdentifier = extractValue(after: "Nro. Transaccion", endingBeforeAnyOf: ["Fecha:", "."], in: normalized)
            else {
                return nil
            }

            let senderPhone = extractValue(after: "El titular del telefono", endingBeforeAnyOf: ["le ha realizado una transferencia"], in: normalized)
            let destinationAccount = extractValue(after: "a la cuenta", endingBeforeAnyOf: ["de", "Nro. Transaccion", "Fecha:"], in: normalized)

            return AutomatedDraftImportPayload(
                sourceKind: .incomingTransfer,
                amount: amount,
                currency: .cup,
                occurredAt: occurredAt,
                rawMessage: message,
                suggestedName: AutomatedDraftSourceKind.incomingTransfer.title,
                counterpartyName: senderPhone,
                note: destinationAccount.map { "Cuenta destino \($0)" },
                externalIdentifier: externalIdentifier,
                typeOverride: .income
            )
        }

        return nil
    }

    private static func normalizeWhitespace(in text: String) -> String {
        text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func extractValue(after marker: String, endingBeforeAnyOf endings: [String], in text: String) -> String? {
        guard let markerRange = text.range(of: marker, options: .caseInsensitive) else {
            return nil
        }

        var remainder = String(text[markerRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        let lowerRemainder = remainder.lowercased()

        let endIndex = endings
            .compactMap { ending -> String.Index? in
                guard let range = lowerRemainder.range(of: ending.lowercased()) else { return nil }
                return range.lowerBound
            }
            .min() ?? lowerRemainder.endIndex

        remainder = String(remainder[..<endIndex])
            .trimmingCharacters(in: CharacterSet(charactersIn: " .:"))

        return remainder.isEmpty ? nil : remainder
    }

    private static func extractAmount(after marker: String, in text: String) -> Double? {
        guard let value = extractValue(after: marker, endingBeforeAnyOf: ["CUP", "."], in: text) else {
            return nil
        }

        return parseAmount(value)
    }

    private static func extractTransferReceivedAmount(in text: String) -> Double? {
        guard
            let startRange = text.range(of: " de ", options: .caseInsensitive),
            let cupRange = text.range(of: " CUP", options: .caseInsensitive, range: startRange.upperBound..<text.endIndex)
        else {
            return nil
        }

        let rawAmount = String(text[startRange.upperBound..<cupRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        return parseAmount(rawAmount)
    }

    private static func parseAmount(_ rawValue: String) -> Double? {
        let normalized = rawValue
            .replacingOccurrences(of: "CUP", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: " ."))

        return Double(normalized)
    }

    private static func parseWithAppleIntelligence(message: String, occurredAt: Date) async -> AutomatedDraftImportPayload? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let model = SystemLanguageModel.default

            guard case .available = model.availability else {
                return nil
            }

            let formatter = ISO8601DateFormatter()
            let occurredAtString = formatter.string(from: occurredAt)

            let instructions = """
            Clasifica y extrae un borrador financiero a partir de un SMS bancario cubano.
            Solo existen tres tipos validos: incomingTransfer, outgoingTransfer, mobileTopUp.
            Usa occurredAt exactamente como se te proporciona.
            currency debe ser CUP.
            suggestedName debe ser el titulo humano del tipo.
            typeOverride debe ser income para incomingTransfer y expense para outgoingTransfer o mobileTopUp.
            externalIdentifier debe ser el identificador de transaccion si existe.
            counterpartyName debe ser telefono, beneficiario o remitente si existe.
            note debe ser breve y util para mostrar en la app.
            Si el mensaje no coincide claramente con uno de esos tres tipos, rehusa.
            """

            let session = LanguageModelSession(instructions: instructions)
            let prompt = """
            occurredAt fijo: \(occurredAtString)
            Mensaje:
            \(message)
            """

            do {
                let response = try await session.respond(
                    to: prompt,
                    generating: AIMesssageDraftExtraction.self,
                    options: GenerationOptions(temperature: 0.1)
                )

                return response.content.asPayload(rawMessage: message, occurredAt: occurredAt)
            } catch {
                return nil
            }
        }
        #endif

        return nil
    }
}

#if canImport(FoundationModels)
@available(iOS 26.0, *)
@Generable(description: "Extraccion estructurada de un mensaje financiero para crear un borrador de ingreso o gasto.")
private struct AIMesssageDraftExtraction {
    @Guide(description: "Uno de estos valores exactos: incomingTransfer, outgoingTransfer, mobileTopUp")
    var sourceKind: String

    @Guide(description: "Monto numerico extraido del mensaje")
    var amount: Double

    @Guide(description: "Moneda del mensaje. Para estos casos siempre debe ser CUP")
    var currency: String

    @Guide(description: "Nombre sugerido para el borrador")
    var suggestedName: String

    @Guide(description: "Telefono, beneficiario o contraparte si aparece")
    var counterpartyName: String?

    @Guide(description: "Nota corta y util para la app")
    var note: String?

    @Guide(description: "Numero o id de transaccion")
    var externalIdentifier: String?

    @Guide(description: "income o expense segun el tipo de borrador")
    var typeOverride: String

    func asPayload(rawMessage: String, occurredAt: Date) -> AutomatedDraftImportPayload? {
        guard
            let kind = AutomatedDraftSourceKind(rawValue: sourceKind.trimmingCharacters(in: .whitespacesAndNewlines)),
            let transactionType = TransactionType(rawValue: typeOverride.trimmingCharacters(in: .whitespacesAndNewlines)),
            let currency = Currency(rawValue: currency.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()),
            amount > 0
        else {
            return nil
        }

        return AutomatedDraftImportPayload(
            sourceKind: kind,
            amount: amount,
            currency: currency,
            occurredAt: occurredAt,
            rawMessage: rawMessage,
            suggestedName: suggestedName,
            counterpartyName: counterpartyName,
            note: note,
            externalIdentifier: externalIdentifier,
            typeOverride: transactionType
        )
    }
}
#endif
