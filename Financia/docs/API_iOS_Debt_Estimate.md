# FinancIA API - Guia de Integracion iOS (Estimacion de Deuda)

## Descripcion General

Este endpoint estima el tiempo promedio para pagar una deuda a partir de un prompt con ingresos, gastos,
situacion actual y estrategia financiera.

---

## Base URL

```
https://tu-servidor.com/api/v1/assistant
```

---

## Estimacion de Tiempo de Pago de Deuda

### Endpoint

```
POST /debt/estimate
```

### Request

**Content-Type**: `application/json`

```json
{
  "prompt": "Deuda en USD: 5000. Ingresos 1200/mes, gastos 800/mes. Situacion: ... Estrategia: ..."
}
```

### Response

```json
{
  "moneda": "USD",
  "caracterizacion": "regular",
  "escenarios": [
    {"escenario": "pesimista", "dias_promedio": 300, "pago_mensual": 350.0},
    {"escenario": "moderada", "dias_promedio": 220, "pago_mensual": 450.0},
    {"escenario": "optimista", "dias_promedio": 180, "pago_mensual": 550.0}
  ],
  "mensaje": "Con tu situacion actual, el pago podria variar segun disciplina y gastos variables. Prioriza estabilidad y revisa tu estrategia cada mes."
}
```

Notas:
- El array `escenarios` SIEMPRE tiene 3 elementos en este orden: `pesimista`, `moderada`, `optimista`.
- La `moneda` debe coincidir con la indicada en el prompt.
- `caracterizacion` puede ser: `buena`, `regular`, `mala`, `muy mala`.
- `mensaje` es una explicacion breve (maximo 2 oraciones).

---

## Modelos Swift

```swift
// MARK: - Request Model

struct DebtEstimateRequest: Codable {
    let prompt: String
}

// MARK: - Response Models

struct DebtEstimateResponse: Codable {
    let moneda: String
    let caracterizacion: String
    let escenarios: [DebtScenario]
    let mensaje: String
}

struct DebtScenario: Codable {
    let escenario: String
    let diasPromedio: Int
    let pagoMensual: Double

    enum CodingKeys: String, CodingKey {
        case escenario
        case diasPromedio = "dias_promedio"
        case pagoMensual = "pago_mensual"
    }
}
```

---

## Swift Implementation

```swift
class DebtEstimateService {
    private let baseURL: String

    init(baseURL: String) {
        self.baseURL = baseURL
    }

    func estimateDebt(prompt: String) async throws -> DebtEstimateResponse {
        let url = URL(string: "\(baseURL)/debt/estimate")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = DebtEstimateRequest(prompt: prompt)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.invalidResponse
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(DebtEstimateResponse.self, from: data)
    }
}
```

---

## Recomendaciones para el Prompt

Incluye siempre:
- Moneda de la deuda (ej: "USD", "EUR", "CUP")
- Monto de la deuda
- Ingresos mensuales
- Gastos mensuales
- Situacion actual (ej: otras deudas, atrasos, ingresos variables)
- Patrimonio actual (activos y pasivos relevantes)
- Estrategia financiera (ej: pagar minimo, nieve/avalancha, recortes)

Contexto Kiyosaki a considerar:
- Endeudarse solo para adquirir activos con flujo de efectivo inmediato.
- Vehiculos recomendados: bienes raices de alquiler, negocios que aumenten ventas/produccion,
  y en algunos casos commodities (requiere experiencia).
- Motivos de su estrategia:
  - Apalancamiento (OPM): usar dinero de otros para controlar mas activos.
  - Beneficios fiscales: la deuda buena puede ser eficiente fiscalmente.
  - Proteccion contra la inflacion: pagar en el futuro con dinero de menor valor.

Ejemplo:

```
Deuda en EUR: 3200. Ingresos 1400/mes, gastos 950/mes.
Situacion: ingreso variable y un credito activo. Patrimonio: ahorro 2000, auto propio.
Estrategia: recortar gastos fijos y priorizar esta deuda.
```

---

## Manejo de Errores

```swift
enum APIError: Error {
    case invalidResponse
    case serverError(String)
}
```
