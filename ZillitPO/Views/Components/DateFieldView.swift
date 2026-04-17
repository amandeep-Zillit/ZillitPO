import SwiftUI

// ═══════════════════════════════════════════════════════════════════
// MARK: - DateFieldView (reusable)
//
// Behaviour the caller asked for (no compromises):
//   1. Tap empty field → iOS's native compact calendar floats below.
//      The outer `date` binding stays nil until the user actually
//      selects a date — the field does NOT pre-fill today on tap.
//   2. User picks a date → calendar closes automatically and the
//      field fills with the picked date.
//   3. Selected date renders in our custom `dd/MM/yyyy` format (not
//      the locale-default "17 Apr 2026" iOS would show).
//
// Implementation:
//   • The native compact DatePicker sits behind our visible text as a
//     hit-testable — but invisible — layer. Visibility is killed via
//     `.colorMultiply(.clear)`, which zeros the picker's RENDER output
//     without altering its view hierarchy, window anchor, or hit
//     testing. Previous versions used `.opacity(0.02)` / `.scaleEffect`
//     / `.id()` recreation — all of those crashed UIKit's targeted-
//     preview presenter ("view is in a window"). `colorMultiply` does
//     not, because it only modifies the composite colour output.
//   • Our visible overlay text (placeholder or formatted date) sits on
//     top with `allowsHitTesting(false)` so taps pass straight through
//     to the picker behind.
//   • When the user picks a date, iOS's setter fires on our binding
//     which commits to `date` AND bumps an internal `@State` so the
//     picker view is recreated on the next render — recreating the
//     picker is what dismisses its still-open popover (the only way
//     to programmatically close a compact DatePicker's calendar). The
//     recreation is deferred via `DispatchQueue.main.async` so UIKit
//     has finished its own selection-handling pass first.
// ═══════════════════════════════════════════════════════════════════

struct DateField: View {

    // MARK: - Bindings

    @Binding var date: Date?

    // MARK: - Customisation

    var placeholder: String = "Select a date"
    var formatHint: String = "dd/mm/yyyy"
    var displayFormat: String = "dd/MM/yyyy"
    var minDate: Date? = nil
    var maxDate: Date? = nil
    var navigationTitle: String = "Select Date"
    var horizontalPadding: CGFloat = 10
    /// Vertical padding — defaults to 4pt because the native compact
    /// DatePicker has an intrinsic height of ~32pt. Padding of 4pt on
    /// each side gives a total field height of ~40pt, matching the
    /// common `TextField` pattern `padding(10)` (20pt text + 20pt
    /// padding = 40pt). Callers whose neighbouring input uses
    /// different padding can override this.
    var verticalPadding: CGFloat = 4
    var cornerRadius: CGFloat = 6

    // MARK: - Local state

