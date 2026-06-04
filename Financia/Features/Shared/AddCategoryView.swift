import SwiftUI

// MARK: - Add Category Form

struct AddCategoryView: View {
    @Environment(\.dismiss) private var dismiss
    var onSave: (TransactionCategory) -> Void

    @State private var name = ""
    @State private var initialSubcategoryName = ""
    @State private var icon = "tag.fill"
    @State private var color = Color.blue
    @State private var showingIconPicker = false

    var body: some View {
        Form {
            Section("Nombre") {
                TextField("Nombre de la Categoría", text: $name)
            }

            Section("Subcategoría inicial") {
                TextField("Nombre de la subcategoría", text: $initialSubcategoryName)
            }

            Section("Icono") {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(color.opacity(0.2))
                            .frame(width: 52, height: 52)
                        CategoryIconView(icon: icon, color: color, size: 24)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(icon)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        Button("Cambiar icono") { showingIconPicker = true }
                            .font(.system(size: 15))
                    }
                    Spacer()
                }
                .padding(.vertical, 4)
            }

            Section("Color") {
                ColorPicker("Elige un color", selection: $color)
            }
        }
        .navigationTitle("Nueva Categoría")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancelar") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Guardar") {
                    let newCategory = TransactionCategory(
                        name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                        subcategories: [Subcategory(name: initialSubcategoryName.trimmingCharacters(in: .whitespacesAndNewlines))],
                        icon: icon,
                        color: color
                    )
                    onSave(newCategory)
                    dismiss()
                }
                .disabled(
                    name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    initialSubcategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    icon.isEmpty
                )
            }
        }
        .sheet(isPresented: $showingIconPicker) {
            IconPickerSheet(selectedIcon: $icon, color: color)
        }
    }
}

// MARK: - Icon Picker Sheet

struct IconPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedIcon: String
    let color: Color

    enum IconMode: String, CaseIterable {
        case sfSymbol = "SF Símbolos"
        case emoji = "Emoji"
    }

    @State private var mode: IconMode = .sfSymbol
    @State private var searchText = ""
    @State private var customSymbolText = ""
    @State private var emojiInputText = ""

    private var isSFSymbolSelected: Bool { UIImage(systemName: selectedIcon) != nil }

    private var filteredSymbols: [String] {
        if searchText.isEmpty { return SFSymbolsLibrary.all }
        return SFSymbolsLibrary.all.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    private let gridColumns = [GridItem(.adaptive(minimum: 52), spacing: 10)]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Preview bar
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(color.opacity(0.2))
                            .frame(width: 44, height: 44)
                        CategoryIconView(icon: selectedIcon, color: color, size: 20)
                    }
                    Text(selectedIcon)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(Color(.systemGroupedBackground))

                Divider()

                Picker("Modo", selection: $mode) {
                    ForEach(IconMode.allCases, id: \.self) { Text($0.rawValue) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 10)

                if mode == .sfSymbol {
                    sfSymbolsContent
                } else {
                    emojiContent
                }
            }
            .navigationTitle("Elegir Icono")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            mode = isSFSymbolSelected ? .sfSymbol : .emoji
        }
    }

    // MARK: - SF Symbols Tab

    private var sfSymbolsContent: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                TextField("Buscar símbolo...", text: $searchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                    }
                }
            }
            .padding(10)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .padding(.horizontal)
            .padding(.bottom, 8)

            // Custom symbol name field
            HStack(spacing: 8) {
                Image(systemName: "pencil").foregroundColor(.secondary).font(.system(size: 13))
                TextField("Nombre exacto de símbolo (ej: star.fill)", text: $customSymbolText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(size: 14))
                    .onChange(of: customSymbolText) { _, newValue in
                        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty, UIImage(systemName: trimmed) != nil {
                            selectedIcon = trimmed
                        }
                    }
                if UIImage(systemName: customSymbolText.trimmingCharacters(in: .whitespacesAndNewlines)) != nil {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.green).font(.system(size: 14))
                }
            }
            .padding(8)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .padding(.horizontal)
            .padding(.bottom, 8)

            // Results count
            if !searchText.isEmpty {
                Text("\(filteredSymbols.count) resultado\(filteredSymbols.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.bottom, 4)
            }

            ScrollView {
                LazyVGrid(columns: gridColumns, spacing: 10) {
                    ForEach(filteredSymbols, id: \.self) { symbol in
                        Button {
                            selectedIcon = symbol
                            customSymbolText = symbol
                        } label: {
                            Image(systemName: symbol)
                                .font(.system(size: 20))
                                .frame(width: 48, height: 48)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(selectedIcon == symbol ? color.opacity(0.25) : Color(.systemGray6))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(selectedIcon == symbol ? color : Color.clear, lineWidth: 1.5)
                                        )
                                )
                                .foregroundColor(selectedIcon == symbol ? color : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
        }
    }

    // MARK: - Emoji Tab

    private var emojiContent: some View {
        VStack(spacing: 0) {
            // Manual emoji entry
            HStack(spacing: 12) {
                Text("Escribe o pega un emoji:")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)

                TextField("😀", text: $emojiInputText)
                    .font(.system(size: 26))
                    .frame(width: 52, height: 44)
                    .multilineTextAlignment(.center)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .onChange(of: emojiInputText) { _, newValue in
                        // Take the first grapheme cluster so multi-emoji pastes stay clean
                        if let first = newValue.first {
                            let cluster = String(first)
                            emojiInputText = cluster
                            if UIImage(systemName: cluster) == nil, !cluster.isEmpty {
                                selectedIcon = cluster
                            }
                        } else {
                            emojiInputText = ""
                        }
                    }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(Color(.systemGroupedBackground))

            Divider()

            Text("O elige uno de los más usados:")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 4)

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 48), spacing: 8)], spacing: 8) {
                    ForEach(EmojiLibrary.all, id: \.self) { emoji in
                        Button {
                            selectedIcon = emoji
                            emojiInputText = emoji
                        } label: {
                            Text(emoji)
                                .font(.system(size: 22))
                                .frame(width: 46, height: 46)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(selectedIcon == emoji ? color.opacity(0.25) : Color(.systemGray6))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(selectedIcon == emoji ? color : Color.clear, lineWidth: 1.5)
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
        }
        .onAppear {
            if !isSFSymbolSelected { emojiInputText = selectedIcon }
        }
    }
}

