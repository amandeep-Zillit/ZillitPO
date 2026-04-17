import SwiftUI

struct CountryCode: Identifiable {
    let code: String  // e.g. "+44"
    let name: String  // e.g. "United Kingdom"
    let flag: String  // e.g. "🇬🇧"
    var id: String { "\(code)_\(name)" }
    var displayLabel: String { "\(flag) \(name) (\(code))" }
    var shortLabel: String { "\(flag) \(code)" }
}

let countryCodes: [CountryCode] = [
    CountryCode(code: "+44", name: "United Kingdom", flag: "🇬🇧"),
    CountryCode(code: "+1", name: "United States", flag: "🇺🇸"),
    CountryCode(code: "+1", name: "Canada", flag: "🇨🇦"),
    CountryCode(code: "+91", name: "India", flag: "🇮🇳"),
    CountryCode(code: "+61", name: "Australia", flag: "🇦🇺"),
    CountryCode(code: "+353", name: "Ireland", flag: "🇮🇪"),
    CountryCode(code: "+33", name: "France", flag: "🇫🇷"),
    CountryCode(code: "+49", name: "Germany", flag: "🇩🇪"),
    CountryCode(code: "+39", name: "Italy", flag: "🇮🇹"),
    CountryCode(code: "+34", name: "Spain", flag: "🇪🇸"),
    CountryCode(code: "+351", name: "Portugal", flag: "🇵🇹"),
    CountryCode(code: "+31", name: "Netherlands", flag: "🇳🇱"),
    CountryCode(code: "+32", name: "Belgium", flag: "🇧🇪"),
    CountryCode(code: "+41", name: "Switzerland", flag: "🇨🇭"),
    CountryCode(code: "+43", name: "Austria", flag: "🇦🇹"),
    CountryCode(code: "+46", name: "Sweden", flag: "🇸🇪"),
    CountryCode(code: "+47", name: "Norway", flag: "🇳🇴"),
    CountryCode(code: "+45", name: "Denmark", flag: "🇩🇰"),
    CountryCode(code: "+358", name: "Finland", flag: "🇫🇮"),
    CountryCode(code: "+48", name: "Poland", flag: "🇵🇱"),
    CountryCode(code: "+420", name: "Czech Republic", flag: "🇨🇿"),
    CountryCode(code: "+36", name: "Hungary", flag: "🇭🇺"),
    CountryCode(code: "+40", name: "Romania", flag: "🇷🇴"),
    CountryCode(code: "+30", name: "Greece", flag: "🇬🇷"),
    CountryCode(code: "+90", name: "Turkey", flag: "🇹🇷"),
    CountryCode(code: "+7", name: "Russia", flag: "🇷🇺"),
    CountryCode(code: "+380", name: "Ukraine", flag: "🇺🇦"),
    CountryCode(code: "+972", name: "Israel", flag: "🇮🇱"),
    CountryCode(code: "+971", name: "UAE", flag: "🇦🇪"),
    CountryCode(code: "+966", name: "Saudi Arabia", flag: "🇸🇦"),
    CountryCode(code: "+974", name: "Qatar", flag: "🇶🇦"),
    CountryCode(code: "+965", name: "Kuwait", flag: "🇰🇼"),
    CountryCode(code: "+968", name: "Oman", flag: "🇴🇲"),
    CountryCode(code: "+973", name: "Bahrain", flag: "🇧🇭"),
    CountryCode(code: "+27", name: "South Africa", flag: "🇿🇦"),
    CountryCode(code: "+234", name: "Nigeria", flag: "🇳🇬"),
    CountryCode(code: "+254", name: "Kenya", flag: "🇰🇪"),
    CountryCode(code: "+20", name: "Egypt", flag: "🇪🇬"),
    CountryCode(code: "+212", name: "Morocco", flag: "🇲🇦"),
    CountryCode(code: "+86", name: "China", flag: "🇨🇳"),
    CountryCode(code: "+81", name: "Japan", flag: "🇯🇵"),
    CountryCode(code: "+82", name: "South Korea", flag: "🇰🇷"),
    CountryCode(code: "+65", name: "Singapore", flag: "🇸🇬"),
    CountryCode(code: "+60", name: "Malaysia", flag: "🇲🇾"),
    CountryCode(code: "+66", name: "Thailand", flag: "🇹🇭"),
    CountryCode(code: "+62", name: "Indonesia", flag: "🇮🇩"),
    CountryCode(code: "+63", name: "Philippines", flag: "🇵🇭"),
    CountryCode(code: "+84", name: "Vietnam", flag: "🇻🇳"),
    CountryCode(code: "+880", name: "Bangladesh", flag: "🇧🇩"),
    CountryCode(code: "+92", name: "Pakistan", flag: "🇵🇰"),
    CountryCode(code: "+94", name: "Sri Lanka", flag: "🇱🇰"),
    CountryCode(code: "+64", name: "New Zealand", flag: "🇳🇿"),
    CountryCode(code: "+55", name: "Brazil", flag: "🇧🇷"),
    CountryCode(code: "+52", name: "Mexico", flag: "🇲🇽"),
    CountryCode(code: "+54", name: "Argentina", flag: "🇦🇷"),
    CountryCode(code: "+57", name: "Colombia", flag: "🇨🇴"),
    CountryCode(code: "+56", name: "Chile", flag: "🇨🇱"),
    CountryCode(code: "+51", name: "Peru", flag: "🇵🇪"),
    CountryCode(code: "+852", name: "Hong Kong", flag: "🇭🇰"),
    CountryCode(code: "+886", name: "Taiwan", flag: "🇹🇼"),
    CountryCode(code: "+370", name: "Lithuania", flag: "🇱🇹"),
    CountryCode(code: "+371", name: "Latvia", flag: "🇱🇻"),
    CountryCode(code: "+372", name: "Estonia", flag: "🇪🇪"),
    CountryCode(code: "+385", name: "Croatia", flag: "🇭🇷"),
    CountryCode(code: "+381", name: "Serbia", flag: "🇷🇸"),
    CountryCode(code: "+359", name: "Bulgaria", flag: "🇧🇬"),
    CountryCode(code: "+386", name: "Slovenia", flag: "🇸🇮"),
    CountryCode(code: "+421", name: "Slovakia", flag: "🇸🇰"),
    CountryCode(code: "+352", name: "Luxembourg", flag: "🇱🇺"),
    CountryCode(code: "+356", name: "Malta", flag: "🇲🇹"),
    CountryCode(code: "+357", name: "Cyprus", flag: "🇨🇾"),
    CountryCode(code: "+354", name: "Iceland", flag: "🇮🇸"),
]

// MARK: - Phone Input Field (country code picker + phone number on one line)

struct PhoneField: View {
    @Binding var phoneCode: String
    @Binding var phone: String
    @State private var showCodePicker = false
    @State private var searchText = ""

    private var selectedCountry: CountryCode? {
        countryCodes.first { $0.code == phoneCode }
    }

    private var codeButtonLabel: String {
        if let c = selectedCountry { return c.shortLabel }
        return phoneCode.isEmpty ? "🌐 Code" : "🌐 \(phoneCode)"
    }

    var body: some View {
        HStack(spacing: 6) {
            // Country code picker button
            Button(action: { showCodePicker = true }) {
                HStack(spacing: 4) {
                    Text(codeButtonLabel)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .background(Color.bgSurface)
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
            }
            .buttonStyle(BorderlessButtonStyle())
            .fixedSize()

            // Phone number input
            TextField("Phone number", text: $phone)
                .font(.system(size: 13))
                .keyboardType(.phonePad)
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .background(Color.bgSurface)
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
        }
        .sheet(isPresented: $showCodePicker) {
            CountryCodePickerSheet(selectedCode: $phoneCode, isPresented: $showCodePicker)
        }
    }
}
