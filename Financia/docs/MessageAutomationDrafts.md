# Automatizacion de borradores desde mensajes

## Flujo recomendado

La opcion principal ahora es una accion de Atajos del propio app:

`Importar borrador automatizado`

Esa accion usa `AppIntents` y puede ejecutarse sin abrir Financia.

Flujo:

1. En una automatizacion de `Atajos`, detecta el SMS o push del banco/operador.
2. Atajos solo verifica si el mensaje es de uno de los tres formatos que te interesan.
3. Si coincide, manda el mensaje crudo a `Importar borrador automatizado`.
4. Financia procesa el mensaje internamente:
   - primero con Apple Intelligence local usando `FoundationModels`
   - si Apple Intelligence no esta disponible o falla, usa fallback por regex
5. El borrador queda guardado y aparece cuando abras la app.

## Alternativa de respaldo

Si quieres una prueba rapida, tambien puedes usar URL scheme. Esa via si puede abrir la app:

```text
financia://import-draft?payload64=BASE64_URL_SAFE_DEL_JSON
```

## JSON esperado

```json
{
  "sourceKind": "incomingTransfer",
  "amount": 1250,
  "currency": "CUP",
  "occurredAt": "2025-02-14T18:42:00Z",
  "rawMessage": "Transferencia recibida de Alejandro. Importe 1250 CUP.",
  "suggestedName": "Alejandro",
  "counterpartyName": "Alejandro",
  "note": "Mensaje importado desde automatizacion",
  "externalIdentifier": "sms-2025-02-14-184200-1250"
}
```

## Reglas de importacion

- `incomingTransfer` entra como borrador de `income`.
- `outgoingTransfer` entra como borrador de `expense`.
- `mobileTopUp` entra como borrador de `expense`.
- `externalIdentifier` evita duplicados si el mismo mensaje llega dos veces.
- El borrador queda persistido localmente en SwiftData y aparece en el dashboard.
- `occurredAt` puede ser la fecha actual del atajo. No hace falta parsear la fecha del SMS.
- La cartera y moneda final las define el usuario en Perfil. No se detectan del mensaje para decidir la cartera.

## Recomendacion tecnica

La implementacion actual sigue esta estrategia:

- Atajos solo filtra si el mensaje es de interes
- Financia intenta primero Apple Intelligence local
- si el modelo no esta disponible, o falla la extraccion, cae a regex

Esto te deja el flujo simple en Atajos, pero con una red de seguridad robusta dentro de la app.

## Campos que de verdad necesita Financia

Para estos mensajes, basta con construir este JSON:

```json
{
  "sourceKind": "incomingTransfer",
  "amount": 5000,
  "currency": "CUP",
  "occurredAt": "2026-03-11T18:42:00Z",
  "rawMessage": "mensaje original completo",
  "suggestedName": "Transferencia recibida",
  "counterpartyName": "5356956542",
  "note": "Nro. Transaccion MM6043C34C987",
  "externalIdentifier": "MM6043C34C987"
}
```

## Mapeo exacto de tus 3 mensajes

### 1. Transferencia que tu realizas

Ejemplo:

```text
Banco Metropolitano: La Transferencia fue completada.
Fecha: 11/3/2026
Beneficiario: 9202XXXXXXXX1864
Ordenante: CUP
Monto: 500.00 CUP
Nro. Transaccion: MM6044S2TE987
Saldo restante: CR 1807.70 CUP
```

Salida:

```json
{
  "sourceKind": "outgoingTransfer",
  "amount": 500.00,
  "currency": "CUP",
  "occurredAt": "fecha actual del atajo en ISO 8601",
  "rawMessage": "mensaje completo",
  "suggestedName": "Transferencia enviada",
  "counterpartyName": "9202XXXXXXXX1864",
  "note": "Beneficiario 9202XXXXXXXX1864",
  "externalIdentifier": "MM6044S2TE987"
}
```

Reglas:

- si contiene `La Transferencia fue completada` => `outgoingTransfer`
- `amount`: valor entre `Monto:` y `CUP`
- `currency`: `CUP`
- `counterpartyName`: valor de `Beneficiario:`
- `externalIdentifier`: valor de `Nro. Transaccion:`

