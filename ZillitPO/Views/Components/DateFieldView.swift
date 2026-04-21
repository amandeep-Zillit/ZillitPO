import SwiftUI

// ═══════════════════════════════════════════════════════════════════
// MARK: - DateFieldView (reusable)
//
// Behaviour (Apr 2026 redesign):
//   1. Visual: matches `InputField` siblings exactly — same font size
//      (13), padding (10h × 9v), corner radius (6), background
//      (`bgSurface`), and border (`borderColor`) regardless of whether
//      a date is set. Picked dates render bold; placeholder renders in
//      grey. A trailing `chevron.down` mirrors `PickerField`.
//   2. The whole field is tappable — a wrapping `Button` with
//      `PlainButtonStyle` covers the entire row, so taps on the icon,
//      label, or empty space all open the calendar.
//   3. Tap opens a BOTTOM SHEET with a graphical calendar. On iOS 16+
//      the sheet uses `.presentationDetents([.medium])` so it takes
//      roughly half the screen. Earlier iOS presents a full sheet.
//   4. The sheet has Cancel / Done nav buttons. "Done" commits the
//      date; "Cancel" leaves the outer binding untouched.
//   5. When a date is set, a small `xmark.circle.fill` appears to
//      clear it (same affordance as before).
// ═══════════════════════════════════════════════════════════════════

struct DateField: View {

    // MARK: - Bindings

    @Binding var date: Date?

    // MARK: - Customisation

    var placeholder: String = "Select a date"
    var displayFormat: String = "dd/MM/yyyy"
    var minDate: Date? = nil
    var maxDate: Date? = nil
    var navigationTitle: String = "Select Date"

    // MARK: - Local state

    @State private var showSheet = false
    /// Staging copy edited inside the sheet. Committed to `date` on Done.
    @State private var tempDate: Date = Date()

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = displayFormat
        f.locale = Locale(identifier: "en_GB")
        return f
    }

    var body: some View {
        Button(action: openSheet) {
            HStack(spacing: 6) {
                Image(systemName: date != nil ? "calendar" : "calendar.badge.plus")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .layoutPriority(-1)   // icon yields first if the row is tight

                if let d = date {
                    // The picked date gets the highest layout priority
                    // so on small screens (iPhone SE / landscape) the
                    // date wins the available width over the trailing
                    // clear button. `minimumScaleFactor` lets the text
                    // shrink to 75 % before SwiftUI would fall back to
                    // truncating — at that scale "21/04/2026" still
                    // fits in ≈ 66pt which clears the smallest cell.
                    Text(dateFormatter.string(from: d))
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .truncationMode(.tail)
                        .fixedSize(horizontal: false, vertical: true)
                        .layoutPriority(2)
                } else {
                    Text(placeholder)
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .truncationMode(.tail)
                        .layoutPriority(1)
                }

                Spacer(minLength: 4)

                if date != nil {
                    // Inner clear button — matches the old component's
                    // affordance. Buttons nested in SwiftUI Lists use
                    // BorderlessButtonStyle so they fire their own
                    // action instead of bubbling to the row button.
                    Button(action: { date = nil }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.gray.opacity(0.55))
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .layoutPriority(-1)
                } else {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.gray)
                        .layoutPriority(-1)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(Color.bgSurface)
            .cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
            .contentShape(Rectangle())   // full row hit-tests, not just the text
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showSheet) {
            pickerSheet
        }
    }

    private func openSheet() {
        tempDate = date ?? clampedToday()
        showSheet = true
    }

    // MARK: - Bottom sheet

    /// The calendar sheet content wrapped in `NavigationView` so it
    /// carries a title + Cancel/Done buttons. On iOS 16+ it uses a
    /// DYNAMIC height detent — sized from the currently-available
    /// detent space (`CalendarDetent.height(in:)`) so the calendar
    /// fits comfortably on every device from iPhone SE up to iPad:
    ///
    ///  • Screens < 700pt tall (SE, mini)   → ~78 % of available height
    ///  • 700–850pt (std iPhones)           → ~65 %
    ///  • ≥ 850pt (Pro Max, iPad)           → ~55 %
    ///
    /// A `.large` detent is always added so users who need the bigger
    /// calendar can drag up. A drag indicator is shown for both.
    /// Older iOS falls back to the default full-height sheet.
    @ViewBuilder
    private var pickerSheet: some View {
        if #available(iOS 16.0, *) {
            pickerSheetBody
                .presentationDetents([.custom(CalendarDetent.self), .large])
                .presentationDragIndicator(.visible)
        } else {
            pickerSheetBody
        }
    }

    private var pickerSheetBody: some View {
        NavigationView {
            VStack(spacing: 0) {
                pickerBody
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                Spacer(minLength: 0)
            }
            .background(Color.bgBase.edgesIgnoringSafeArea(.all))
            .navigationBarTitle(Text(navigationTitle), displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") { showSheet = false },
                trailing: Button(action: {
                    date = tempDate
                    showSheet = false
                }) {
                    Text("Done").fontWeight(.semibold)
                }
            )
        }
    }

    /// Renders a graphical calendar on iOS 14+ (matches the Close-PO
    /// sheet and other date fields in the app); wheel style on iOS 13
    /// where GraphicalDatePickerStyle isn't available.
    @ViewBuilder
    private var pickerBody: some View {
        if #available(iOS 14.0, *) {
            rangedPicker(binding: $tempDate)
                .datePickerStyle(GraphicalDatePickerStyle())
                .labelsHidden()
                .accentColor(.goldDark)
                .environment(\.locale, Locale(identifier: "en_GB"))
        } else {
            rangedPicker(binding: $tempDate)
                .datePickerStyle(WheelDatePickerStyle())
                .labelsHidden()
                .environment(\.locale, Locale(identifier: "en_GB"))
        }
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
// MARK: - Custom presentation detent (iOS 16+)
//
// Scales the calendar sheet height to the current device so the
// GraphicalDatePicker (which has ~420pt intrinsic content) is always
// fully visible without wasted vertical whitespace.
//
// `context.maxDetentValue` is the height SwiftUI is willing to allot
// a sheet on the current device (safe-area adjusted). We pick a
// fraction of that based on screen size class — smaller phones need a
// larger proportion so the calendar doesn't get clipped by the Done /
// Cancel bar, while bigger phones and iPads can afford a tighter fit.
// ═══════════════════════════════════════════════════════════════════

@available(iOS 16.0, *)
private struct CalendarDetent: CustomPresentationDetent {
    static func height(in context: Context) -> CGFloat? {
        let max = context.maxDetentValue
        // Guardrail: the calendar header + grid + nav bar won't render
        // properly under ~420pt; bump smaller screens up proportionally.
        let minimum: CGFloat = 420
        let fraction: CGFloat
        switch max {
        case ..<700:   fraction = 0.82   // iPhone SE / mini / landscape phones
        case ..<850:   fraction = 0.65   // Standard iPhones
        default:       fraction = 0.55   // Pro Max / iPad
        }
        return Swift.max(minimum, max * fraction)
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
