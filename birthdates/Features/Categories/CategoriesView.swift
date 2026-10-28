//
//  CategoriesView.swift
//  birthdates
//
//  Created for native macOS offline-first birthday management.
//

import SwiftUI
import SwiftData

/// Categories and grouping view for organizing friends with liquid-glass cards,
/// cluster avatars, category creation/editing, and responsive layouts.
struct CategoriesView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @Query private var friends: [Friend]

    @State private var isShowingAddCategorySheet: Bool = false
    @State private var categoryToEdit: Category? = nil
    @State private var categoryToDelete: Category? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                // Header
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xxSmall) {
                        Text("Friend Categories")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.primary)

                        Text("Group your friends by relationships, circles, and reminder priorities.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        isShowingAddCategorySheet = true
                    } label: {
                        Label("Add Category", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .help("Create a new category")
                }

                if categories.isEmpty {
                    GlassCard {
                        EmptyStateView(
                            iconName: "folder.badge.plus",
                            title: "No Categories",
                            message: "Create categories to group your friends and family members.",
                            actionTitle: "Add Category",
                            actionIcon: "plus",
                            action: {
                                isShowingAddCategorySheet = true
                            }
                        )
                    }
                } else {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 260, maximum: 380), spacing: AppTheme.Spacing.medium)],
                        spacing: AppTheme.Spacing.medium
                    ) {
                        ForEach(categories) { category in
                            categoryCard(for: category)
                        }
                    }
                }
            }
            .padding(AppTheme.Spacing.large)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Categories")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isShowingAddCategorySheet = true
                } label: {
                    Label("Add Category", systemImage: "plus")
                }
                .help("Add Category")
            }
        }
        .sheet(isPresented: $isShowingAddCategorySheet) {
            CategoryEditorSheet(categoryToEdit: nil)
        }
        .sheet(item: $categoryToEdit) { category in
            CategoryEditorSheet(categoryToEdit: category)
        }
        .confirmationDialog(
            "Delete Category?",
            isPresented: Binding(
                get: { categoryToDelete != nil },
                set: { if !$0 { categoryToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let cat = categoryToDelete {
                    try? CategoryRepository.shared.deleteCategory(cat, in: modelContext)
                    categoryToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) {
                categoryToDelete = nil
            }
        } message: {
            Text("Are you sure you want to delete this category? Associated friends will not be deleted.")
        }
    }

    // MARK: - Subviews
    private func categoryCard(for category: Category) -> some View {
        let categoryColor = Color(hex: category.colorHex) ?? .accentColor
        let associatedFriends = friends.filter { !$0.isArchived && $0.categories.contains(where: { $0.id == category.id }) }

        return GlassCard(
            isInteractive: true,
            tintColor: categoryColor
        ) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                HStack(spacing: AppTheme.Spacing.small) {
                    ZStack {
                        Circle()
                            .fill(categoryColor.opacity(0.15))
                            .frame(width: 36, height: 36)

                        Image(systemName: category.iconName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(categoryColor)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(category.name)
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Text("\(associatedFriends.count) \(associatedFriends.count == 1 ? "friend" : "friends")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Menu {
                        Button {
                            categoryToEdit = category
                        } label: {
                            Label("Edit Category", systemImage: "pencil")
                        }

                        Divider()

                        Button(role: .destructive) {
                            categoryToDelete = category
                        } label: {
                            Label("Delete Category", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .frame(width: 20, height: 20)
                }

                Divider()

                HStack {
                    if associatedFriends.isEmpty {
                        Text("No friends assigned")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .padding(.vertical, AppTheme.Spacing.xxSmall)
                    } else {
                        HStack(spacing: -6) {
                            ForEach(associatedFriends.prefix(5)) { friend in
                                FriendAvatar(
                                    initials: friend.initials,
                                    colorHex: friend.avatarColorHex,
                                    size: 28,
                                    name: friend.fullName
                                )
                                .overlay(Circle().stroke(AppTheme.Colors.controlBackground, lineWidth: 1.5))
                            }

                            if associatedFriends.count > 5 {
                                Text("+\(associatedFriends.count - 5)")
                                    .font(.caption2.bold())
                                    .padding(.leading, 12)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, AppTheme.Spacing.xxSmall)
                    }

                    Spacer()

                    Button("Edit") {
                        categoryToEdit = category
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .contextMenu {
            Button {
                categoryToEdit = category
            } label: {
                Label("Edit Category", systemImage: "pencil")
            }

            Divider()

            Button(role: .destructive) {
                categoryToDelete = category
            } label: {
                Label("Delete Category", systemImage: "trash")
            }
        }
    }
}

#Preview {
    CategoriesView()
        .modelContainer(SampleData.createSampleContainer())
}
