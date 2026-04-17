//
//  CompatActionSheet.swift
//  ZillitPO
//
//  Reusable wrappers around SwiftUI's native `actionSheet` modifier.
//  Cuts the per-call-site boilerplate of building `ActionSheet.Button`
//  arrays, appending `.cancel()`, and rendering selection checkmarks.
//
//  Two equivalent entry points:
//
//   • `.appActionSheet(title:isPresented:items:)`
//        — generic version: pass an array of `AppActionSheetItem`s
//          (selectable / action / destructive). Cancel is appended
//          automatically.
//
//   • `.selectionActionSheet(title:isPresented:options:isSelected:label:onSelect:)`
//        — filter/picker convenience: pass any Hashable list, a
//          label closure, and an `onSelect` callback. Adds a "✓"
//          to the currently-selected option's label.
//
//  Note on file name: this file is named `CompatActionSheet.swift` for
//  historical reasons (Xcode project reference). The current contents
//  are the new `AppActionSheet*` types.
//

import SwiftUI

// MARK: - Item type used by .appActionSheet(...)

struct AppActionSheetItem {
    enum Role { case `default`, destructive }
    let label: String
    let isSelected: Bool
    let role: Role
    /// Optional SF Symbol name shown on the leading edge — used by the
    /// dropdown menu variant. The action sheet variant ignores it.
    let systemImage: String?
    let action: () -> Void

    /// Selectable row — adds a "✓" to the label when `isSelected` is true.
    static func selectable(_ label: String,
                           isSelected: Bool,
                           systemImage: String? = nil,
                           action: @escaping () -> Void) -> AppActionSheetItem {
        AppActionSheetItem(label: label, isSelected: isSelected, role: .default,
                           systemImage: systemImage, action: action)
    }

    /// Plain action row — no checkmark.
    static func action(_ label: String,
                       systemImage: String? = nil,
                       action: @escaping () -> Void) -> AppActionSheetItem {
        AppActionSheetItem(label: label, isSelected: false, role: .default,
                           systemImage: systemImage, action: action)
    }

    /// Destructive (red) row.
    static func destructive(_ label: String,
                            systemImage: String? = nil,
                            action: @escaping () -> Void) -> AppActionSheetItem {
        AppActionSheetItem(label: label, isSelected: false, role: .destructive,
                           systemImage: systemImage, action: action)
    }
}

extension View {
    /// Generic reusable action sheet. Cancel button is appended.
    ///
    /// Uses Apple-native presentation that always slides up from the
    /// bottom:
    ///   • iOS 15+ → `.confirmationDialog` (bottom-anchored on iPhone AND
    ///     iPad; replaces the iOS-16-deprecated `.actionSheet`).
    ///   • iOS 13/14 → `.actionSheet` (bottom-anchored on iPhone, which
    ///     is the app's only deployment form factor at those versions).
    @ViewBuilder
    func appActionSheet(title: String,
                        isPresented: Binding<Bool>,
                        items: [AppActionSheetItem]) -> some View {
        if #available(iOS 15.0, *) {
            self.confirmationDialog(title, isPresented: isPresented, titleVisibility: .visible) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    let label = item.isSelected ? "\(item.label) ✓" : item.label
                    switch item.role {
                    case .default:
                        Button(label) { item.action() }
                    case .destructive:
                        Button(label, role: .destructive) { item.action() }
                    }
                }
                Button("Cancel", role: .cancel) { }
            }
        } else {
            self.actionSheet(isPresented: isPresented) {
                ActionSheet(
                    title: Text(title),
                    buttons: items.map { item -> ActionSheet.Button in
                        let txt = item.isSelected ? Text("\(item.label) ✓") : Text(item.label)
                        switch item.role {
                        case .default:     return .default(txt, action: item.action)
                        case .destructive: return .destructive(txt, action: item.action)
                        }
                    } + [.cancel()]
                )
            }
        }
    }

    /// Filter/picker convenience — auto-builds a selectable item list
    /// from any Hashable collection. Cancel button is appended.
    func selectionActionSheet<T: Hashable>(title: String,
                                            isPresented: Binding<Bool>,
                                            options: [T],
                                            isSelected: (T) -> Bool,
                                            label: (T) -> String,
                                            onSelect: @escaping (T) -> Void) -> some View {
        let items = options.map { opt in
            AppActionSheetItem.selectable(label(opt), isSelected: isSelected(opt)) {
                onSelect(opt)
            }
        }
        return appActionSheet(title: title, isPresented: isPresented, items: items)
    }

    /// Dropdown popup menu using the same `AppActionSheetItem` model.
    /// Renders a small card overlaid on the trailing edge of the view
    /// (typically used on a page that has an ellipsis nav-bar trigger).
    /// Tapping outside the card or on an item dismisses it.
    ///
    /// Usage:
    /// ```
    /// .appDropdownMenu(isPresented: $showMenu, items: [
    ///     .action("Query",   systemImage: "text.bubble") { … },
    ///     .action("History", systemImage: "clock.arrow.circlepath") { … }
    /// ])
    /// ```
    func appDropdownMenu(isPresented: Binding<Bool>,
                         width: CGFloat = 180,
                         items: [AppActionSheetItem]) -> some View {
        ZStack(alignment: .topTrailing) {
            self
            if isPresented.wrappedValue {
                // Full-screen tap catcher dismisses on outside taps.
                Color.black.opacity(0.001)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture { isPresented.wrappedValue = false }

                AppDropdownMenuCard(width: width, items: items) {
                    isPresented.wrappedValue = false
                }
                .padding(.trailing, 12)
                .padding(.top, 4)
                .transition(.opacity)
            }
        }
    }
}

// MARK: - Dropdown card view (private to this file)

private struct AppDropdownMenuCard: View {
    let width: CGFloat
    let items: [AppActionSheetItem]
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                Button(action: {
                    onDismiss()
                    item.action()
                }) {
                    HStack(spacing: 10) {
                        if let sym = item.systemImage {
                            Image(systemName: sym)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(item.role == .destructive ? .red : .goldDark)
                                .frame(width: 18, alignment: .center)
                        }
                        Text(item.label)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(item.role == .destructive ? .red : .primary)
                        Spacer()
                        if item.isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.goldDark)
                        }
                    }
                    .padding(.horizontal, 12).padding(.vertical, 10)
                    .contentShape(Rectangle())
                }.buttonStyle(PlainButtonStyle())

                if idx < items.count - 1 {
                    Divider().padding(.leading, item.systemImage != nil ? 34 : 12)
                }
            }
        }
        .frame(width: width)
        .background(Color.bgSurface)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
    }
}
