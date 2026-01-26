# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Financia is an iOS finance tracking application built with SwiftUI. The app features:
- Sign in with Apple authentication
- Finance dashboard with interactive charts using Swift Charts
- Custom "Aurora" pastel gradient design system
- Multi-wallet support with multiple currencies (USD, EUR, CUP)
- Transaction tracking with categories and subcategories
- Receipt scanning with AI-powered data extraction
- AI chat assistant ("FinancIA") for financial analysis and insights
- Debt tracking with AI-powered repayment scenarios
- Place/location management for transaction categorization
- User profile for personalized financial context
- Local JSON-based persistence (FileManager + Codable)
- Automatic exchange rate updates via ElToque API
- Backend integration for AI services (chat, receipt extraction, debt estimation)

**Platform:** iOS 16.6+, iPhone only
**Language:** Swift 5.0
**Xcode Version:** 26.1
**Bundle ID:** com.ruben.Financia

## Build & Development Commands

### Building
```bash
# Build the project
xcodebuild -scheme Financia -configuration Debug

# Build for specific simulator
xcodebuild -scheme Financia -destination 'platform=iOS Simulator,name=iPhone 15' build

# Clean build
xcodebuild clean -scheme Financia
```

### Running
Open `Financia.xcodeproj` in Xcode and use Cmd+R to build and run. The app targets iPhone simulators and devices only.

### Project Information
```bash
# List schemes and configurations
xcodebuild -list -project Financia.xcodeproj
```

## Architecture

The codebase follows a feature-based modular architecture:

```
Financia/
├── Core/                      # Shared components and utilities
│   ├── API/                  # Backend API services
│   │   ├── ElToqueAPI.swift          # Exchange rate service
│   │   ├── ChatService.swift         # AI chat assistant (streaming)
│   │   ├── DebtEstimateService.swift # AI debt analysis
│   │   └── ReceiptService.swift      # Receipt extraction (multipart)
│   ├── Data/                 # CategoriesData - predefined categories
│   ├── DesignSystem/         # Aurora design system (gradients, colors)
│   ├── Managers/             # Business logic and persistence managers
│   │   ├── ExchangeRateManager.swift
│   │   ├── TransactionManager.swift
│   │   ├── WalletManager.swift
│   │   ├── CategoryManager.swift
│   │   ├── LugarManager.swift        # Place/location management
│   │   ├── DebtManager.swift         # Debt tracking
│   │   ├── ProfileManager.swift      # User profile
│   │   └── SavingsGoalManager.swift  # Savings goals
│   ├── Models/               # Core data models
│   │   ├── CategoryModels.swift
│   │   ├── WalletModels.swift
│   │   ├── TransactionModels.swift   # + Lugar, SubItem
│   │   ├── FinanceModels.swift
│   │   ├── DebtModels.swift          # Debt, DebtPayment, API responses
│   │   ├── ProfileModels.swift       # UserProfile
│   │   ├── ChatModels.swift          # ChatMessage, filters, time periods
│   │   ├── ReceiptModels.swift       # ReceiptExtraction, API models
│   │   └── SavingsModels.swift       # SavingsGoal, SavingsContribution
│   └── Persistence/          # Local storage layer
│       └── PersistenceManager.swift
├── Features/                  # Feature modules
│   ├── Root/                 # ContentView - main app coordinator
│   ├── Onboarding/           # WelcomeScreen - Sign in with Apple
│   ├── Dashboard/            # Finance dashboard
│   │   ├── FinanceDashboardView.swift
│   │   ├── AddEntrySheet.swift
│   │   ├── ReceiptScannerView.swift  # Photo capture + instructions
│   │   └── ReceiptReviewView.swift   # Review extracted data
│   ├── Balance/              # BalanceView - Consolidated overview
│   ├── Wallets/              # WalletsView + AddWalletSheet
│   ├── History/              # HistoryView + TransactionEditView
│   ├── Categories/           # CategoriesManagementView
│   ├── Places/               # PlacesView - Manage known locations
│   ├── Debts/                # Debt tracking and analysis
│   │   ├── DebtsView.swift
│   │   ├── DebtEditorView.swift
│   │   └── DebtDetailView.swift
│   ├── Profile/              # ProfileView - User info and financial context
│   ├── Savings/              # Savings goals tracking
│   │   ├── SavingsGoalsView.swift
│   │   ├── SavingsGoalEditorView.swift
│   │   └── SavingsGoalDetailView.swift
│   ├── Chat/                 # AI assistant
│   │   ├── ChatView.swift
│   │   └── ChatViewModel.swift
│   └── Shared/               # Reusable components
│       ├── AddCategoryView.swift
│       ├── CategoryGridSelector.swift
│       └── KeyboardSupport.swift
└── FinanciaApp.swift         # App entry point
```

