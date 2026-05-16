//
//  DMStepPrimitives.swift
//  ZillitPO
//
//  Shared form primitives used by every wizard step view —
//  `DMFieldGroup`, `DMTextField`, `DMPicker`, `DMToggleRow`,
//  `DMDateField`. Same visual language as the rest of the AccountHub
//  module (rounded inputs, gold accents, light-mode-first).
//

import SwiftUI

// MARK: - Field group (label + content)

struct DMFieldGroup<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content

    init(_ label: String, @ViewBuilder content: @escaping () -> Content) {
        self.label = label
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .tracking(0.4)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Text field

struct DMTextField: View {
    @Binding var text: String
    let placeholder: String
    var keyboard: UIKeyboardType = .default

    var body: some View {
        TextField(placeholder, text: $text)
            .keyboardType(keyboard)
            .font(.system(size: 14))
            .padding(.horizontal, 12).padding(.vertical, 12)
            .background(Color.bgSurface)
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
    }
}

// MARK: - Picker (inline Menu — iOS 15+)

struct DMPicker: View {
    @Binding var selection: String
    let options: [String]
    let placeholder: String

    var body: some View {
        Menu {
            ForEach(options, id: \.self) { opt in
                Button(action: { selection = opt }) {
                    Text(displayLabel(opt))
                    if opt == selection { Image(systemName: "checkmark") }
                }
            }
        } label: {
            HStack {
                Text(selection.isEmpty ? placeholder : displayLabel(selection))
                    .font(.system(size: 14))
                    .foregroundColor(selection.isEmpty ? .secondary : .primary)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12).padding(.vertical, 12)
            .background(Color.bgSurface)
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
        }
    }

    /// Show prettier labels for department/designation identifiers
    /// while keeping raw values for storage.
    private func displayLabel(_ raw: String) -> String {
        if raw.contains("_") { return FormatUtils.formatLabel(raw) }
        return raw
    }
}

// MARK: - Toggle row

struct DMToggleRow: View {
    let label: String
    let subtitle: String?
    @Binding var isOn: Bool

    init(_ label: String, subtitle: String? = nil, isOn: Binding<Bool>) {
        self.label = label
        self.subtitle = subtitle
        self._isOn = isOn
    }

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.system(size: 14, weight: .medium))
                if let s = subtitle {
                    Text(s).font(.system(size: 11)).foregroundColor(.secondary)
                }
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(.goldDark)
        }
        .padding(.horizontal, 12).padding(.vertical, 12)
        .background(Color.bgSurface)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
    }
}

// MARK: - Date field

struct DMDateField: View {
    @Binding var date: Date

    var body: some View {
        DatePicker("", selection: $date, displayedComponents: .date)
            .labelsHidden()
            .datePickerStyle(.compact)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Color.bgSurface)
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
    }
}

// MARK: - Currency / number field

struct DMAmountField: View {
    @Binding var amount: Double
    let currencySymbol: String

    @State private var text: String = ""

    var body: some View {
        HStack(spacing: 6) {
            Text(currencySymbol).foregroundColor(.secondary)
            TextField("0", text: $text)
                .keyboardType(.decimalPad)
                .font(.system(size: 14))
                .onChange(of: text) { newValue in
                    amount = Double(newValue) ?? 0
                }
        }
        .padding(.horizontal, 12).padding(.vertical, 12)
        .background(Color.bgSurface)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
        .onAppear {
            // Seed display string only on first appear so user edits
            // aren't trampled.
            if text.isEmpty && amount > 0 {
                text = amount.truncatingRemainder(dividingBy: 1) == 0
                    ? String(Int(amount))
                    : String(amount)
            }
        }
    }
}

// MARK: - Section heading

struct DMStepSection: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(.secondary)
            .tracking(0.8)
            .padding(.top, 6)
    }
}
