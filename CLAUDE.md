# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Financia is an iOS finance tracking application built with SwiftUI. The app features:
- Sign in with Apple authentication
- Finance dashboard with interactive charts using Swift Charts
- Custom "Aurora" pastel gradient design system
- Sample finance data visualization with date-based filtering

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
│   ├── DesignSystem/         # Aurora design system (gradients, colors)
│   └── Models/               # Core data models (DateRange, FinanceEntry)
├── Features/                  # Feature modules
│   ├── Root/                 # ContentView - main app coordinator
│   ├── Onboarding/           # WelcomeScreen - Sign in with Apple
│   └── Dashboard/            # FinanceDashboardView - main finance UI
└── FinanciaApp.swift         # App entry point
```

### Key Architectural Patterns

**State Management:** SwiftUI `@State` and `@Binding` for local state, passed down from [ContentView.swift](Financia/Features/Root/ContentView.swift) which acts as the root coordinator.

**Authentication Flow:**
- Unauthenticated users see [WelcomeScreen.swift](Financia/Features/Onboarding/WelcomeScreen.swift)
- Authentication state managed in [ContentView.swift:5](Financia/Features/Root/ContentView.swift#L5)
- Sign in with Apple configured via entitlements

**Design System:**
- All views use `AuroraBackground` from [DesignSystem.swift](Financia/Core/DesignSystem/DesignSystem.swift)
- Colors defined in `AuroraColors` enum (primaryText, secondaryText)
- Consistent use of rounded corners (30-32pt radius) and subtle shadows

**Data Flow:**
- Sample data generated in [FinanceModels.swift:34-46](Financia/Core/Models/FinanceModels.swift#L34-L46)
- Dashboard accepts entries via props, filters by selected date range
- Income/Expense handlers defined but not yet implemented (see [ContentView.swift:91-97](Financia/Features/Root/ContentView.swift#L91-L97))

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