### Feature Modules Overview

**Balance Tab** ([BalanceView.swift](Financia/Features/Balance/BalanceView.swift))
- Three-tabbed interface: Ingresos (Income), Gastos (Expenses), Deudas (Debts)
- Stats cards showing totals by currency with movement counters
- Quick navigation links to detailed history views
- Create new entries directly from each tab

**Categories Management** ([CategoriesManagementView.swift](Financia/Features/Categories/CategoriesManagementView.swift))
- Toggle between income and expense categories
- Visual grid with color-coded icons
- Create categories with custom icon and color picker
- Add/edit/delete subcategories
- Accessible from History view menu

**Debts System** ([Financia/Features/Debts/](Financia/Features/Debts/))
- **DebtsView**: List with health indicators (green/yellow/red based on AI characterization)
- **DebtEditorView**: Create debts with name, reason, amount, currency, optional timeline
- **DebtDetailView**:
  - AI debt estimation with 3 scenarios (pessimistic/moderate/optimistic)
  - Payment tracking against specific wallets
  - Balance preview after payment
  - Automatic "Deudas" category creation
  - Toggle time units (days/biweekly/months)

**History View** ([HistoryView.swift](Financia/Features/History/HistoryView.swift))
- Grouping by biweekly or monthly periods
- Filter by transaction type (all/income/expenses/debt payments)
- Swipe to delete transactions
- Tap to edit via TransactionEditView
- Menu access to Places and Categories management
- Pull to refresh

**Places Management** ([PlacesView.swift](Financia/Features/Places/PlacesView.swift))
- List of known locations with visual keyword tags
- Create/edit places with name and keywords
- Swipe to delete
- Keywords used for receipt matching
- Auto-populated from receipt extraction API

**Profile Tab** ([ProfileView.swift](Financia/Features/Profile/ProfileView.swift))
- User name field
- Avatar photo picker (from library)
- Financial situation description (free-form text)
- Financial strategy/goals description
- Data used as context for debt estimation prompts
- Navigation to Savings Goals

**Savings Goals System** ([Financia/Features/Savings/](Financia/Features/Savings/))
- **SavingsGoalsView**: List of savings goals with progress bars and completion status
- **SavingsGoalEditorView**: Create goals with name, description, target price, currency, optional photo, and product URL
- **SavingsGoalDetailView**:
  - LinkPresentation preview for product URLs (iMessage-style)
  - Progress tracking with percentage and remaining amount
  - Contribution management against wallets
  - Contribution history with notes
  - Achievement indication when goal is reached
- Manual entry or paste product links (Amazon, Shein, MercadoLibre, etc.)
- Photo upload from library for visual goal representation
- Link preview using iOS LinkPresentation framework

**Chat Assistant** ([ChatView.swift](Financia/Features/Chat/ChatView.swift) + [ChatViewModel.swift](Financia/Features/Chat/ChatViewModel.swift))
- iMessage-style chat interface with bubbles
- Real-time streaming AI responses
- Filter sheet for transaction context customization
- Transaction type filter (income/expenses/both)
- Time period selector (week/month/3mo/6mo/year/all)
- Includes up to 50 transactions + stats in prompts
- Message history with timestamps
- Clear chat option

**Receipt Scanning** ([ReceiptScannerView.swift](Financia/Features/Dashboard/ReceiptScannerView.swift) + [ReceiptReviewView.swift](Financia/Features/Dashboard/ReceiptReviewView.swift))
- Photo capture or library selection
- Processing instructions input (e.g., "split 3 ways")
- AI extraction of amount, currency, place, line items
- Review UI with grouped sections (General Info, Items, Transaction Details)
- Place auto-matching via keywords
- Manual item editing (add/remove/modify)
- Seamless integration into transaction creation flow

