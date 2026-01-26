# FinancIA API - Guía de Integración iOS

## Descripción General

FinancIA ofrece dos asistentes de IA especializados:

1. **Chat Financiero**: Asistente para consultas de finanzas personales con respuestas en streaming
2. **Extractor de Vales**: Analiza fotos de vales/recibos y extrae información estructurada

---

## Base URL

```
https://tu-servidor.com/api/v1/assistant
```

---

## 1. Chat Financiero (Streaming)

Asistente para consultas de finanzas personales: presupuestos, ahorro, gastos, etc.

### Endpoint

```
POST /chat/stream
```

### Request

**Content-Type**: `application/json`

```json
{
  "content": "¿Cómo puedo ahorrar más dinero este mes?"
}
```

### Response

**Content-Type**: `text/plain` (streaming)

La respuesta llega como stream de texto. Cada chunk es parte de la respuesta que puedes mostrar progresivamente.

### Swift Implementation

```swift
func sendChatMessage(_ message: String) async throws -> AsyncThrowingStream<String, Error> {
    let url = URL(string: "\(baseURL)/chat/stream")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let body = ["content": message]
    request.httpBody = try JSONEncoder().encode(body)

    return AsyncThrowingStream { continuation in
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                continuation.finish(throwing: error)
                return
            }

            if let data = data, let text = String(data: data, encoding: .utf8) {
                continuation.yield(text)
            }
            continuation.finish()
        }
        task.resume()
    }
}

// Uso con streaming real (URLSession bytes)
func streamChat(_ message: String) async throws {
    let url = URL(string: "\(baseURL)/chat/stream")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONEncoder().encode(["content": message])

    let (bytes, _) = try await URLSession.shared.bytes(for: request)

    for try await byte in bytes {
        if let char = String(bytes: [byte], encoding: .utf8) {
            // Actualizar UI con cada caracter/chunk
            print(char, terminator: "")
        }
    }
}
```

---

## 2. Extractor de Vales

Analiza una foto de vale/recibo y extrae: monto, lugar, items y moneda.

### Endpoint

```
POST /receipt/extract
```

### Request

**Content-Type**: `multipart/form-data`

| Campo | Tipo | Requerido | Descripción |
|-------|------|-----------|-------------|
| `image` | File | ✅ | Imagen del vale (JPEG, PNG, HEIC) |
| `instrucciones` | String | ✅ | Qué parte te corresponde |
| `lugares_conocidos` | String (JSON) | ❌ | Array de lugares guardados |

### Response

```json
{
  "monto": 150.0,
  "lugar": {
    "id": "cafe-123",
    "nombre": null,
    "palabras_clave": ["cafeteria pepe", "papel térmico", "logo verde"]
  },
  "subitems": [
    {"nombre": "Café", "cantidad": 2, "precio": 50.0},
    {"nombre": "Sandwich", "cantidad": 1, "precio": 200.0}
  ],
  "moneda": "CUP"
}
```

### Modelos Swift

```swift
// MARK: - Request Models

struct KnownPlace: Codable {
    let id: String
    let nombre: String
    let palabrasClave: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case nombre
        case palabrasClave = "palabras_clave"
    }
}

// MARK: - Response Models

struct ReceiptExtraction: Codable {
    let monto: Double
    let lugar: Lugar
    let subitems: [SubItem]?
    let moneda: String
}

struct Lugar: Codable {
    let id: String?
    let nombre: String?
    let palabrasClave: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case nombre
        case palabrasClave = "palabras_clave"
    }

    /// True si es un lugar nuevo (no reconocido)
    var esNuevo: Bool {
        return id == nil && nombre != nil
    }

    /// True si coincidió con un lugar existente
    var esConocido: Bool {
        return id != nil
    }
}

struct SubItem: Codable {
    let nombre: String
    let cantidad: Int
    let precio: Double?
}
```

### Swift Implementation

```swift
class ReceiptService {
    private let baseURL: String

    init(baseURL: String) {
        self.baseURL = baseURL
    }

    func extractReceipt(
        image: UIImage,
        instrucciones: String,
        lugaresConocidos: [KnownPlace]? = nil
    ) async throws -> ReceiptExtraction {

        let url = URL(string: "\(baseURL)/receipt/extract")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // Imagen
        if let imageData = image.jpegData(compressionQuality: 0.8) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"image\"; filename=\"receipt.jpg\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
            body.append(imageData)
            body.append("\r\n".data(using: .utf8)!)
        }

        // Instrucciones
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"instrucciones\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(instrucciones)\r\n".data(using: .utf8)!)

        // Lugares conocidos (opcional)
        if let lugares = lugaresConocidos, !lugares.isEmpty {
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            let lugaresJSON = try encoder.encode(lugares)

            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"lugares_conocidos\"\r\n\r\n".data(using: .utf8)!)
            body.append(lugaresJSON)
            body.append("\r\n".data(using: .utf8)!)
        }

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.invalidResponse
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(ReceiptExtraction.self, from: data)
    }
}
```

