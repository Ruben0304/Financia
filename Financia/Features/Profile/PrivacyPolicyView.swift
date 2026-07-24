import SwiftUI

/// In-app privacy policy. Kept self-contained (no network) so there is always an
/// accessible privacy policy inside the app. The same content is mirrored in
/// `privacy-policy.html` for the public URL required by App Store Connect.
struct PrivacyPolicyView: View {
    private let lastUpdated = "7 de julio de 2026"
    private let contactEmail = "rubianclaude@gmail.com"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Política de Privacidad")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(DarkFinanceColors.primaryText)
                    Text("Última actualización: \(lastUpdated)")
                        .font(.footnote)
                        .foregroundColor(DarkFinanceColors.secondaryText)
                }

                intro

                ForEach(sections) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(section.title)
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(DarkFinanceColors.primaryText)
                        Text(section.body)
                            .font(.system(size: 15))
                            .foregroundColor(DarkFinanceColors.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Contacto")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(DarkFinanceColors.primaryText)
                    Text("Si tienes dudas sobre esta política o sobre tus datos, escríbenos a:")
                        .font(.system(size: 15))
                        .foregroundColor(DarkFinanceColors.secondaryText)
                    Link(contactEmail, destination: URL(string: "mailto:\(contactEmail)")!)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(DarkFinanceColors.primaryAccent)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(DarkFinanceColors.background.ignoresSafeArea())
        .navigationTitle("Privacidad")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var intro: some View {
        Text("FinancIA es una app de finanzas personales. Esta política explica qué datos recogemos, para qué los usamos y qué control tienes sobre ellos. Diseñamos la app para pedir solo lo necesario: no vendemos tus datos ni los usamos para publicidad ni seguimiento de terceros.")
            .font(.system(size: 15))
            .foregroundColor(DarkFinanceColors.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
    }

    private struct Section: Identifiable {
        let id = UUID()
        let title: String
        let body: String
    }

    private var sections: [Section] {
        [
            Section(
                title: "1. Datos que recogemos",
                body: """
                • Identidad: al iniciar sesión con Apple guardamos el identificador anónimo que Apple nos entrega y, si lo compartes, tu nombre. No recibimos tu correo real salvo que Apple te lo pida compartir.
                • Información financiera: las transacciones, carteras, deudas, préstamos, presupuestos, metas de ahorro, patrimonio y suscripciones que tú introduces.
                • Contenido que aportas: el texto de tu perfil (situación y estrategia financiera), notas, mensajes al asistente y fotos que subas (avatar, recibos, imágenes de metas de ahorro).
                • Datos técnicos mínimos: preferencias locales de la app y marcas de tiempo de archivos para el funcionamiento normal.
                """
            ),
            Section(
                title: "2. Para qué usamos tus datos",
                body: """
                Usamos tus datos únicamente para ofrecerte la app: mostrar tus finanzas, calcular balances y estadísticas, generar análisis con el asistente FinancIA, extraer información de recibos y sincronizar tu información entre tus sesiones. No usamos tus datos para seguimiento entre apps ni con fines publicitarios.
                """
            ),
            Section(
                title: "3. Inteligencia artificial",
                body: """
                Algunas funciones (chat del asistente, extracción de recibos y análisis de deudas) envían tu información financiera y, cuando corresponde, las fotos de recibos a nuestro servidor, que las procesa mediante modelos de IA para generarte respuestas y sugerencias. Esta información se procesa para darte el resultado que pediste y no se usa para entrenar modelos ni con fines ajenos a la app.
                """
            ),
            Section(
                title: "4. Almacenamiento y sincronización",
                body: """
                Tus datos se guardan en tu dispositivo y en nuestro servidor (alojado en Railway), donde quedan asociados a tu identificador de usuario para que puedas acceder a ellos. Las comunicaciones con el servidor se realizan sobre conexiones cifradas (HTTPS).
                """
            ),
            Section(
                title: "5. Conexión con Claude (MCP)",
                body: """
                Si activas “Conectar con Claude”, generamos un token que te permite acceder a tus propios datos de FinancIA desde Claude. Tú controlas ese acceso: el token solo expone tu información y puedes solicitar su revocación escribiéndonos.
                """
            ),
            Section(
                title: "6. Compartir con terceros",
                body: """
                No vendemos ni cedemos tus datos. Solo los comparten los proveedores necesarios para operar la app (por ejemplo, la infraestructura del servidor y los servicios de IA que procesan tus solicitudes), y únicamente para prestarte el servicio.
                """
            ),
            Section(
                title: "7. Tus derechos y el control de tus datos",
                body: """
                Puedes editar o borrar tus datos dentro de la app en cualquier momento. La opción “Eliminar cuenta” borra de forma permanente toda tu información de nuestro servidor. También puedes activar el bloqueo con Face ID, Touch ID o código para proteger el acceso a la app.
                """
            ),
            Section(
                title: "8. Menores",
                body: """
                FinancIA no está dirigida a menores de 13 años y no recogemos deliberadamente datos de menores.
                """
            ),
            Section(
                title: "9. Cambios en esta política",
                body: """
                Podemos actualizar esta política ocasionalmente. Publicaremos la versión vigente en la app y actualizaremos la fecha indicada arriba.
                """
            )
        ]
    }
}