### Key Architectural Patterns

**State Management:**
- SwiftUI `@State` and `@Binding` for local view state
- `@EnvironmentObject` for shared managers injected from [FinanciaApp.swift](Financia/FinanciaApp.swift)
- Singleton managers (`*.shared`) for global state and persistence

**Persistence Layer:**
- [PersistenceManager.swift](Financia/Core/Persistence/PersistenceManager.swift) - Generic JSON storage using FileManager + Codable
- All data stored in Documents directory as JSON files
- Automatic encoding/decoding with `JSONEncoder`/`JSONDecoder`
- Supports any `Codable` type for easy extensibility

**Data Managers:**
- **TransactionManager** - CRUD operations for transactions, statistics, filtering
- **WalletManager** - Wallet management, balance calculation, currency conversion
- **CategoryManager** - Category/subcategory management (income & expense)
- **ExchangeRateManager** - Exchange rate caching with auto-refresh (1 day expiration)
- **LugarManager** - Place/location management with intelligent API merging
- **DebtManager** - Debt tracking, payment history, AI estimate storage
- **ProfileManager** - User profile persistence (name, avatar, financial context)
- **SavingsGoalManager** - Savings goals tracking with contribution management

**Backend API Services:**
- **ChatService** - Streaming AI chat endpoint for financial analysis
  - Endpoint: `https://financia-backend-production.up.railway.app/api/v1/assistant/chat/stream`
  - Uses AsyncThrowingStream for real-time message chunks
  - Includes transaction context in prompts (filtered by type and time period)
- **DebtEstimateService** - AI-powered debt repayment analysis
  - Endpoint: `https://financia-backend-production.up.railway.app/api/v1/assistant/debt/estimate`
  - Returns characterization (good/regular/bad) + 3 scenarios (pessimistic/moderate/optimistic)
  - Builds context from user profile, wallet balances, and transaction history
- **ReceiptService** - Multipart receipt extraction
  - Extracts amount, currency, place, and line items from receipt photos
  - Accepts known places list for intelligent location matching
  - Returns structured data with backend place IDs for syncing

**Authentication Flow:**
- Unauthenticated users see [WelcomeScreen.swift](Financia/Features/Onboarding/WelcomeScreen.swift)
- Authentication state managed in [ContentView.swift](Financia/Features/Root/ContentView.swift)
- Sign in with Apple configured via entitlements

**Design System:**
- All views use `AuroraBackground` from [DesignSystem.swift](Financia/Core/DesignSystem/DesignSystem.swift)
- Colors defined in `AuroraColors` enum (primaryText, secondaryText)
- Consistent use of rounded corners (30-32pt radius) and subtle shadows

**Data Flow:**
- Transactions persist automatically on creation via [AddEntrySheet.swift](Financia/Features/Dashboard/AddEntrySheet.swift)
- Dashboard reads real transactions from TransactionManager
- Wallets calculate balance from associated transactions
- Exchange rates cache locally and refresh automatically after 1 day
- Receipt scanning flow: Photo → API extraction → User review → Transaction + Place persistence
- Chat context building: Filter transactions → Build stats summary → Stream AI response
- Debt analysis: Build prompt from profile + finances → API analysis → Store scenarios with debt

## Persistence & Data Models

### Core Models

**Transaction** ([TransactionModels.swift](Financia/Core/Models/TransactionModels.swift))
```swift
struct Transaction: Identifiable, Codable {
    var id: UUID
    var type: TransactionType  // .income or .expense
    var amount: Double
    var date: Date
    var categoryId: UUID
    var categoryName: String
    var subcategoryId: UUID
    var subcategoryName: String
    var description: String
    var walletId: UUID
    var createdAt: Date
    var lugar: Lugar?          // NEW: Associated place/location
    var subitems: [SubItem]?   // NEW: Line items from receipt
}

struct Lugar: Identifiable, Codable {
    var id: UUID               // Local UUID
    var nombre: String
    var visualKeywords: [String]?  // Tags for matching
    var backendId: String?         // API reference ID
}

struct SubItem: Identifiable, Codable {
    var id: UUID
    var nombre: String
    var cantidad: Int
    var precio: Double?
}
```