---

## Lógica de Negocio: Lugares

### Cómo funciona el matching de lugares

```
┌─────────────────────────────────────────────────────────────┐
│                    FOTO DEL VALE                            │
│                  (nombre visible)                           │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│         ¿El nombre coincide con algún lugar conocido?       │
└─────────────────────┬───────────────────────────────────────┘
                      │
          ┌───────────┴───────────┐
          │                       │
          ▼                       ▼
    ┌─────────┐             ┌─────────┐
    │   SÍ    │             │   NO    │
    └────┬────┘             └────┬────┘
         │                       │
         ▼                       ▼
┌─────────────────┐     ┌─────────────────┐
│ Retorna:        │     │ Retorna:        │
│ - id: "abc123"  │     │ - id: null      │
│ - nombre: null  │     │ - nombre: "..."  │
│ - palabras_clave│     │ - palabras_clave│
└─────────────────┘     └─────────────────┘
         │                       │
         ▼                       ▼
┌─────────────────┐     ┌─────────────────┐
│ LUGAR EXISTENTE │     │ LUGAR NUEVO     │
│ Actualizar      │     │ Crear en BD     │
│ palabras_clave  │     │ con nombre y    │
│ si hay nuevas   │     │ palabras_clave  │
└─────────────────┘     └─────────────────┘
```

### Flujo en tu app iOS

```swift
func procesarVale(image: UIImage, instrucciones: String) async {
    // 1. Obtener lugares guardados del usuario
    let lugaresGuardados = await database.getLugares()

    // 2. Convertir a formato API
    let lugaresAPI = lugaresGuardados.map { lugar in
        KnownPlace(
            id: lugar.id,
            nombre: lugar.nombre,
            palabrasClave: lugar.palabrasClave
        )
    }

    // 3. Llamar API
    let resultado = try await receiptService.extractReceipt(
        image: image,
        instrucciones: instrucciones,
        lugaresConocidos: lugaresAPI
    )

    // 4. Procesar lugar
    if resultado.lugar.esConocido {
        // Lugar existente - actualizar palabras clave si hay nuevas
        let lugarExistente = lugaresGuardados.first { $0.id == resultado.lugar.id }
        let nuevasPalabras = resultado.lugar.palabrasClave.filter {
            !lugarExistente.palabrasClave.contains($0)
        }
        if !nuevasPalabras.isEmpty {
            await database.agregarPalabrasClave(
                lugarId: resultado.lugar.id!,
                palabras: nuevasPalabras
            )
        }
    } else if resultado.lugar.esNuevo {
        // Lugar nuevo - crear
        await database.crearLugar(
            nombre: resultado.lugar.nombre!,
            palabrasClave: resultado.lugar.palabrasClave
        )
    }

    // 5. Guardar gasto
    await database.guardarGasto(
        monto: resultado.monto,
        moneda: resultado.moneda,
        lugarId: resultado.lugar.id ?? nuevoLugarId,
        items: resultado.subitems
    )
}
```

---

## Ejemplos de Instrucciones

| Situación | Instrucción |
|-----------|-------------|
| Todo el vale es tuyo | `"todo es mío"` |
| Dividir entre 2 | `"me corresponde la mitad"` |
| Dividir entre 3 | `"somos 3 personas"` |
| Solo algunos items | `"solo el café y el postre"` |
| Porcentaje específico | `"me corresponde el 30%"` |

---

## Ejemplo Completo: lugares_conocidos

```json
[
  {
    "id": "cafe-001",
    "nombre": "Cafetería El Rápido",
    "palabras_clave": ["papel térmico", "logo rojo", "EL RÁPIDO arriba"]
  },
  {
    "id": "rest-002",
    "nombre": "Paladar La Rosa",
    "palabras_clave": ["papel a mano", "rosa dibujada", "firma del mesero"]
  }
]
```

---

## Manejo de Errores

```swift
enum APIError: Error {
    case invalidResponse
    case serverError(String)
    case invalidImage
}

// El servidor retorna errores así:
// HTTP 400: {"detail": "El archivo debe ser una imagen"}
// HTTP 400: {"detail": "Formato inválido de lugares_conocidos: ..."}
```

---

## Moneda

- Por defecto siempre es `CUP`
- El símbolo `$` se interpreta como `CUP`
- Solo cambia si el vale muestra explícitamente otra moneda (USD, EUR, etc.)