// MARK: - SF Symbols Library

struct SFSymbolsLibrary {
    static let all: [String] = [
        // Finance & Money
        "dollarsign", "dollarsign.circle", "dollarsign.circle.fill",
        "eurosign.circle", "eurosign.circle.fill",
        "sterlingsign.circle", "sterlingsign.circle.fill",
        "yensign.circle", "yensign.circle.fill",
        "creditcard", "creditcard.fill",
        "banknote", "banknote.fill",
        "wallet.pass", "wallet.pass.fill",
        "cart", "cart.fill",
        "bag", "bag.fill",
        "tag", "tag.fill",
        "percent", "function",
        "chart.bar", "chart.bar.fill",
        "chart.bar.xaxis", "chart.line.uptrend.xyaxis",
        "chart.pie", "chart.pie.fill",
        "arrow.up.right", "arrow.down.right",
        "arrow.up.circle", "arrow.down.circle",
        "plus.circle", "minus.circle",

        // Transport & Vehicles
        "car", "car.fill",
        "car.2", "car.2.fill",
        "bus", "bus.fill",
        "tram.fill", "trolleybus",
        "airplane", "airplane.circle",
        "bicycle", "scooter",
        "ferry", "ferry.fill",
        "fuelpump", "fuelpump.fill",
        "road.lanes", "car.rear",

        // Home & Living
        "house", "house.fill",
        "building.2", "building.2.fill",
        "building.columns", "building.columns.fill",
        "bed.double", "bed.double.fill",
        "sofa", "sofa.fill",
        "tv", "tv.fill",
        "display", "desktopcomputer",
        "lightbulb", "lightbulb.fill",
        "bolt", "bolt.fill",
        "drop", "drop.fill",
        "flame", "flame.fill",
        "snowflake",
        "washer", "washer.fill",
        "refrigerator", "oven",
        "lamp.desk", "lamp.desk.fill",
        "shower", "bathtub",

        // Food & Drink
        "fork.knife",
        "fork.knife.circle", "fork.knife.circle.fill",
        "cup.and.saucer", "cup.and.saucer.fill",
        "mug", "mug.fill",
        "wineglass", "wineglass.fill",
        "birthday.cake", "birthday.cake.fill",
        "takeoutbag.and.cup.and.straw",
        "carrot", "carrot.fill",

        // Health & Fitness
        "heart", "heart.fill",
        "cross", "cross.fill",
        "cross.circle", "cross.circle.fill",
        "pill", "pill.fill",
        "stethoscope",
        "syringe", "syringe.fill",
        "bandage", "bandage.fill",
        "figure.walk",
        "figure.run",
        "figure.gymnastics",
        "dumbbell", "dumbbell.fill",
        "sportscourt", "sportscourt.fill",
        "brain", "brain.fill",
        "lungs", "lungs.fill",
        "eye", "eye.fill",
        "ear", "ear.fill",

        // Entertainment & Leisure
        "gamecontroller", "gamecontroller.fill",
        "film", "film.fill",
        "music.note",
        "music.note.list",
        "headphones",
        "speaker.wave.2", "speaker.wave.2.fill",
        "music.mic",
        "guitars", "guitars.fill",
        "pianokeys",
        "book", "book.fill",
        "books.vertical", "books.vertical.fill",
        "newspaper", "newspaper.fill",
        "theatermasks", "theatermasks.fill",
        "popcorn", "popcorn.fill",
        "paintbrush", "paintbrush.fill",
        "paintpalette", "paintpalette.fill",
        "camera", "camera.fill",
        "photo", "photo.fill",
        "tv.and.hifispeaker.fill",

        // Technology & Devices
        "iphone",
        "ipad",
        "laptopcomputer",
        "keyboard",
        "printer", "printer.fill",
        "scanner", "scanner.fill",
        "phone", "phone.fill",
        "wifi",
        "network",
        "antenna.radiowaves.left.and.right",
        "cpu", "memorychip",
        "externaldrive", "internaldrive",

        // Education & Work
        "graduationcap", "graduationcap.fill",
        "pencil", "pencil.circle", "pencil.circle.fill",
        "doc", "doc.fill",
        "doc.text", "doc.text.fill",
        "folder", "folder.fill",
        "tray", "tray.fill",
        "briefcase", "briefcase.fill",
        "newspaper.circle", "newspaper.circle.fill",
        "paperclip", "link",
        "square.and.pencil",
        "chart.xyaxis.line",

        // People & Social
        "person", "person.fill",
        "person.2", "person.2.fill",
        "person.3", "person.3.fill",
        "person.circle", "person.circle.fill",
        "figure.stand",
        "hand.raised", "hand.raised.fill",
        "hands.clap", "hands.clap.fill",
        "bubble.left", "bubble.left.fill",
        "message", "message.fill",

        // Travel & Places
        "map", "map.fill",
        "location", "location.fill",
        "globe", "globe.americas", "globe.europe.africa",
        "suitcase", "suitcase.fill",
        "backpack", "backpack.fill",
        "tent", "tent.fill",
        "beach.umbrella", "beach.umbrella.fill",
        "mountain.2", "mountain.2.fill",

        // Nature & Environment
        "leaf", "leaf.fill",
        "tree", "tree.fill",
        "sun.max", "sun.max.fill",
        "moon", "moon.fill",
        "cloud", "cloud.fill",
        "cloud.sun", "cloud.rain",
        "wind", "tornado",
        "pawprint", "pawprint.fill",
        "hare", "hare.fill",
        "tortoise", "tortoise.fill",
        "fish", "fish.fill",
        "bird", "bird.fill",
        "ladybug", "ladybug.fill",

        // Gifts & Events
        "gift", "gift.fill",
        "party.popper", "party.popper.fill",
        "balloon", "balloon.fill",
        "balloon.2", "balloon.2.fill",
        "rosette",
        "medal", "medal.fill",
        "trophy", "trophy.fill",
        "star", "star.fill",
        "star.circle", "star.circle.fill",

        // Security & Settings
        "lock", "lock.fill",
        "lock.open", "lock.open.fill",
        "key", "key.fill",
        "shield", "shield.fill",
        "gear", "gearshape", "gearshape.fill",
        "gearshape.2", "gearshape.2.fill",
        "wrench.and.screwdriver", "wrench.and.screwdriver.fill",
        "hammer", "hammer.fill",
        "crown", "crown.fill",

        // Arrows & Shapes
        "arrow.left.arrow.right",
        "arrow.up.arrow.down",
        "arrow.triangle.2.circlepath",
        "checkmark.circle", "checkmark.circle.fill",
        "exclamationmark.circle", "exclamationmark.circle.fill",
        "questionmark.circle", "questionmark.circle.fill",
        "xmark.circle", "xmark.circle.fill",
        "sparkles", "sparkle",
        "wand.and.stars",
        "wand.and.rays",
        "rays",

        // Household & Utility
        "scissors", "scissors.circle",
        "cart.badge.plus", "bag.badge.plus",
        "hanger",
        "tshirt", "tshirt.fill",
        "comb", "comb.fill",
        "eyeglasses",
        "watch.analog",
        "clock", "clock.fill",
        "alarm", "alarm.fill",
        "calendar", "calendar.badge.plus",
    ]
}