**Wallet** ([WalletModels.swift](Financia/Core/Models/WalletModels.swift))
```swift
struct Wallet: Identifiable, Codable {
    var id: UUID
    var name: String
    var currency: Currency  // .usd, .eur, .cup
    var balance: Double
    var icon: String
    var color: Color
}
```

**TransactionCategory** ([CategoryModels.swift](Financia/Core/Models/CategoryModels.swift))
```swift
struct TransactionCategory: Identifiable, Codable {
    var id: UUID
    var name: String
    var subcategories: [Subcategory]
    var icon: String
    var color: Color
}
```

**Debt** ([DebtModels.swift](Financia/Core/Models/DebtModels.swift))
```swift
struct Debt: Identifiable, Codable {
    var id: UUID
    var nombre: String
    var motivo: String         // Reason for debt
    var monto: Double          // Current amount
    var moneda: Currency
    var plazoMeses: Int?       // Optional timeline
    var createdAt: Date
    var lastEstimate: DebtEstimateResponse?  // AI analysis
    var montoOriginal: Double  // Starting amount
    var pagos: [DebtPayment]   // Payment history
}

struct DebtPayment: Identifiable, Codable {
    var id: UUID
    var amount: Double
    var date: Date
    var walletId: UUID
}

struct DebtEstimateResponse: Codable {
    var moneda: String
    var caracterizacion: String  // "good", "regular", "bad", "muy mala"
    var escenarios: [DebtScenario]
    var mensaje: String
}

struct DebtScenario: Codable {
    var escenario: String      // "pessimista", "moderada", "optimista"
    var diasPromedio: Int
    var pagoMensual: Double
}
```

**UserProfile** ([ProfileModels.swift](Financia/Core/Models/ProfileModels.swift))
```swift
struct UserProfile: Codable {
    var nombre: String
    var avatarData: Data?           // Image data
    var situacionFinanciera: String // Financial situation description
    var estrategiaFinanciera: String // Financial strategy/goals
}
```

**ChatMessage** ([ChatModels.swift](Financia/Core/Models/ChatModels.swift))
```swift
struct ChatMessage: Identifiable, Codable {
    var id: UUID
    var content: String
    var isUser: Bool
    var timestamp: Date
}

enum TransactionFilter {
    case ingresos   // Income only
    case gastos     // Expenses only
    case ambos      // Both
}

enum TimePeriod {
    case week, month, threeMonths, sixMonths, year, all
    var startDate: Date { /* computed */ }
}
```

**SavingsGoal** ([SavingsModels.swift](Financia/Core/Models/SavingsModels.swift))
```swift
struct SavingsGoal: Identifiable, Codable {
    var id: UUID
    var nombre: String
    var descripcion: String
    var precioObjetivo: Double
    var moneda: Currency
    var imagenData: Data?          // Optional local photo
    var productURL: String?         // Optional product link
    var ahorrado: Double            // Current progress
    var createdAt: Date
    var contribuciones: [SavingsContribution]

    // Computed properties
    var porcentajeCompletado: Double  // Progress percentage
    var montoPendiente: Double        // Remaining amount
    var alcanzado: Bool               // Goal achieved
}

struct SavingsContribution: Identifiable, Codable {
    var id: UUID
    var monto: Double
    var fecha: Date
    var walletId: UUID
    var nota: String?
}
```

### JSON Storage Files

All data persists to Documents directory:
- `transactions.json` - All transactions (with lugar and subitems)
- `wallets.json` - User wallets
- `income_categories.json` - Income categories
- `expense_categories.json` - Expense categories
- `exchange_rates.json` - Cached exchange rates with timestamp
- `lugares.json` - Known places/locations with visual keywords
- `debts.json` - Debt tracking with payment history and AI estimates
- `profile.json` - User profile (name, avatar, financial context)
- `chat_messages.json` - Chat history with AI assistant
- `savings_goals.json` - Savings goals with contributions and progress tracking

### Exchange Rate Management

**Auto-refresh logic** ([ExchangeRateManager.swift](Financia/Core/Managers/ExchangeRateManager.swift)):
- Checks cache age on app launch
- Auto-updates if > 1 day old
- Manual refresh via `refreshRates()`
- Currency conversion: USD ↔ CUP, EUR ↔ CUP

