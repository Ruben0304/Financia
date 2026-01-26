import SwiftUI
import Combine

struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var showFilterSheet = false
    @FocusState private var isInputFocused: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header con filtros
            filterHeader

            // Lista de mensajes
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }

                        if viewModel.isLoading {
                            HStack {
                                TypingIndicatorBubble()
                                Spacer(minLength: 50)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .background(Color(.systemGroupedBackground))
                .onChange(of: viewModel.messages.count) { _ in
                    if let lastMessage = viewModel.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }

            // Input de mensaje
            messageInput
        }
        .navigationTitle("Asistente FinancIA")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(role: .destructive, action: viewModel.clearMessages) {
                        Label("Limpiar chat", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showFilterSheet) {
            FilterSheet(
                transactionFilter: $viewModel.transactionFilter,
                timePeriod: $viewModel.timePeriod
            )
        }
    }

    // MARK: - Subviews

    private var filterHeader: some View {
        HStack {
            Button(action: { showFilterSheet = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.body)
                    Text("\(viewModel.transactionFilter.rawValue) · \(viewModel.timePeriod.rawValue)")
                        .font(.subheadline)
                }
                .foregroundColor(.blue)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)

            Spacer()
        }
        .background(Color(.systemGroupedBackground))
    }

    private var messageInput: some View {
        HStack(spacing: 12) {
            TextField("Escribe tu pregunta...", text: $viewModel.currentInput, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(18)
                .focused($isInputFocused)
                .onSubmit {
                    Task {
                        await viewModel.sendMessage()
                    }
                }

            Button(action: {
                Task {
                    await viewModel.sendMessage()
                }
            }) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(viewModel.currentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .blue)
            }
            .disabled(viewModel.currentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

// MARK: - MessageBubble

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.isUser {
                Spacer(minLength: 50)
            }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                Text(messageAttributedText)
                    .padding(12)
                    .background(message.isUser ? Color.blue : Color(.systemGray5))
                    .foregroundColor(message.isUser ? .white : .primary)
                    .cornerRadius(18)
                    .frame(maxWidth: 260, alignment: message.isUser ? .trailing : .leading)

                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if !message.isUser {
                Spacer(minLength: 50)
            }
        }
    }

    private var messageAttributedText: AttributedString {
        guard !message.isUser else { return AttributedString(message.content) }
        if let attributed = try? AttributedString(markdown: message.content) {
            return attributed
        }
        return AttributedString(message.content)
    }
}

private struct TypingIndicatorBubble: View {
    var body: some View {
        TypingIndicator()
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.systemGray5))
            .cornerRadius(18)
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
                    Picker("Tipo de transacción", selection: $transactionFilter) {
                        ForEach(TransactionFilter.allCases, id: \.self) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                    .pickerStyle(.inline)
                } header: {
                    Text("Tipo de transacción")
                } footer: {
                    Text("Selecciona qué tipo de transacciones incluir en el contexto del chat")
                }

                Section {
                    Picker("Periodo de tiempo", selection: $timePeriod) {
                        ForEach(TimePeriod.allCases, id: \.self) { period in
                            Text(period.rawValue).tag(period)
                        }
                    }
                    .pickerStyle(.inline)
                } header: {
                    Text("Periodo de tiempo")
                } footer: {
                    Text("Selecciona el rango de fechas de las transacciones a analizar")
                }
            }
            .navigationTitle("Filtros")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Listo") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ChatView()
    }
}
