import SwiftUI
import Combine

struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var showFilterSheet = false
    @FocusState private var isInputFocused: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var keyboardHeight: CGFloat = 0

    var body: some View {
        ZStack(alignment: .top) {
            // Background color de iMessage
            Color(UIColor.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Lista de mensajes
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            // Botón de filtros en la parte superior
                            filterButton
                                .padding(.top, 8)
                                .padding(.bottom, 4)

                            ForEach(viewModel.messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }

                            if viewModel.isLoading {
                                HStack {
                                    TypingIndicatorBubble()
                                    Spacer(minLength: 50)
                                }
                                .padding(.horizontal, 16)
                            }

                            // Espaciado al final para que el último mensaje no quede oculto
                            Color.clear.frame(height: 8)
                        }
                        .padding(.horizontal, 8)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: viewModel.messages.count) { _ in
                        if let lastMessage = viewModel.messages.last {
                            withAnimation(.easeOut(duration: 0.25)) {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }

                // Input de mensaje estilo iMessage
                messageInputBar
                    .padding(.bottom, keyboardHeight)
                    .animation(.easeOut(duration: 0.25), value: keyboardHeight)
            }
        }
        .navigationTitle("FinancIA")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                        Text("Atrás")
                    }
                    .foregroundColor(.blue)
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { showFilterSheet = true }) {
                        Label("Filtros", systemImage: "line.3.horizontal.decrease.circle")
                    }
                    Divider()
                    Button(role: .destructive, action: viewModel.clearMessages) {
                        Label("Limpiar chat", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.blue)
                }
            }
        }
        .sheet(isPresented: $showFilterSheet) {
            FilterSheet(
                transactionFilter: $viewModel.transactionFilter,
                timePeriod: $viewModel.timePeriod
            )
        }
        .onAppear {
            setupKeyboardObservers()
        }
    }

    // MARK: - Subviews

    private var filterButton: some View {
        HStack {
            Button(action: { showFilterSheet = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "line.3.horizontal.decrease.circle.fill")
                        .font(.system(size: 14))
                    Text("\(viewModel.transactionFilter.rawValue) · \(viewModel.timePeriod.rawValue)")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(.blue)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.1))
                .clipShape(Capsule())
            }

            Spacer()
        }
        .padding(.horizontal, 8)
    }

    private var messageInputBar: some View {
        VStack(spacing: 0) {
            Divider()
                .background(Color(.separator))

            HStack(alignment: .bottom, spacing: 8) {
                // TextField con estilo iMessage
                HStack {
                    TextField("iMessage", text: $viewModel.currentInput, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.system(size: 17))
                        .lineLimit(1...5)
                        .focused($isInputFocused)
                        .submitLabel(.send)
                        .onSubmit {
                            Task {
                                await viewModel.sendMessage()
                            }
                        }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(.systemGray6))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color(.systemGray4), lineWidth: 0.5)
                )

                // Botón de envío estilo iMessage
                Button(action: {
                    Task {
                        await viewModel.sendMessage()
                    }
                }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(
                            viewModel.currentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? Color(.systemGray3)
                            : Color.blue
                        )
                }
                .disabled(viewModel.currentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .padding(.bottom, 2)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color(.systemBackground))
        }
    }

    // MARK: - Keyboard Handling

    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard let userInfo = notification.userInfo,
                  let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
                return
            }

            let window = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }

            let bottomSafeArea = window?.safeAreaInsets.bottom ?? 0
            keyboardHeight = keyboardFrame.height - bottomSafeArea
        }

        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { _ in
            keyboardHeight = 0
        }
    }
}

