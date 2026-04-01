import Foundation

struct VATOption { let value: String; let label: String; let rate: Double }
struct VATResult { let vatAmount: Double; let gross: Double; let reverseCharged: Bool }

struct VATHelpers {
    static let options: [VATOption] = [
        VATOption(value: "pending", label: "Pending", rate: 0),
        VATOption(value: "standard_20", label: "20% Standard Rate", rate: 0.20),
        VATOption(value: "exempt", label: "Exempt", rate: 0),
        VATOption(value: "zero_rated", label: "Zero Rated", rate: 0),
        VATOption(value: "reverse_charged", label: "Reverse Charged", rate: 0.20),
        VATOption(value: "outside_scope", label: "Outside Scope", rate: 0),
    ]

    static func calcVat(_ net: Double, treatment: String = "pending") -> VATResult {
        switch treatment {
        case "standard_20": return VATResult(vatAmount: net * 0.20, gross: net * 1.20, reverseCharged: false)
        case "reverse_charged": return VATResult(vatAmount: net * 0.20, gross: net, reverseCharged: true)
        default: return VATResult(vatAmount: 0, gross: net, reverseCharged: false)
        }
    }

    static func vatLabel(_ t: String?) -> String {
        options.first { $0.value == (t ?? "") }?.label ?? "Pending"
    }
}
