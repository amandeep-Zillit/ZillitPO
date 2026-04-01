import Foundation

struct FormatUtils {
    private static let upper: Set<String> = ["sfx","vfx","epk","dit","covid","hod","pa"]
    private static let special: [String: String] = ["1st":"1st","2nd":"2nd","3rd":"3rd"]

    static func formatLabel(_ label: String?) -> String {
        guard let label = label, !label.isEmpty else { return "" }
        var cleaned = label.replacingOccurrences(of: "_label", with: "")
        for p in ["department_", "designation_"] {
            if cleaned.hasPrefix(p) { cleaned = String(cleaned.dropFirst(p.count)) }
        }
        return cleaned.split(separator: "_").map { w in
            let s = String(w)
            if let sp = special[s] { return sp }
            if upper.contains(s) { return s.uppercased() }
            return s.prefix(1).uppercased() + s.dropFirst()
        }.joined(separator: " ")
    }

    static func formatGBP(_ amount: Double) -> String {
        formatCurrency(amount, code: "GBP")
    }

    static func formatCurrency(_ amount: Double, code: String) -> String {
        let f = NumberFormatter(); f.numberStyle = .currency; f.currencyCode = code
        f.minimumFractionDigits = 2; f.maximumFractionDigits = 2
        switch code.uppercased() {
        case "GBP": f.locale = Locale(identifier: "en_GB")
        case "USD": f.locale = Locale(identifier: "en_US")
        case "EUR": f.locale = Locale(identifier: "de_DE")
        default: f.locale = Locale(identifier: "en_GB")
        }
        let fallback = "\(currencySymbol(code))\(String(format: "%.2f", amount))"
        return f.string(from: NSNumber(value: amount)) ?? fallback
    }

    static func currencySymbol(_ code: String) -> String {
        switch code.uppercased() {
        case "GBP": return "£"
        case "USD": return "$"
        case "EUR": return "€"
        default: return code + " "
        }
    }

    static func formatTimestamp(_ ms: Int64?) -> String {
        guard let ms = ms, ms > 0 else { return "—" }
        let df = DateFormatter(); df.dateFormat = "dd MMM yyyy"; df.locale = Locale(identifier: "en_GB")
        return df.string(from: Date(timeIntervalSince1970: Double(ms) / 1000))
    }

    static func formatDateTime(_ ms: Int64?) -> String {
        guard let ms = ms, ms > 0 else { return "—" }
        let df = DateFormatter(); df.dateFormat = "dd MMM yyyy | h:mm a"; df.locale = Locale(identifier: "en_GB")
        return df.string(from: Date(timeIntervalSince1970: Double(ms) / 1000))
    }
}
