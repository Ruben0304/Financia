import AppIntents

struct ImportAutomatedDraftIntent: AppIntent {
    static let title: LocalizedStringResource = "Importar borrador automatizado"
    static let description = IntentDescription("Guarda un borrador de ingreso o gasto desde una automatización, sin abrir Financia.")
    static let openAppWhenRun = false

    @Parameter(title: "JSON del borrador")
    var payloadJSON: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let imported = await MainActor.run {
            AutomatedDraftManager.shared.importJSONString(payloadJSON)
        }

        if imported {
            return .result(dialog: IntentDialog("Borrador guardado en Financia."))
        } else {
            return .result(dialog: IntentDialog("No se pudo leer el JSON del borrador."))
        }
    }
}

struct FinanciaAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        [
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
