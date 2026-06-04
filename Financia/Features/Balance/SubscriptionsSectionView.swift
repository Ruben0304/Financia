import SwiftUI
import UIKit

struct SubscriptionsSectionView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var subscriptionManager: SubscriptionManager

    @State private var quickFilter: SubscriptionQuickFilter = .all
    @State private var navigationPath = NavigationPath()
    @State private var errorMessage: String?
    @State private var showingError = false

    private var activeSubscriptions: [Subscription] {
        let active = subscriptionManager.subscriptions
            .filter(\.isActive)
            .sorted { $0.billingDay < $1.billingDay }

        guard quickFilter == .thisWeek else { return active }
        return active.filter(isInUpcomingWeek(_:))
    }

    private var cancelledSubscriptions: [Subscription] {
        subscriptionManager.subscriptions
            .filter { !$0.isActive }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    private var allActiveSubscriptions: [Subscription] {
        subscriptionManager.subscriptions.filter(\.isActive)
    }

    private var upcomingThisWeekCount: Int {
        allActiveSubscriptions.filter(isInUpcomingWeek(_:)).count
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    summaryCard
                    filterTabs

                    if activeSubscriptions.isEmpty && cancelledSubscriptions.isEmpty {
                        emptyState
                    } else {
                        if !activeSubscriptions.isEmpty {
                            sectionTitle("Activas")
                            VStack(spacing: 12) {
                                ForEach(activeSubscriptions) { subscription in
                                    subscriptionRow(subscription)
                                }
                            }
                        }

                        if quickFilter == .all && !cancelledSubscriptions.isEmpty {
                            sectionTitle("Canceladas")
                            VStack(spacing: 12) {
                                ForEach(cancelledSubscriptions) { subscription in
                                    subscriptionRow(subscription)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(DarkFinanceBackground())
            .navigationTitle("Suscripciones")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Plantillas") {
                        navigationPath.append(SubscriptionSheetRoute.templates)
                    }

                    Button {
                        navigationPath.append(SubscriptionSheetRoute.new)
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .navigationDestination(for: SubscriptionSheetRoute.self) { route in
                destinationView(for: route)
            }
        }
        .alert("No se pudo registrar", isPresented: $showingError, actions: {
            Button("OK", role: .cancel) {}
        }, message: {
            Text(errorMessage ?? "Intenta de nuevo.")
        })
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Controla tus pagos recurrentes y regístralos cuando toque.")
                .font(DarkFinanceTypography.body(size: 14))
                .foregroundColor(DarkFinanceColors.secondaryText)

            HStack(spacing: 12) {
                summaryMetric(
                    title: "Activas",
                    value: "\(allActiveSubscriptions.count)",
                    accent: DarkFinanceColors.primaryAccent
                )

                summaryMetric(
                    title: "Esta semana",
                    value: "\(upcomingThisWeekCount)",
                    accent: DarkFinanceColors.successGreen
                )

                summaryMetric(
                    title: "Mensual",
                    value: monthlyTotalText,
                    accent: DarkFinanceColors.primaryText
                )
            }
        }
        .darkFinanceCard(cornerRadius: 20, padding: 20)
    }

    private var monthlyTotalText: String {
        let grouped = Dictionary(grouping: allActiveSubscriptions, by: \.currency)
        let parts = Currency.allCases.compactMap { currency -> String? in
            let total = grouped[currency, default: []].reduce(0) { $0 + $1.userExpenseAmount }
            guard total > 0 else { return nil }
            return total.formatted(.currency(code: currency.rawValue).precision(.fractionLength(0)))
        }
        return parts.isEmpty ? "0" : parts.joined(separator: " + ")
    }

    private var filterTabs: some View {
        Picker("Filtro", selection: $quickFilter) {
            ForEach(SubscriptionQuickFilter.allCases) { filter in
                Text(filter.title).tag(filter)
            }
        }
        .pickerStyle(.segmented)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "rectangle.stack.badge.person.crop")
                .font(.system(size: 30, weight: .medium))
                .foregroundColor(DarkFinanceColors.tertiaryText)
            Text("No tienes suscripciones registradas")
                .font(DarkFinanceTypography.emphasis(size: 15))
                .foregroundColor(DarkFinanceColors.primaryText)
            Text("Añade una suscripción o usa una plantilla para empezar.")
                .font(DarkFinanceTypography.body(size: 13))
                .foregroundColor(DarkFinanceColors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .darkFinanceCard(cornerRadius: 20, padding: 20)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(DarkFinanceTypography.action(size: 12, weight: .semibold))
            .foregroundColor(DarkFinanceColors.secondaryText)
    }

    private func subscriptionRow(_ subscription: Subscription) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                SubscriptionLogoView(subscription: subscription, size: 40)

                VStack(alignment: .leading, spacing: 4) {
                    Text(subscription.platformName)
                        .font(DarkFinanceTypography.emphasis(size: 15))
                        .foregroundColor(DarkFinanceColors.primaryText)
                    Text(subscription.planName)
                        .font(DarkFinanceTypography.body(size: 12))
                        .foregroundColor(DarkFinanceColors.secondaryText)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(subscription.userExpenseAmount, format: .currency(code: subscription.currency.rawValue).precision(.fractionLength(0)))
                        .font(DarkFinanceTypography.monoAmount(size: 14, weight: .semibold))
                        .foregroundColor(DarkFinanceColors.primaryText)
                    Text(subscription.isActive ? "Día \(subscription.billingDay)" : "Cancelada")
                        .font(DarkFinanceTypography.body(size: 11))
                        .foregroundColor(DarkFinanceColors.tertiaryText)
                }
            }

            HStack(spacing: 8) {
                actionPill(title: "Registrar", systemImage: "plus") {
                    let result = subscriptionManager.registerAsExpense(subscription)
                    if case let .failure(error) = result {
                        errorMessage = error.errorDescription
                        showingError = true
                    }
                }
                .disabled(!subscription.isActive)
                .opacity(subscription.isActive ? 1.0 : 0.45)

                actionPill(title: subscription.isActive ? "Cancelar" : "Inactiva", systemImage: "xmark") {
                    if subscription.isActive {
                        subscriptionManager.cancelSubscription(subscription)
                    }
                }
                .disabled(!subscription.isActive)
                .opacity(subscription.isActive ? 1.0 : 0.45)

                actionPill(title: "Editar", systemImage: "pencil") {
                    navigationPath.append(SubscriptionSheetRoute.edit(subscription))
                }
            }
        }
        .darkFinanceCard(cornerRadius: 18, padding: 16)
        .contentShape(Rectangle())
        .onTapGesture {
            navigationPath.append(SubscriptionSheetRoute.detail(subscription))
        }
    }

    @ViewBuilder
    private func destinationView(for route: SubscriptionSheetRoute) -> some View {
        switch route {
        case .new:
            SubscriptionEditorView { subscription in
                subscriptionManager.addSubscription(subscription)
            }
        case let .edit(subscription):
            SubscriptionEditorView(subscription: subscription) { updated in
                subscriptionManager.updateSubscription(updated)
            } onDelete: { deleting in
                subscriptionManager.deleteSubscription(deleting)
            }
        case let .detail(subscription):
            SubscriptionDetailView(subscription: subscription)
        case .templates:
            SubscriptionTemplatesView()
        }
    }

    private func summaryMetric(title: String, value: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(DarkFinanceTypography.body(size: 11))
                .foregroundColor(DarkFinanceColors.tertiaryText)
            Text(value)
                .font(DarkFinanceTypography.monoAmount(size: 15, weight: .semibold))
                .foregroundColor(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(DarkFinanceColors.inputBackground)
        )
    }

    @ViewBuilder
    private func actionPill(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(DarkFinanceTypography.action(size: 12, weight: .semibold))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
    }

    private func isInUpcomingWeek(_ subscription: Subscription) -> Bool {
        let calendar = Calendar.current
        let now = Date()
        let start = calendar.startOfDay(for: now)
        guard
            let nextDate = nextBillingDate(for: subscription, from: now, calendar: calendar),
            let end = calendar.date(byAdding: .day, value: 7, to: start)
        else {
            return false
        }

        return nextDate >= start && nextDate < end
    }

    private func nextBillingDate(for subscription: Subscription, from date: Date, calendar: Calendar) -> Date? {
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) else {
            return nil
        }

        if let currentMonthBilling = billingDate(inMonthOf: monthStart, day: subscription.billingDay, calendar: calendar),
           currentMonthBilling >= calendar.startOfDay(for: date) {
            return currentMonthBilling
        }

        guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthStart) else { return nil }
        return billingDate(inMonthOf: nextMonth, day: subscription.billingDay, calendar: calendar)
    }

    private func billingDate(inMonthOf date: Date, day: Int, calendar: Calendar) -> Date? {
        let range = calendar.range(of: .day, in: .month, for: date)
        let clampedDay = min(max(1, day), range?.count ?? 28)
        var components = calendar.dateComponents([.year, .month], from: date)
        components.day = clampedDay
        return calendar.date(from: components)
    }
}