// MARK: - MessageBubble

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            if message.isUser {
                Spacer(minLength: 60)
            }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 2) {
                // Burbuja de mensaje con tail estilo iMessage
                Text(messageAttributedText)
                    .font(.system(size: 17))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .foregroundColor(message.isUser ? .white : Color(.label))
                    .background(
                        MessageBubbleShape(isFromCurrentUser: message.isUser)
                            .fill(message.isUser ? Color.blue : Color(.systemGray5))
                    )
                    .frame(maxWidth: UIScreen.main.bounds.width * 0.7, alignment: message.isUser ? .trailing : .leading)

                // Timestamp discreto
                Text(message.timestamp, style: .time)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
            }

            if !message.isUser {
                Spacer(minLength: 60)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 1)
    }

    private var messageAttributedText: AttributedString {
        guard !message.isUser else { return AttributedString(message.content) }
        if let attributed = try? AttributedString(markdown: message.content) {
            return attributed
        }
        return AttributedString(message.content)
    }
}

// MARK: - MessageBubbleShape (iMessage tail)

struct MessageBubbleShape: Shape {
    let isFromCurrentUser: Bool

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: isFromCurrentUser
                ? [.topLeft, .topRight, .bottomLeft]
                : [.topLeft, .topRight, .bottomRight],
            cornerRadii: CGSize(width: 18, height: 18)
        )

        if isFromCurrentUser {
            // Tail para mensajes del usuario (derecha)
            let tailWidth: CGFloat = 8
            let tailHeight: CGFloat = 12
            let tailPath = UIBezierPath()
            tailPath.move(to: CGPoint(x: rect.maxX, y: rect.maxY - 2))
            tailPath.addQuadCurve(
                to: CGPoint(x: rect.maxX + tailWidth, y: rect.maxY),
                controlPoint: CGPoint(x: rect.maxX + 2, y: rect.maxY - 4)
            )
            tailPath.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - tailHeight))
            path.append(tailPath)
        } else {
            // Tail para mensajes del asistente (izquierda)
            let tailWidth: CGFloat = 8
            let tailHeight: CGFloat = 12
            let tailPath = UIBezierPath()
            tailPath.move(to: CGPoint(x: rect.minX, y: rect.maxY - 2))
            tailPath.addQuadCurve(
                to: CGPoint(x: rect.minX - tailWidth, y: rect.maxY),
                controlPoint: CGPoint(x: rect.minX - 2, y: rect.maxY - 4)
            )
            tailPath.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - tailHeight))
            path.append(tailPath)
        }

        return Path(path.cgPath)
    }
}

private struct TypingIndicatorBubble: View {
    var body: some View {
        HStack {
            TypingIndicator()
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    MessageBubbleShape(isFromCurrentUser: false)
                        .fill(Color(.systemGray5))
                )
            Spacer()
        }
    }
}

private struct TypingIndicator: View {
    @State private var phase = 0
    private let timer = Timer.publish(every: 0.35, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.gray.opacity(0.7))
                    .frame(width: 8, height: 8)
                    .scaleEffect(phase == index ? 1.2 : 0.8)
                    .opacity(phase == index ? 1.0 : 0.5)
            }
        }
        .onReceive(timer) { _ in
            phase = (phase + 1) % 3
        }
        .accessibilityLabel("Escribiendo")
    }
}

// MARK: - FilterSheet

struct FilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var transactionFilter: TransactionFilter
    @Binding var timePeriod: TimePeriod

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Picker("Tipo", selection: $transactionFilter) {
                        ForEach(TransactionFilter.allCases, id: \.self) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                    .pickerStyle(.inline)
                } header: {
                    Text("TIPO DE TRANSACCIÓN")
                } footer: {
                    Text("El asistente usará solo estas transacciones como contexto")
                        .font(.footnote)
                }

                Section {
                    Picker("Periodo", selection: $timePeriod) {
                        ForEach(TimePeriod.allCases, id: \.self) { period in
                            Text(period.rawValue).tag(period)
                        }
                    }
                    .pickerStyle(.inline)
                } header: {
                    Text("PERIODO DE TIEMPO")
                } footer: {
                    Text("Rango de fechas de las transacciones a analizar")
                        .font(.footnote)
                }
            }
            .navigationTitle("Filtros de Contexto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Listo") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ChatView()
    }
}
