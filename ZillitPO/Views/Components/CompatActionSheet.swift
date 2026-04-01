//
//  CompatActionSheet.swift
//  ZillitPO
//
//  ActionSheet replacement that works on iOS 13–26
//

import SwiftUI

struct CompatActionSheetButton {
    let title: String
    let role: CompatButtonRole
    let action: () -> Void

    enum CompatButtonRole { case `default`, cancel, destructive }

    static func `default`(_ title: String, action: @escaping () -> Void) -> CompatActionSheetButton {
        CompatActionSheetButton(title: title, role: .default, action: action)
    }
    static func cancel() -> CompatActionSheetButton {
        CompatActionSheetButton(title: "Cancel", role: .cancel, action: {})
    }
    static func destructive(_ title: String, action: @escaping () -> Void) -> CompatActionSheetButton {
        CompatActionSheetButton(title: title, role: .destructive, action: action)
    }
}

// MARK: - Custom bottom sheet view (works reliably on all iOS versions)

struct CompatActionSheetContent: View {
    let title: String
    let buttons: [CompatActionSheetButton]
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.gray.opacity(0.4))
                .frame(width: 40, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 14)

            // Title
            if !title.isEmpty {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                    .padding(.bottom, 12)
            }

            // Buttons
            VStack(spacing: 0) {
                ForEach(buttons.indices, id: \.self) { i in
                    let btn = buttons[i]
                    if btn.role != .cancel {
                        if i > 0 && buttons[i - 1].role != .cancel {
                            Divider()
                        }
                        Button(action: {
                            isPresented = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { btn.action() }
                        }) {
                            Text(btn.title)
                                .font(.system(size: 17))
                                .foregroundColor(btn.role == .destructive ? .red : .primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    }
                }
            }
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(12)
            .padding(.horizontal, 16)

            // Cancel button
            Button(action: { isPresented = false }) {
                Text("Cancel")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())
            }
            .buttonStyle(BorderlessButtonStyle())
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(12)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        .background(Color(UIColor.systemGroupedBackground))
    }
}

// MARK: - View Modifier

struct CompatActionSheet: ViewModifier {
    let title: String
    @Binding var isPresented: Bool
    let buttons: [CompatActionSheetButton]

    func body(content: Content) -> some View {
        content.sheet(isPresented: $isPresented) {
            if #available(iOS 16.4, *) {
                CompatActionSheetContent(title: title, buttons: buttons, isPresented: $isPresented)
                    .presentationDetents([.height(CGFloat(actionButtons.count * 50 + 140))])
                    .presentationDragIndicator(.hidden)
            } else {
                CompatActionSheetContent(title: title, buttons: buttons, isPresented: $isPresented)
            }
        }
    }

    private var actionButtons: [CompatActionSheetButton] {
        buttons.filter { $0.role != .cancel }
    }
}

extension View {
    func compatActionSheet(title: String, isPresented: Binding<Bool>, buttons: [CompatActionSheetButton]) -> some View {
        modifier(CompatActionSheet(title: title, isPresented: isPresented, buttons: buttons))
    }
}