private enum SubscriptionSheetRoute: Hashable {
    case new
    case edit(Subscription)
    case detail(Subscription)
    case templates
}

private struct SubscriptionLogoView: View {
    let subscription: Subscription
    let size: CGFloat

    var body: some View {
        Group {
            if let data = subscription.logoImageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else if let urlString = subscription.logoURLString, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case let .success(image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        fallbackLogo
                    }
                }
            } else {
                fallbackLogo
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(DarkFinanceColors.cardBorder, lineWidth: 1)
        )
    }

    private var fallbackLogo: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color(hex: "1A1A1D"))
            .overlay(
                Image(systemName: "photo")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            )
    }
}

private enum SubscriptionQuickFilter: String, CaseIterable, Identifiable {
    case all
    case thisWeek

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "Todas"
        case .thisWeek: return "Esta semana"
        }
    }
}

private struct SubscriptionDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let subscription: Subscription

    var body: some View {
        List {
            Section("Suscripción") {
                HStack(spacing: 12) {
                    SubscriptionLogoView(subscription: subscription, size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(subscription.platformName)
                            .font(.headline)
                        Text(subscription.planName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Section("Pago") {
                detailRow("Precio mensual", subscription.userExpenseAmount.formatted(.currency(code: subscription.currency.rawValue)))
                detailRow("Día de pago", "Día \(subscription.billingDay)")
                if let format = subscription.logoImageFormat, !format.isEmpty {
                    detailRow("Formato del logo", format.uppercased())
                }
            }

            Section("Compartición") {
                detailRow("Compartida", subscription.isShared ? "Sí" : "No")
                if subscription.isShared {
                    detailRow("Personas", "\(subscription.sharedPeopleCount)")
                    detailRow("División", subscription.splitEqually ? "Partes iguales" : "Personalizada")
                    if !subscription.splitEqually {
                        let amount = subscription.personalShareAmount ?? subscription.userExpenseAmount
                        detailRow("Tu parte", amount.formatted(.currency(code: subscription.currency.rawValue)))
                    }
                }
            }
        }
        .navigationTitle("Detalle")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cerrar") { dismiss() }
            }
        }
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}

private extension View {
    @ViewBuilder
    func ifAvailableIOS26Glass() -> some View {
        if #available(iOS 26.0, *) {
            self.buttonStyle(.glass)
        } else {
            self.buttonStyle(.bordered)
        }
    }
}

private struct SubscriptionEditorView: View {
    @Environment(\.dismiss) private var dismiss

    private let original: Subscription?
    private let onSave: (Subscription) -> Void
    private let onDelete: ((Subscription) -> Void)?

    @State private var platformName: String
    @State private var planName: String
    @State private var price: Double
    @State private var currency: Currency
    @State private var isShared: Bool
    @State private var sharedPeopleCount: Int
    @State private var splitEqually: Bool
    @State private var personalShareAmount: Double
    @State private var billingDay: Int
    @State private var isActive: Bool

    @State private var logoImageData: Data?
    @State private var logoURLString: String?
    @State private var logoImageFormat: String?
    @State private var logoSource: LogoSource = .internet
    @State private var selectedLocalImage: UIImage?

    @State private var searchQuery: String
    @State private var searchResults: [LogoSearchResult] = []
    @State private var isSearching = false
    @State private var showingPhotoPicker = false

    init(
        subscription: Subscription? = nil,
        onSave: @escaping (Subscription) -> Void,
        onDelete: ((Subscription) -> Void)? = nil
    ) {
        self.original = subscription
        self.onSave = onSave
        self.onDelete = onDelete

        _platformName = State(initialValue: subscription?.platformName ?? "")
        _planName = State(initialValue: subscription?.planName ?? "")
        _price = State(initialValue: subscription?.price ?? 0)
        _currency = State(initialValue: subscription?.currency ?? .cup)
        _isShared = State(initialValue: subscription?.isShared ?? false)
        _sharedPeopleCount = State(initialValue: max(2, subscription?.sharedPeopleCount ?? 2))
        _splitEqually = State(initialValue: subscription?.splitEqually ?? true)
        _personalShareAmount = State(initialValue: subscription?.personalShareAmount ?? 0)
        _billingDay = State(initialValue: subscription?.billingDay ?? 5)
        _isActive = State(initialValue: subscription?.isActive ?? true)

        _logoImageData = State(initialValue: subscription?.logoImageData)
        _logoURLString = State(initialValue: subscription?.logoURLString)
        _logoImageFormat = State(initialValue: subscription?.logoImageFormat)
        _searchQuery = State(initialValue: subscription?.platformName ?? "")
    }

    var body: some View {
        Form {
            Section("Plataforma") {
                TextField("Nombre", text: $platformName)
                TextField("Plan", text: $planName)
            }

            Section("Logo") {
                logoPreview

                Picker("Fuente", selection: $logoSource) {
                    ForEach(LogoSource.allCases) { source in
                        Text(source.title).tag(source)
                    }
                }
                .pickerStyle(.segmented)

                if logoSource == .internet {
                    HStack {
                        TextField("Buscar logo en internet", text: $searchQuery)
                        Button("Buscar") {
                            searchLogos()
                        }
                        .disabled(searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSearching)
                    }

                    if isSearching {
                        HStack {
                            ProgressView()
                            Text("Buscando logos...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    if !searchResults.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(searchResults) { result in
                                    logoResultCard(result)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                } else {
                    Button {
                        showingPhotoPicker = true
                    } label: {
                        Label("Seleccionar imagen local", systemImage: "photo.on.rectangle")
                    }
                }
            }

            Section("Precio") {
                TextField("Precio", value: $price, format: .number.precision(.fractionLength(2)))
                    .keyboardType(.decimalPad)
                Picker("Moneda", selection: $currency) {
                    ForEach(Currency.allCases) { currency in
                        Text(currency.rawValue).tag(currency)
                    }
                }
            }

            Section("Compartición") {
                Toggle("Suscripción compartida", isOn: $isShared)
                if isShared {
                    Stepper("Se comparte entre \(sharedPeopleCount) personas", value: $sharedPeopleCount, in: 2...20)
                    Toggle("Dividir a partes iguales", isOn: $splitEqually)
                    if !splitEqually {
                        TextField("Monto que te corresponde", value: $personalShareAmount, format: .number.precision(.fractionLength(2)))
                            .keyboardType(.decimalPad)
                    }
                }
            }

            Section("Pago") {
                Stepper("Día de pago: \(billingDay)", value: $billingDay, in: 1...31)
                Toggle("Activa", isOn: $isActive)
            }

            if let original, let onDelete {
                Section {
                    Button("Eliminar suscripción", role: .destructive) {
                        onDelete(original)
                        dismiss()
                    }
                }
            }
        }
        .navigationTitle(original == nil ? "Nueva suscripción" : "Editar suscripción")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Guardar") {
                    onSave(buildSubscription())
                    dismiss()
                }
                .disabled(!canSave)
            }
        }
        .sheet(isPresented: $showingPhotoPicker) {
            PhotoLibraryImagePicker(image: $selectedLocalImage)
        }
        .onChange(of: selectedLocalImage) { _, image in
            guard let image else { return }
            if let png = image.pngData() {
                logoImageData = png
                logoImageFormat = "png"
            } else if let jpeg = image.jpegData(compressionQuality: 0.9) {
                logoImageData = jpeg
                logoImageFormat = "jpg"
            }
            logoURLString = nil
        }
    }

    private var canSave: Bool {
        !platformName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !planName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        price > 0
    }

    private var logoPreview: some View {
        HStack(spacing: 12) {
            Group {
                if let data = logoImageData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else if let urlString = logoURLString, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case let .success(image):
                            image
                                .resizable()
                                .scaledToFill()
                        default:
                            placeholderLogo
                        }
                    }
                } else {
                    placeholderLogo
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(DarkFinanceColors.cardBorder, lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: 4) {
                Text("Logo actual")
                    .font(.subheadline.weight(.semibold))
                if let format = logoImageFormat {
                    Text("Formato: \(format.uppercased())")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("Sin formato detectado")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var placeholderLogo: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(hex: "1A1A1D"))
            .overlay(
                Image(systemName: "photo")
                    .foregroundColor(.white)
            )
    }

    private func logoResultCard(_ result: LogoSearchResult) -> some View {
        Button {
            Task {
                await selectRemoteLogo(result)
            }
        } label: {
            VStack(spacing: 8) {
                AsyncImage(url: result.imageURL) { phase in
                    switch phase {
                    case let .success(image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(hex: "1A1A1D"))
                            .overlay(ProgressView())
                    }
                }
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                Text(result.title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                Text(result.format.uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(result.format.lowercased() == "png" ? .green : .secondary)
            }
            .frame(width: 82)
        }
        .buttonStyle(.plain)
    }

    private func buildSubscription() -> Subscription {
        let hasLocalLogoData = logoImageData != nil
        return Subscription(
            id: original?.id ?? UUID(),
            platformName: platformName.trimmingCharacters(in: .whitespacesAndNewlines),
            planName: planName.trimmingCharacters(in: .whitespacesAndNewlines),
            price: price,
            currency: currency,
            logoImageData: logoImageData,
            logoURLString: hasLocalLogoData ? nil : logoURLString,
            logoImageFormat: logoImageFormat,
            isShared: isShared,
            sharedPeopleCount: isShared ? sharedPeopleCount : 1,
            splitEqually: isShared ? splitEqually : true,
            personalShareAmount: isShared && !splitEqually ? personalShareAmount : nil,
            billingDay: billingDay,
            isActive: isActive,
            createdAt: original?.createdAt ?? Date(),
            updatedAt: Date()
        )
    }

    private func searchLogos() {
        let term = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return }

        isSearching = true
        Task {
            let results = await LogoSearchService.shared.search(term: term)
            await MainActor.run {
                self.searchResults = results
                self.isSearching = false
            }
        }
    }

    private func selectRemoteLogo(_ result: LogoSearchResult) async {
        do {
            let (data, response) = try await URLSession.shared.data(from: result.imageURL)
            guard !data.isEmpty else { return }

            let mimeType = (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Content-Type")?.lowercased()
            let detectedFormat: String
            if mimeType?.contains("png") == true || result.imageURL.absoluteString.lowercased().contains(".png") {
                detectedFormat = "png"
            } else if mimeType?.contains("jpeg") == true || mimeType?.contains("jpg") == true || result.imageURL.absoluteString.lowercased().contains(".jpg") || result.imageURL.absoluteString.lowercased().contains(".jpeg") {
                detectedFormat = "jpg"
            } else {
                detectedFormat = result.format
            }

            await MainActor.run {
                logoImageData = data
                // Persistimos localmente para no depender de la URL remota.
                logoURLString = nil
                logoImageFormat = detectedFormat
            }
        } catch {
            print("Error downloading logo image: \(error)")
        }
    }
}

private enum LogoSource: String, CaseIterable, Identifiable {
    case internet
    case local

    var id: String { rawValue }

    var title: String {
        switch self {
        case .internet: return "Internet"
        case .local: return "Local"
        }
    }
}

private struct LogoSearchResult: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let imageURL: URL
    let format: String
}

private struct ITunesSearchResponse: Decodable {
    let results: [ITunesResult]
}

private struct ITunesResult: Decodable {
    let trackName: String?
    let sellerName: String?
    let artworkUrl100: String?
}

private final class LogoSearchService {
    static let shared = LogoSearchService()

    private init() {}

    func search(term: String) async -> [LogoSearchResult] {
        guard let query = term.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://itunes.apple.com/search?term=\(query)&entity=software&limit=20")
        else {
            return []
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(ITunesSearchResponse.self, from: data)

            let mapped: [LogoSearchResult] = response.results.compactMap { item in
                guard let artwork = item.artworkUrl100,
                      let imageURL = URL(string: artwork.replacingOccurrences(of: "100x100bb", with: "512x512bb"))
                else {
                    return nil
                }

                let lower = imageURL.absoluteString.lowercased()
                let format: String
                if lower.contains(".png") {
                    format = "png"
                } else if lower.contains(".jpg") || lower.contains(".jpeg") {
                    format = "jpg"
                } else {
                    format = "img"
                }

                return LogoSearchResult(
                    title: item.trackName ?? item.sellerName ?? "Logo",
                    imageURL: imageURL,
                    format: format
                )
            }

            var unique: [LogoSearchResult] = []
            var seen = Set<String>()
            for item in mapped where seen.insert(item.imageURL.absoluteString).inserted {
                unique.append(item)
            }
            return unique
        } catch {
            print("Error searching logos: \(error)")
            return []
        }
    }
}

private struct SubscriptionTemplatesView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var subscriptionManager: SubscriptionManager

    var body: some View {
        List {
            if subscriptionManager.templates.isEmpty {
                Text("No hay plantillas disponibles")
                    .foregroundColor(.secondary)
            } else {
                ForEach(subscriptionManager.templates) { template in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 10) {
                            templateLogo(template)

                            Text(template.platformName)
                                .font(.headline)

                            Spacer()
                            Text(template.price, format: .currency(code: template.currency.rawValue))
                                .font(.subheadline.weight(.semibold))
                        }

                        Text(template.planName)
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if let format = template.logoImageFormat {
                            Text(format.uppercased())
                                .font(.caption2.weight(.semibold))
                                .foregroundColor(format.lowercased() == "png" ? .green : .secondary)
                        }

                        Button {
                            subscriptionManager.createSubscription(from: template)
                            dismiss()
                        } label: {
                            Label("Crear suscripción", systemImage: "plus.circle")
                                .font(.system(size: 13, weight: .semibold))
                        }
                    }
                    .padding(.vertical, 4)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            subscriptionManager.deleteTemplate(template)
                        } label: {
                            Label("Eliminar", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .navigationTitle("Plantillas")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cerrar") {
                    dismiss()
                }
            }
        }
    }

    private func templateLogo(_ template: SubscriptionTemplate) -> some View {
        Group {
            if let data = template.logoImageData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if let urlString = template.logoURLString, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case let .success(image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray5))
                    }
                }
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray5))
                    .overlay(Image(systemName: "photo"))
            }
        }
        .frame(width: 32, height: 32)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