### 2. Recarga movil

Ejemplo:

```text
Banco Metropolitano: La recarga se realizo con exito. Saldo a acreditar: 360 CUP. Saldo acreditado: 360 CUP. Monto Pagado: 324.0 CUP. Telefono: 53074015. Id transaccion: MM6043ROTO987. Saldo Restante: CR 2147.7.
Gracias por utilizar nuestros servicios, ETECSA.
```

Salida:

```json
{
  "sourceKind": "mobileTopUp",
  "amount": 324.0,
  "currency": "CUP",
  "occurredAt": "fecha actual del atajo en ISO 8601",
  "rawMessage": "mensaje completo",
  "suggestedName": "Recarga movil",
  "counterpartyName": "53074015",
  "note": "Telefono 53074015",
  "externalIdentifier": "MM6043ROTO987"
}
```

Reglas:

- si contiene `La recarga se realizo con exito` => `mobileTopUp`
- usa `Monto Pagado` como monto del gasto
- `counterpartyName`: valor de `Telefono:`
- `externalIdentifier`: valor de `Id transaccion:`

### 3. Transferencia que te hacen

Ejemplo:

```text
El titular del telefono 5356956542 le ha realizado una transferencia a la cuenta 9205959874714620 de 5000.00 CUP. Nro. Transaccion MM6043C34C987. Fecha: 5/3/2026.
```

Salida:

```json
{
  "sourceKind": "incomingTransfer",
  "amount": 5000.00,
  "currency": "CUP",
  "occurredAt": "fecha actual del atajo en ISO 8601",
  "rawMessage": "mensaje completo",
  "suggestedName": "Transferencia recibida",
  "counterpartyName": "5356956542",
  "note": "Cuenta destino 9205959874714620",
  "externalIdentifier": "MM6043C34C987"
}
```

Reglas:

- si contiene `le ha realizado una transferencia a la cuenta` => `incomingTransfer`
- `amount`: valor entre `de` y `CUP`
- `counterpartyName`: numero luego de `El titular del telefono`
- `externalIdentifier`: valor luego de `Nro. Transaccion`

## Flujo recomendado en Atajos

1. Crea una automatizacion personal basada en SMS o notificacion, segun como te lleguen.
2. Obtén el texto completo del mensaje.
3. Haz un bloque `Si`:
   - si contiene `La Transferencia fue completada`
   - si no, si contiene `La recarga se realizo con exito`
   - si no, si contiene `le ha realizado una transferencia a la cuenta`
4. Si no coincide con ninguno, termina.
5. Si coincide, ejecuta la accion de Atajos de Financia:
   - `Importar borrador automatizado`
   - pasando el mensaje completo como parámetro

## Prompt interno para Apple Intelligence

Financia ya usa internamente un prompt local con `FoundationModels` para:

- clasificar entre `incomingTransfer`, `outgoingTransfer` y `mobileTopUp`
- extraer monto
- extraer contraparte
- extraer identificador de transaccion

Si el modelo no esta disponible, la app usa regex y no depende de la IA.

## Ejemplos de prompts para Apple Intelligence

### Transferencia recibida

```text
Extrae un JSON valido con estas llaves exactas:
sourceKind, amount, currency, occurredAt, rawMessage, suggestedName, counterpartyName, note, externalIdentifier.
sourceKind debe ser "incomingTransfer".
amount debe ser numero.
currency debe ser "CUP", "USD" o "EUR".
occurredAt debe venir en ISO 8601.
Si falta suggestedName, usa el remitente si existe.
Devuelve solo JSON.
```

### Transferencia enviada

```text
Extrae un JSON valido con estas llaves exactas:
sourceKind, amount, currency, occurredAt, rawMessage, suggestedName, counterpartyName, note, externalIdentifier.
sourceKind debe ser "outgoingTransfer".
Devuelve solo JSON.
```

### Recarga movil

```text
Extrae un JSON valido con estas llaves exactas:
sourceKind, amount, currency, occurredAt, rawMessage, suggestedName, counterpartyName, note, externalIdentifier.
sourceKind debe ser "mobileTopUp".
Si no hay suggestedName, usa "Recarga movil".
Devuelve solo JSON.
```