    /// Bumped after every successful pick to force the DatePicker view
    /// to recreate on the next render. Swapping the `.id` destroys the
    /// previous picker — which is what dismisses its popover. The bump
    /// happens on the next run-loop tick so it doesn't fight UIKit's
    /// ongoing selection handling.
    @State private var pickerKey: Int = 0

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = displayFormat
        f.locale = Locale(identifier: "en_GB")
        return f
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: date != nil ? "calendar" : "calendar.badge.plus")
                .font(.system(size: 14))
                .foregroundColor(date != nil ? .goldDark : .gray)

            pickerStack

            Spacer(minLength: 0)

            if date != nil {
                Button(action: { date = nil }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.gray.opacity(0.55))
                }.buttonStyle(BorderlessButtonStyle())
            }
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .background(date != nil ? Color.gold.opacity(0.06) : Color.bgSurface)
        .cornerRadius(cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(date != nil ? Color.gold.opacity(0.3) : Color.borderColor,
                        lineWidth: 1)
        )
    }

    // MARK: - Picker stack

    /// Invisible native compact picker behind our visible placeholder/
    /// date text. The picker receives the tap (native calendar floats
    /// below); the text shows our custom format.
    @ViewBuilder
    private var pickerStack: some View {
        if #available(iOS 14.0, *) {
            ZStack(alignment: .leading) {
                invisibleCompactPicker

                // Visible overlay.
                if let d = date {
                    Text(dateFormatter.string(from: d))
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .truncationMode(.tail)
                        .allowsHitTesting(false)
                } else {
                    HStack(spacing: 6) {
                        Text(placeholder)
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .truncationMode(.tail)
                            .layoutPriority(1)
                        Spacer(minLength: 4)
                        Text(formatHint)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(.gray.opacity(0.5))
                            .lineLimit(1)
                            .layoutPriority(-1)
                    }
                    .allowsHitTesting(false)
                }
            }
        } else {
            // iOS 13 — no compact style; fall back to a tap-to-reveal
            // wheel picker pattern. The empty-state tap seeds today so
            // the wheel has a value to render.
            if let d = date {
                DatePicker("", selection: Binding(
                    get: { d }, set: { date = $0 }
                ), displayedComponents: .date)
                .labelsHidden()
                .environment(\.locale, Locale(identifier: "en_GB"))
            } else {
                Button(action: { date = clampedToday() }) {
                    HStack(spacing: 6) {
                        Text(placeholder)
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Text(formatHint)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(.gray.opacity(0.5))
                            .lineLimit(1)
                    }
                }.buttonStyle(BorderlessButtonStyle())
            }
        }
    }

    /// The native compact DatePicker rendered invisibly via
    /// `.colorMultiply(.clear)`. It is the HIT-TESTABLE layer — a tap
    /// on the field area lands here and opens iOS's system calendar.
    /// When the user picks a date inside the calendar:
    ///   1. Setter writes the new value to the outer `date` binding.
    ///   2. `pickerKey` is bumped on the next run-loop tick via
    ///      `DispatchQueue.main.async`.
    ///   3. The `.id(pickerKey)` modifier sees the new key and SwiftUI
    ///      destroys + recreates the DatePicker — dismissing its still-
    ///      open popover. This is the only reliable way to get the
    ///      auto-close UX without tripping UIKit's internal presenter.
    @available(iOS 14.0, *)
    private var invisibleCompactPicker: some View {
        let binding = Binding<Date>(
            get: { date ?? clampedToday() },
            set: { newValue in
                date = newValue
                DispatchQueue.main.async { pickerKey &+= 1 }
            }
        )
        return rangedPicker(binding: binding)
            .datePickerStyle(CompactDatePickerStyle())
            .labelsHidden()
            .accentColor(.goldDark)
            .environment(\.locale, Locale(identifier: "en_GB"))
            // `.colorMultiply(.clear)` = all render output × 0 alpha.
            // Safe for UIKit's compact picker because it's a render
            // modifier, not a hierarchy / opacity / window change.
            .colorMultiply(.clear)
            // Stretch horizontally so the picker's hit area covers the
            // full field width, not just its natural pill. The compact
            // DatePicker respects `maxWidth: .infinity` in iOS 14+ and
            // expands its button/tap target across the whole cell —
            // so tapping ANYWHERE in the field opens the calendar.
            .frame(maxWidth: .infinity, alignment: .leading)
            .id(pickerKey)
    }

    @ViewBuilder
    private func rangedPicker(binding: Binding<Date>) -> some View {
        switch (minDate, maxDate) {
        case let (min?, max?):
            DatePicker("", selection: binding, in: min...max, displayedComponents: .date)
        case let (min?, nil):
            DatePicker("", selection: binding, in: min..., displayedComponents: .date)
        case let (nil, max?):
            DatePicker("", selection: binding, in: ...max, displayedComponents: .date)
        case (nil, nil):
            DatePicker("", selection: binding, displayedComponents: .date)
        }
    }

    private func clampedToday() -> Date {
        var d = Date()
        if let min = minDate, d < min { d = min }
        if let max = maxDate, d > max { d = max }
        return d
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Legacy wrapper — DateFieldView (hasDate + date)
// Adapts the old two-binding API onto the new `DateField(date:)`.
// ═══════════════════════════════════════════════════════════════════

struct DateFieldView: View {
    @Binding var hasDate: Bool
    @Binding var date: Date

    var placeholder: String = "Select a date"
    var displayFormat: String = "dd/MM/yyyy"

    var body: some View {
        DateField(
            date: Binding<Date?>(
                get: { hasDate ? date : nil },
                set: { newValue in
                    if let v = newValue {
                        date = v; hasDate = true
                    } else {
                        hasDate = false
                    }
                }
            ),
            placeholder: placeholder,
            displayFormat: displayFormat
        )
    }
}
