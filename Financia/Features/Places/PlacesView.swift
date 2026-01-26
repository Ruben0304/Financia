import SwiftUI

struct PlacesView: View {
    @EnvironmentObject private var lugarManager: LugarManager
    @State private var editingLugar: Lugar?
    @State private var isAdding: Bool = false

    var body: some View {
        List {
            ForEach(lugarManager.lugares) { lugar in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(lugar.nombre)
                            .font(.headline)
                        Spacer()
                        if let count = lugar.visualKeywords?.count, count > 0 {
                            Text("\(count) palabras")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    if let keywords = lugar.visualKeywords, !keywords.isEmpty {
                        LazyVGrid(columns: keywordColumns, alignment: .leading, spacing: 6) {
                            ForEach(keywords, id: \.self) { keyword in
                                Text(keyword)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color(.systemGray6), in: Capsule())
                            }
                        }
                    }
                }
                .padding(.vertical, 6)
                .contentShape(Rectangle())
                .onTapGesture {
                    editingLugar = lugar
                }
            }
            .onDelete { indices in
                indices.map { lugarManager.lugares[$0] }.forEach { lugar in
                    lugarManager.deleteLugar(lugar)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Lugares")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    isAdding = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .refreshable {
            lugarManager.loadLugares()
        }
        .sheet(item: $editingLugar) { lugar in
            PlaceEditorView(
                title: "Editar lugar",
                initialLugar: lugar
            ) { updated in
                lugarManager.updateLugar(updated)
            }
        }
        .sheet(isPresented: $isAdding) {
            PlaceEditorView(
                title: "Nuevo lugar",
                initialLugar: nil
            ) { newLugar in
                lugarManager.addLugar(newLugar)
            }
        }
    }

    private var keywordColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 120), spacing: 6)]
    }
}

private struct PlaceEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let initialLugar: Lugar?
    let onSave: (Lugar) -> Void

    @State private var name: String = ""
    @State private var keywords: [String] = []
    @State private var newKeyword: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Nombre") {
                    TextField("Nombre del lugar", text: $name)
                }

                Section("Palabras clave") {
                    if !keywords.isEmpty {
                        LazyVGrid(columns: keywordColumns, alignment: .leading, spacing: 8) {
                            ForEach(keywords, id: \.self) { keyword in
                                HStack(spacing: 6) {
                                    Text(keyword)
                                        .font(.caption)
                                    Button(role: .destructive) {
                                        keywords.removeAll { $0 == keyword }
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color(.systemGray6), in: Capsule())
                            }
                        }
                    }

                    HStack {
                        TextField("Agregar palabra clave", text: $newKeyword)
                        Button("Añadir") {
                            let trimmed = newKeyword.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmed.isEmpty else { return }
                            if !keywords.contains(trimmed) {
                                keywords.append(trimmed)
                            }
                            newKeyword = ""
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .keyboardDoneToolbar()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        let lugar = Lugar(
                            id: initialLugar?.id ?? UUID(),
                            nombre: trimmed,
                            visualKeywords: keywords,
                            backendId: initialLugar?.backendId
                        )
                        onSave(lugar)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                name = initialLugar?.nombre ?? ""
                keywords = initialLugar?.visualKeywords ?? []
            }
        }
    }

    private var keywordColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 120), spacing: 8)]
    }
}
