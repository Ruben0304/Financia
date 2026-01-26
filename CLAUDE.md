# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Financia is an iOS finance tracking application built with SwiftUI. The app features:
- Sign in with Apple authentication
- Finance dashboard with interactive charts using Swift Charts
- Custom "Aurora" pastel gradient design system
- Multi-wallet support with multiple currencies (USD, EUR, CUP)
- Transaction tracking with categories and subcategories
- Local JSON-based persistence (FileManager + Codable)
- Automatic exchange rate updates via ElToque API

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
│   ├── API/                  # ElToqueAPI - exchange rate service
│   ├── Data/                 # CategoriesData - predefined categories
│   ├── DesignSystem/         # Aurora design system (gradients, colors)
│   ├── Managers/             # Business logic and persistence managers
│   │   ├── ExchangeRateManager.swift
│   │   ├── TransactionManager.swift
│   │   ├── WalletManager.swift
│   │   └── CategoryManager.swift
│   ├── Models/               # Core data models
│   │   ├── CategoryModels.swift
│   │   ├── WalletModels.swift
│   │   ├── TransactionModels.swift
│   │   └── FinanceModels.swift
│   └── Persistence/          # Local storage layer
│       └── PersistenceManager.swift
├── Features/                  # Feature modules
│   ├── Root/                 # ContentView - main app coordinator
│   ├── Onboarding/           # WelcomeScreen - Sign in with Apple
│   ├── Dashboard/            # FinanceDashboardView + AddEntrySheet
│   └── Wallets/              # WalletsView + AddWalletSheet
└── FinanciaApp.swift         # App entry point
```

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

### JSON Storage Files

All data persists to Documents directory:
- `transactions.json` - All transactions
- `wallets.json` - User wallets
- `income_categories.json` - Income categories
- `expense_categories.json` - Expense categories
- `exchange_rates.json` - Cached exchange rates with timestamp

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

## Code Style Conventions

**SwiftUI Views:** Use view builders and computed properties for complex layouts. See `metricCard` and `chartView` in [FinanceDashboardView.swift](Financia/Features/Dashboard/FinanceDashboardView.swift).

**Color Usage:** Always use `AuroraColors` constants instead of hardcoded values for text. Background effects use specific RGB values for the gradient aesthetic.

**Spacing:** Consistent padding of 24pt for cards, 32pt for horizontal screen margins, 48pt for vertical screen margins.

**Font Styling:** Primarily uses `.rounded` design for a friendly feel. Titles use size 42-52pt with semibold weight.

## Current State & TODOs

**Implemented:**
- Authentication flow (with skip option)
- Finance dashboard with chart visualization
- Date range filtering (7D, 30D, 90D)
- Tab navigation structure

**Placeholder/Incomplete:**
- Income/Expense flows (handlers exist but empty at [ContentView.swift:91-97](Financia/Features/Root/ContentView.swift#L91-L97))
- "Carteras" (Wallets) tab
- "Historial" (History) tab
- User profile button action
- USD to CUP currency conversion (commented out in dashboard)

## Important Notes

**Entitlements:** The app uses Sign in with Apple capability. See [Financia.entitlements](Financia/Financia.entitlements).

**Sample Data:** Finance data is currently generated programmatically using a sine wave pattern in [FinanceModels.swift:34-46](Financia/Core/Models/FinanceModels.swift#L34-L46). Replace with real data integration when implementing persistence.

**Team ID:** Development team is set to `3978UBKA75` in project settings.