// MARK: - Emoji Library

struct EmojiLibrary {
    static let all: [String] = [
        // Finance & Money
        "💰", "💵", "💴", "💶", "💷", "💳", "🏦", "📊", "📈", "📉",
        "🤑", "💸", "🏧", "💹", "🪙", "💎",

        // Food & Drink
        "🍕", "🍔", "🍟", "🌮", "🌯", "🍱", "🥗", "🍜", "🍣", "🍛",
        "🥩", "🍗", "🥚", "🧀", "🥦", "🥕", "🍎", "🍌", "🍓", "🍇",
        "☕", "🍺", "🍷", "🥂", "🧃", "🥤", "🍰", "🎂", "🍩", "🍪",
        "🛒", "🛍️",

        // Transport
        "🚗", "🚕", "🚙", "🚌", "🚎", "✈️", "🚂", "🚁", "⛴️", "🛵",
        "🚲", "🛺", "⛽", "🅿️", "🚀", "🛸",

        // Home & Living
        "🏠", "🏡", "🏢", "🏗️", "🛋️", "🛏️", "🔧", "🔨", "💡", "🔑",
        "🪑", "🛁", "🚿", "🪟", "🚪", "🧹", "🧺", "🪴", "🖼️",

        // Health & Fitness
        "❤️", "💊", "🩺", "🏥", "🩸", "🩹", "🏋️", "⚽", "🏀", "🎾",
        "🏊", "🧘", "🚴", "🥊", "🏅", "🥗",

        // Entertainment & Leisure
        "🎮", "🎬", "🎵", "🎸", "🎭", "📚", "📖", "🎲", "🎪", "🎡",
        "🎢", "🎠", "🎟️", "🎰", "🃏", "🎯",

        // Technology
        "📱", "💻", "🖥️", "⌨️", "🖨️", "📷", "🎥", "📡", "🔋", "🖱️",
        "💾", "📀", "🔌",

        // Shopping & Fashion
        "👗", "👠", "👒", "🕶️", "💄", "💍", "👜", "👝", "🧴", "💅",
        "🧣", "🧤", "👟",

        // Education & Work
        "🎓", "📝", "✏️", "📐", "🔬", "🔭", "📚", "💼", "🏛️", "📋",
        "📌", "📎", "✂️", "🗂️",

        // Nature & Animals
        "🌿", "🌱", "🌲", "🌸", "🌻", "☀️", "🌙", "❄️", "🌧️", "⛈️",
        "🐶", "🐱", "🐟", "🐦", "🦋", "🌈", "🍀", "🌺", "🌴",

        // Travel & Places
        "🗺️", "📍", "✈️", "🏖️", "🏔️", "🗼", "🗽", "🏰", "🏯", "⛩️",

        // Events & Misc
        "🎁", "🎉", "🎊", "🏆", "⭐", "💫", "🔥", "💥", "🎯", "🚩",
        "📣", "🔔", "🎶", "✨", "🌟", "💪", "👏", "🤝", "🙏", "❤️‍🔥",
    ]
}
