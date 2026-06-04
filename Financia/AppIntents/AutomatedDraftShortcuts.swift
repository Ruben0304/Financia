import AppIntents

struct ImportAutomatedDraftIntent: AppIntent {
    static let title: LocalizedStringResource = "Importar borrador automatizado"
    static let description = IntentDescription("Recibe el mensaje crudo desde una automatización, lo procesa en segundo plano y guarda el borrador en Financia.")
    static let openAppWhenRun = false

    @Parameter(title: "Mensaje")
    var rawMessage: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let imported = await AutomatedDraftManager.shared.importRawMessage(rawMessage)

        if imported {
            return .result(dialog: IntentDialog("Mensaje procesado y borrador guardado en Financia."))
        } else {
            return .result(dialog: IntentDialog("No se pudo procesar el mensaje."))
        }
    }
}

struct FinanciaAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        return [
            AppShortcut(
                intent: ImportAutomatedDraftIntent(),
                phrases: [
                    "Importar borrador en \(.applicationName)",
                    "Guardar borrador en \(.applicationName)"
                ],
                shortTitle: "Importar borrador",
                systemImageName: "sparkles.rectangle.stack"
            )
        ]
    }
}