**API Integration:**
- ElToque API for Cuban exchange rates
- Token configured in [FinanciaApp.swift](Financia/FinanciaApp.swift) init
- Caches response to avoid unnecessary requests

### Manager Usage Patterns

**Creating a transaction:**
```swift
let transaction = Transaction(
    type: .expense,
    amount: 100.0,
    date: Date(),
    categoryId: category.id,
    categoryName: category.name,
    subcategoryId: subcategory.id,
    subcategoryName: subcategory.name,
    description: "Lunch",
    walletId: wallet.id
)
transactionManager.addTransaction(transaction)
```

**Querying transactions:**
```swift
// By wallet
let walletTransactions = transactionManager.transactions(for: wallet)

// By type
let expenses = transactionManager.transactions(ofType: .expense)

// By date range
let recent = transactionManager.transactions(in: .month)

// Statistics
let totalIncome = transactionManager.totalIncome()
let balance = transactionManager.balance()
```

## Receipt Scanning Workflow

Receipt scanning is a two-stage process that extracts transaction data from photos:

### Stage 1: Photo Capture ([ReceiptScannerView.swift](Financia/Features/Dashboard/ReceiptScannerView.swift))
1. User takes photo or selects from library
2. User enters processing instructions (e.g., "it's all mine", "split 3 ways", "only food items")
3. Photo + instructions + known places list sent to backend API
4. Backend returns `ReceiptExtraction` with:
   - Total amount
   - Currency (USD, EUR, CUP)
   - Place information (name + keywords)
   - Line items with quantities and prices

### Stage 2: Review & Confirm ([ReceiptReviewView.swift](Financia/Features/Dashboard/ReceiptReviewView.swift))
1. User reviews extracted data in grouped sections:
   - **Información General**: Amount, currency, place name
   - **Artículos**: Line items (can edit/add/remove)
   - **Detalles de Transacción**: Wallet, category, date, notes
2. Place name auto-matches to known lugares via keywords
3. User can override place name (override persists in LugarManager)
4. On save:
   - Transaction created with `lugar` and `subitems`
   - Place upserted to LugarManager (merges API data with user overrides)
   - Automatic subcategory creation if needed

### Place Matching Logic
```swift
// LugarManager.upsertLugar() intelligently merges:
// - If user previously renamed: Keep user's name
// - If new from API: Store backend ID and keywords
// - Keywords merged from API responses for better future matching
```

## AI Integration

### Chat Assistant ("FinancIA")

**Context Building:**
- Filters transactions by type (income/expenses/both) and time period
- Includes up to 50 most recent transactions in prompt
- Adds summary statistics (total income, expenses, balance by currency)
- User profile data not currently included (potential enhancement)

**Streaming Response:**
```swift
// ChatViewModel.sendMessage()
let context = buildTransactionContext()
let fullPrompt = context + "\n\nUser query: \(message)"

for try await chunk in ChatService.shared.sendMessage(fullPrompt) {
    currentMessage.content += chunk  // Real-time streaming
}
```

**Filter Sheet:**
- Transaction type selector (ingresos/gastos/ambos)
- Time period picker (week/month/3mo/6mo/year/all)
- Filters applied before building context

### Debt Estimation

**Prompt Construction:**
```swift
// DebtDetailView.buildPrompt()
// Includes:
// 1. Debt details (original amount, current amount, timeline)
// 2. Wallet balance (same currency as debt)
// 3. Monthly income/expenses (last 30 days)
// 4. Payment history
// 5. User's profile (financial situation + strategy)
```

**Response Processing:**
- Characterization: "good", "regular", "bad", "muy mala" (color-coded in UI)
- Three scenarios: pessimistic, moderate, optimistic
- Each scenario includes: average days to payoff, monthly payment amount
- User can toggle time units: days / biweekly periods / months

**Debt Payment Flow:**
1. User registers payment against a wallet
2. Debt amount reduced by payment
3. Payment recorded in `pagos` array
4. Automatically creates/uses "Deudas" expense category
5. Transaction created with debt payment details

## Code Style Conventions

**SwiftUI Views:** Use view builders and computed properties for complex layouts. See `metricCard` and `chartView` in [FinanceDashboardView.swift](Financia/Features/Dashboard/FinanceDashboardView.swift).

