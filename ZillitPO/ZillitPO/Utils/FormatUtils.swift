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
        let f = NumberFormatter(); f.numberStyle = .currency; f.currencyCode = "GBP"
        f.locale = Locale(identifier: "en_GB"); f.minimumFractionDigits = 2
        return f.string(from: NSNumber(value: amount)) ?? "£0.00"
    }

    static func formatTimestamp(_ ms: Int64?) -> String {
        guard let ms = ms, ms > 0 else { return "—" }
        let df = DateFormatter(); df.dateFormat = "dd MMM yyyy"; df.locale = Locale(identifier: "en_GB")
        return df.string(from: Date(timeIntervalSince1970: Double(ms) / 1000))
    }
}
