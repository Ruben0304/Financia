import SwiftUI
import Combine

struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var showFilterSheet = false
    @FocusState private var isInputFocused: Bool

    var body: some View {
        ZStack(alignment: .top) {
            DarkFinanceBackground()

            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 4) {
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

                            Color.clear.frame(height: 8)
                        }
                        .padding(.horizontal, 8)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: viewModel.messages.count) { _, _ in
                        if let lastMessage = viewModel.messages.last {
                            withAnimation(.easeOut(duration: 0.25)) {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                    // Auto-scroll during streaming as AI content grows
                    .onChange(of: viewModel.messages.last?.content) { _, _ in
                        if let lastMessage = viewModel.messages.last, !lastMessage.isUser {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .navigationTitle("FinancIA")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
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
                        .foregroundColor(DarkFinanceColors.primaryAccent)
                }
            }

            ToolbarItem(placement: .bottomBar) {
                TextField("Escribe un mensaje", text: $viewModel.currentInput)
                    .autocorrectionDisabled()
                    .focused($isInputFocused)
                    .submitLabel(.send)
                    .foregroundColor(DarkFinanceColors.primaryText)
                    .onSubmit {
                        Task { await viewModel.sendMessage() }
                    }
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity)
            }

            if #available(iOS 26.0, *) {
                ToolbarSpacer(.fixed, placement: .bottomBar)
                ToolbarItem(placement: .bottomBar) {
                    Button(action: { Task { await viewModel.sendMessage() } }) {
                        Image(systemName: "paperplane")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(DarkFinanceColors.primaryAccent)
                    }
                    .disabled(viewModel.currentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            } else {
                ToolbarItem(placement: .bottomBar) {
                    Button(action: { Task { await viewModel.sendMessage() } }) {
                        Image(systemName: "paperplane")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(DarkFinanceColors.primaryAccent)
                    }
                    .disabled(viewModel.currentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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

    // MARK: - Filter button

    private var filterButton: some View {
        HStack {
            Button(action: { showFilterSheet = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "line.3.horizontal.decrease.circle.fill")
                        .font(.system(size: 14))
                    Text("\(viewModel.transactionFilter.rawValue) · \(viewModel.timePeriod.rawValue)")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(DarkFinanceColors.primaryAccent)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(DarkFinanceColors.primaryAccent.opacity(0.15))
                .clipShape(Capsule())
            }
            Spacer()
        }
        .padding(.horizontal, 8)
    }
}

// MARK: - MessageBubble

struct MessageBubble: View {
    let message: ChatMessage

    private let maxWidthFraction: CGFloat = 0.78

    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            if message.isUser { Spacer(minLength: 50) }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 2) {
                if message.isUser {
                    // User bubble: plain text
                    Text(message.content)
                        .font(.system(size: 17))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .foregroundColor(.white)
                        .background(
                            MessageBubbleShape(isFromCurrentUser: true)
                                .fill(DarkFinanceColors.primaryAccent)
                        )
                        .frame(maxWidth: UIScreen.main.bounds.width * maxWidthFraction, alignment: .trailing)
                } else {
                    // AI bubble: markdown rendered
                    MarkdownContentView(
                        text: message.content,
                        textColor: DarkFinanceColors.primaryText
                    )
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        MessageBubbleShape(isFromCurrentUser: false)
                            .fill(DarkFinanceColors.inputBackground)
                    )
                    .frame(maxWidth: UIScreen.main.bounds.width * maxWidthFraction, alignment: .leading)
                }

                Text(message.timestamp, style: .time)
                    .font(.system(size: 11))
                    .foregroundColor(DarkFinanceColors.secondaryText)
                    .padding(.horizontal, 4)
            }

            if !message.isUser { Spacer(minLength: 50) }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 1)
    }
}

// MARK: - MarkdownContentView

/// Renders Markdown content as SwiftUI views, handling streaming gracefully.
private struct MarkdownContentView: View {
    let text: String
    let textColor: Color
    private let fontSize: CGFloat = 17

    var body: some View {
        let blocks = parseMarkdown(text)
        return VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                blockView(for: block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func blockView(for block: MdBlock) -> some View {
        switch block {

        case .heading(let level, let content):
            let size: CGFloat = level == 1 ? fontSize + 7 : level == 2 ? fontSize + 4 : fontSize + 1
            let weight: Font.Weight = level == 1 ? .bold : .semibold
            Text(inlineMarkdown(content))
                .font(.system(size: size, weight: weight))
                .foregroundColor(textColor)

        case .paragraph(let content):
            Text(inlineMarkdown(content))
                .font(.system(size: fontSize))
                .foregroundColor(textColor)
                .fixedSize(horizontal: false, vertical: true)

        case .bulletList(let items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .font(.system(size: fontSize))
                            .foregroundColor(textColor)
                        Text(inlineMarkdown(item))
                            .font(.system(size: fontSize))
                            .foregroundColor(textColor)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

        case .orderedList(let items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(i + 1).")
                            .font(.system(size: fontSize, weight: .medium))
                            .foregroundColor(textColor)
                            .frame(minWidth: 22, alignment: .trailing)
                        Text(inlineMarkdown(item))
                            .font(.system(size: fontSize))
                            .foregroundColor(textColor)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

        case .codeBlock(let code, _):
            Text(code)
                .font(.system(size: fontSize - 2, design: .monospaced))
                .foregroundColor(textColor.opacity(0.9))
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.black.opacity(0.25))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

        case .divider:
            Divider()
                .background(textColor.opacity(0.3))
                .padding(.vertical, 2)
        }
    }

    /// Parses inline markdown (bold, italic, code) using AttributedString.
    private func inlineMarkdown(_ raw: String) -> AttributedString {
        var options = AttributedString.MarkdownParsingOptions()
        options.interpretedSyntax = .inlinesOnlyPreservingWhitespace
        if let attributed = try? AttributedString(markdown: raw, options: options) {
            return attributed
        }
        return AttributedString(raw)
    }
}

// MARK: - Markdown Block Types

private enum MdBlock {
    case heading(level: Int, text: String)
    case paragraph(text: String)
    case bulletList(items: [String])
    case orderedList(items: [String])
    case codeBlock(code: String, language: String?)
    case divider
}

// MARK: - Markdown Parser

/// Splits markdown text into semantic blocks for rendering.
/// Handles incomplete/streaming content gracefully.
private func parseMarkdown(_ text: String) -> [MdBlock] {
    var blocks: [MdBlock] = []
    let lines = text.components(separatedBy: "\n")
    var i = 0
    var paragraphLines: [String] = []
    var inCodeBlock = false
    var codeLang: String? = nil
    var codeLines: [String] = []

    func flushParagraph() {
        let joined = paragraphLines
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !joined.isEmpty {
            blocks.append(.paragraph(text: joined))
        }
        paragraphLines = []
    }

    while i < lines.count {
        let line = lines[i]

        // ── Code block ────────────────────────────────────────────
        if inCodeBlock {
            if line.hasPrefix("```") {
                blocks.append(.codeBlock(code: codeLines.joined(separator: "\n"), language: codeLang))
                codeLines = []; codeLang = nil; inCodeBlock = false
            } else {
                codeLines.append(line)
            }
            i += 1; continue
        }

        if line.hasPrefix("```") {
            flushParagraph()
            inCodeBlock = true
            let lang = String(line.dropFirst(3)).trimmingCharacters(in: .whitespacesAndNewlines)
            codeLang = lang.isEmpty ? nil : lang
            i += 1; continue
        }

        // ── Headings ──────────────────────────────────────────────
        if line.hasPrefix("### ") {
            flushParagraph()
            blocks.append(.heading(level: 3, text: String(line.dropFirst(4))))
            i += 1; continue
        }
        if line.hasPrefix("## ") {
            flushParagraph()
            blocks.append(.heading(level: 2, text: String(line.dropFirst(3))))
            i += 1; continue
        }
        if line.hasPrefix("# ") {
            flushParagraph()
            blocks.append(.heading(level: 1, text: String(line.dropFirst(2))))
            i += 1; continue
        }

        // ── Horizontal rule ───────────────────────────────────────
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed == "---" || trimmed == "***" || trimmed == "___" {
            flushParagraph()
            blocks.append(.divider)
            i += 1; continue
        }

        // ── Bullet list ───────────────────────────────────────────
        if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ") {
            flushParagraph()
            var items: [String] = []
            while i < lines.count {
                let l = lines[i]
                if l.hasPrefix("- ") { items.append(String(l.dropFirst(2))); i += 1 }
                else if l.hasPrefix("* ") { items.append(String(l.dropFirst(2))); i += 1 }
                else if l.hasPrefix("+ ") { items.append(String(l.dropFirst(2))); i += 1 }
                else { break }
            }
            blocks.append(.bulletList(items: items))
            continue
        }

        // ── Ordered list ──────────────────────────────────────────
        if startsOrderedItem(line) {
            flushParagraph()
            var items: [String] = []
            while i < lines.count, startsOrderedItem(lines[i]) {
                items.append(orderedItemText(lines[i]))
                i += 1
            }
            blocks.append(.orderedList(items: items))
            continue
        }

        // ── Empty line ────────────────────────────────────────────
        if trimmed.isEmpty {
            flushParagraph()
            i += 1; continue
        }

        // ── Regular text ──────────────────────────────────────────
        paragraphLines.append(line)
        i += 1
    }

    flushParagraph()

    // Handle unclosed code block (streaming: closing ``` hasn't arrived yet)
    if inCodeBlock && !codeLines.isEmpty {
        blocks.append(.codeBlock(code: codeLines.joined(separator: "\n"), language: codeLang))
    }

    return blocks
}

private func startsOrderedItem(_ line: String) -> Bool {
    guard let first = line.first, first.isNumber else { return false }
    // Find where digits end
    let prefix = line.prefix(while: { $0.isNumber })
    let rest = line.dropFirst(prefix.count)
    return rest.hasPrefix(". ")
}

private func orderedItemText(_ line: String) -> String {
    if let range = line.range(of: ". ") {
        return String(line[range.upperBound...])
    }
    return line
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

// MARK: - TypingIndicator

private struct TypingIndicatorBubble: View {
    var body: some View {
        HStack {
            TypingIndicator()
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    MessageBubbleShape(isFromCurrentUser: false)
                        .fill(DarkFinanceColors.inputBackground)
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
                    .fill(DarkFinanceColors.secondaryText.opacity(0.7))
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
                    Button("Listo") { dismiss() }
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