**Color Usage:** Always use `AuroraColors` constants instead of hardcoded values for text. Background effects use specific RGB values for the gradient aesthetic.

**Spacing:** Consistent padding of 24pt for cards, 32pt for horizontal screen margins, 48pt for vertical screen margins.

**Font Styling:** Primarily uses `.rounded` design for a friendly feel. Titles use size 42-52pt with semibold weight.

## Current State & TODOs

**Fully Implemented:**
- ✅ Authentication flow (Sign in with Apple + skip option)
- ✅ Finance dashboard with Swift Charts visualization
- ✅ Multi-wallet management with currency support (USD, EUR, CUP)
- ✅ Transaction CRUD operations with categories and subcategories
- ✅ Category management (create, edit, delete categories and subcategories)
- ✅ Receipt scanning with AI-powered data extraction
- ✅ Place/location management with intelligent API syncing
- ✅ Transaction history with filtering and editing
- ✅ Balance view with tabbed income/expenses/debts overview
- ✅ Debt tracking with payment history
- ✅ AI debt estimation with repayment scenarios
- ✅ Chat assistant with transaction context filtering
- ✅ User profile management (name, avatar, financial context)
- ✅ Exchange rate caching and automatic updates
- ✅ Tab-based navigation (Dashboard, Balance, Wallets, Profile)

**Recent Additions:**
- Chat tab ("FinancIA") with streaming AI responses
- Receipt review workflow with grouped UI sections
- Debt detail view with AI analysis integration
- Transaction editing from history view
- Place name validation and keyword management
- Profile data integration into debt estimation prompts

**Known Limitations:**
- Sample data generation removed (now using real persistence)
- No cloud sync (all data stored locally)
- No data export functionality
- No recurring transactions support
- No budgeting/savings goals features
- No multi-user support
- No transaction search beyond filtering

**Potential Enhancements:**
- Include user profile in chat context (currently only in debt estimation)
- Add transaction search by description or place
- Implement budget tracking per category
- Add savings goals with progress tracking
- Support for recurring/scheduled transactions
- Data export (CSV, PDF reports)
- iCloud sync for cross-device support
- Transaction attachments (store receipt photos)
- Notification reminders for bills/debts
- Advanced analytics and spending insights

## Important Notes

**Entitlements:** The app uses Sign in with Apple capability. See [Financia.entitlements](Financia/Financia.entitlements).

**Backend Integration:** The app connects to a production backend hosted on Railway:
- Base URL: `https://financia-backend-production.up.railway.app`
- Endpoints: `/api/v1/assistant/chat/stream`, `/api/v1/assistant/debt/estimate`, `/api/v1/receipt/extract`
- All API communication uses JSON encoding with snake_case conversion
- Chat uses streaming responses via AsyncThrowingStream
- Receipt extraction uses multipart/form-data for image upload

**Persistence Strategy:** All data stored locally in JSON files in Documents directory. No cloud sync implemented. App operates offline except for AI features (chat, debt estimation, receipt extraction) and exchange rate updates.

**Error Handling:** API services implement custom error enums (`ChatAPIError`, `DebtAPIError`, `ReceiptAPIError`) with detailed error cases for network failures, invalid responses, and decoding issues.

**Team ID:** Development team is set to `3978UBKA75` in project settings.

**Platform Requirements:** iOS 16.6+ required for Swift Charts and AsyncThrowingStream support.

**Navigation Structure:** The app uses a TabView with four main tabs:
1. **Dashboard** (Inicio) - Finance overview with charts and quick actions
2. **Balance** - Tabbed view of income/expenses/debts with stats
3. **Wallets** (Carteras) - Wallet management and balance tracking
4. **Profile** (Perfil) - User information and financial context

Additional views accessible via navigation:
- History - From Dashboard or Balance tabs
- Categories Management - From History menu
- Places Management - From History menu
- Debt Detail - From Balance > Debts tab
- Transaction Edit - From History (tap transaction)
- Receipt Scanner - From Dashboard floating action button

## Common User Workflows

### Workflow 1: Manual Transaction Entry
```
Dashboard → Add Entry FAB → AddEntrySheet
  ↓ User fills:
  - Transaction type (income/expense)
  - Amount
  - Category + Subcategory (via CategoryGridSelector)
  - Wallet
  - Date
  - Description
  ↓ Save
Transaction persisted → TransactionManager → transactions.json
```

