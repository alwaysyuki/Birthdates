//
//  CategoryEditorSheet.swift
//  birthdates
//
//  Created for native macOS offline-first birthday management.
//

import SwiftUI
import SwiftData

/// Modal sheet for creating and modifying friend categories with color palettes,
/// symbol selection, and live previews.
struct CategoryEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let categoryToEdit: Category?
    var onSaveSuccess: ((Category) -> Void)? = nil

    @State private var name: String = ""
    @State private var selectedColorHex: String = "#0A84FF"
    @State private var selectedIconName: String = "folder"
    @State private var errorMessage: String? = nil

    private let colorPresets: [String] = [
        "#0A84FF", // Blue
        "#AF52DE", // Purple
        "#FF2D55", // Pink
        "#FF3B30", // Red
        "#FF9500", // Orange
        "#FFCC00", // Yellow
        "#34C759", // Green
        "#00C7BE", // Teal
        "#5856D6", // Indigo
        "#8E8E93"  // Gray
    ]

    private let iconPresets: [String] = [
        "folder",
        "person.2.fill",
        "heart.fill",
        "star.fill",
        "briefcase.fill",
        "house.fill",
        "gift.fill",
        "graduationcap.fill",
        "gamecontroller.fill",
        "airplane",
        "figure.walk",
        "sparkles",
        "cup.and.saucer.fill",
        "music.note",
        "sun.max.fill",
        "building.2.fill"
    ]

    private var isEditing: Bool {
        categoryToEdit != nil
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack {
                Text(isEditing ? "Edit Category" : "New Category")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, AppTheme.Spacing.large)
            .padding(.vertical, AppTheme.Spacing.medium)
            .background(.regularMaterial)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                    if let errorMessage {
                        HStack(spacing: AppTheme.Spacing.xSmall) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                        .padding(AppTheme.Spacing.small)
                        .background(Color.red.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small, style: .continuous))
                    }

                    // Live Preview Card
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xSmall) {
                        Text("PREVIEW")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)

                        HStack(spacing: AppTheme.Spacing.medium) {
                            CategoryChip(
                                title: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Category Name" : name.trimmingCharacters(in: .whitespacesAndNewlines),
                                color: Color(hex: selectedColorHex) ?? .accentColor,
                                iconName: selectedIconName,
                                isSelected: true
                            )

                            CategoryChip(
                                title: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Category Name" : name.trimmingCharacters(in: .whitespacesAndNewlines),
                                color: Color(hex: selectedColorHex) ?? .accentColor,
                                iconName: selectedIconName,
                                isSelected: false
                            )
                        }
                        .padding(AppTheme.Spacing.medium)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppTheme.Colors.secondaryFill)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium, style: .continuous))
                    }

                    // Name Input
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xxSmall) {
                        Text("Name")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        TextField("e.g. Family, Close Friends, Work", text: $name)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Color Palette
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xSmall) {
                        Text("Color")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        HStack(spacing: 10) {
                            ForEach(colorPresets, id: \.self) { hex in
                                let isSelected = selectedColorHex.caseInsensitiveCompare(hex) == .orderedSame
                                let color = Color(hex: hex) ?? .blue

                                Button {
                                    selectedColorHex = hex
                                } label: {
                                    ZStack {
                                        Circle()
                                            .fill(color)
                                            .frame(width: 26, height: 26)

                                        if isSelected {
                                            Circle()
                                                .strokeBorder(Color.white, lineWidth: 2.5)
                                                .frame(width: 24, height: 24)

                                            Circle()
                                                .strokeBorder(color, lineWidth: 1.5)
                                                .frame(width: 30, height: 30)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                                .help(hex)
                            }
                        }
                    }

                    // Icon Palette
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xSmall) {
                        Text("Icon")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(minimum: 36), spacing: 8), count: 8),
                            spacing: 8
                        ) {
                            ForEach(iconPresets, id: \.self) { icon in
                                let isSelected = selectedIconName == icon
                                let accent = Color(hex: selectedColorHex) ?? .accentColor

                                Button {
                                    selectedIconName = icon
                                } label: {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .fill(isSelected ? accent.opacity(0.2) : AppTheme.Colors.secondaryFill)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                                    .stroke(isSelected ? accent : Color.clear, lineWidth: 1.5)
                                            )
                                            .frame(height: 36)

                                        Image(systemName: icon)
                                            .font(.system(size: 15))
                                            .foregroundStyle(isSelected ? accent : .primary)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(AppTheme.Spacing.large)
            }

            Divider()

            // Footer / Action Bar
            HStack {
                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button(isEditing ? "Save Changes" : "Create Category") {
                    saveCategory()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
            .padding(.horizontal, AppTheme.Spacing.large)
            .padding(.vertical, AppTheme.Spacing.medium)
            .background(.regularMaterial)
        }
        .frame(width: 440, height: 500)
        .onAppear {
            if let categoryToEdit {
                name = categoryToEdit.name
                selectedColorHex = categoryToEdit.colorHex
                selectedIconName = categoryToEdit.iconName
            }
        }
    }

    private func saveCategory() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        do {
            if let existing = categoryToEdit {
                existing.name = trimmed
                existing.colorHex = selectedColorHex
                existing.iconName = selectedIconName
                try CategoryRepository.shared.updateCategory(existing, in: modelContext)
                onSaveSuccess?(existing)
            } else {
                let created = try CategoryRepository.shared.createCategory(
                    name: trimmed,
                    iconName: selectedIconName,
                    colorHex: selectedColorHex,
                    sortOrder: 0,
                    in: modelContext
                )
                onSaveSuccess?(created)
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    CategoryEditorSheet(categoryToEdit: nil)
        .modelContainer(SampleData.createSampleContainer())
}