### Workflow 2: Receipt-Based Transaction
```
Dashboard → Scan Receipt FAB → ReceiptScannerView
  ↓ User:
  - Takes photo or selects from library
  - Enters instructions ("split 3 ways", etc.)
  ↓ API Call
ReceiptService.extractReceipt() → Backend processing
  ↓ Returns:
  - ReceiptExtraction (amount, place, subitems, currency)
  ↓ Navigate to
ReceiptReviewView
  ↓ User reviews/edits:
  - Verifies amount and place name
  - Edits line items if needed
  - Selects wallet, category, date
  ↓ Save
Transaction created with lugar + subitems
  ↓ Parallel operations:
  1. TransactionManager.addTransaction()
  2. LugarManager.upsertLugar() (merges API data)
  ↓ Persist
transactions.json + lugares.json updated
```

### Workflow 3: Debt Tracking & Analysis
```
Balance Tab → Deudas → Create Debt → DebtEditorView
  ↓ User fills:
  - Name, reason, amount, currency
  - Optional timeline (months)
  ↓ Save
DebtManager.addDebt() → debts.json
  ↓ User taps debt
DebtDetailView
  ↓ User taps "Analizar con IA"
buildPrompt() includes:
  - Debt details
  - Wallet balance
  - Monthly income/expenses
  - Payment history
  - User profile context
  ↓ API Call
DebtEstimateService.estimateDebt()
  ↓ Returns:
  - Characterization (good/regular/bad/muy mala)
  - 3 scenarios with days + monthly payment
  ↓ Update
DebtManager.updateDebt() saves estimate
  ↓ User can:
  - Toggle time units (days/biweekly/months)
  - Register payment → reduces debt amount + creates transaction
```

### Workflow 4: Chat with AI Assistant
```
Chat Tab → ChatView
  ↓ User taps filter icon
Filter Sheet
  ↓ User selects:
  - Transaction type (ingresos/gastos/ambos)
  - Time period (week/month/3mo/6mo/year/all)
  ↓ User types message
ChatViewModel.sendMessage()
  ↓ Build context:
  1. Filter transactions by type + period
  2. Get up to 50 most recent
  3. Calculate totals by currency
  4. Format as text context
  ↓ Concatenate
fullPrompt = context + user message
  ↓ API Call
ChatService.sendMessage() → streaming endpoint
  ↓ AsyncThrowingStream
Chunks received in real-time
  ↓ Display
Message bubbles update as content streams in
  ↓ Persist
chat_messages.json updated
```

### Workflow 5: Transaction Editing
```
Dashboard/Balance → Navigate to History → HistoryView
  ↓ User taps transaction
TransactionEditView sheet
  ↓ User edits:
  - Amount
  - Category/Subcategory
  - Date
  - Description
  ↓ Save
TransactionManager.updateTransaction()
  ↓ Persist
transactions.json updated
  ↓ Auto-refresh
Dashboard charts update
Wallet balances recalculate
```

### Workflow 6: Place Management
```
History → Menu → Places → PlacesView
  ↓ User sees:
  - List of known lugares with keywords
  ↓ User can:
  - Create new place (name + keywords)
  - Edit existing place
  - Delete place (swipe action)
  ↓ Save/Update
LugarManager persists → lugares.json
  ↓ Impact:
  - Future receipt scans match against keywords
  - Transactions can be filtered by place
```

## Testing Considerations

**Receipt Scanning:**
- Test with various receipt formats (thermal, printed, handwritten)
- Test splitting instructions ("split 2 ways", "only my items", etc.)
- Test place matching with known and new locations
- Verify line item extraction accuracy

**AI Services:**
- Mock streaming responses for UI testing
- Test error handling for network failures
- Test context building with edge cases (no transactions, single currency, etc.)
- Verify prompt construction includes all necessary data

**Persistence:**
- Test data migration when models change
- Verify JSON encoding/decoding for all Codable types
- Test concurrent access to managers
- Verify file system permissions

**Exchange Rates:**
- Test cache expiration logic
- Test offline behavior when rates unavailable
- Verify currency conversion calculations
- Test manual refresh trigger
