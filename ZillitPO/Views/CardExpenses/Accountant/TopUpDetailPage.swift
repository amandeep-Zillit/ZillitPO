import SwiftUI

struct TopUpDetailPage: View {
    let item: TopUpItem
    @EnvironmentObject var appState: POViewModel

    private var statusColors: (Color, Color) {
        let teal = Color(red: 0.0, green: 0.6, blue: 0.5)
        let orange = Color(red: 0.95, green: 0.55, blue: 0.15)
        switch (item.status ?? "").lowercased() {
        case "completed": return (teal, teal.opacity(0.12))
        case "skipped":   return (.gray, Color.gray.opacity(0.15))
        case "partial":   return (orange, orange.opacity(0.12))
        case "pending":   return (.goldDark, Color.gold.opacity(0.15))
        default:          return (.gray, Color.gray.opacity(0.12))
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                // Summary card
                VStack(alignment: .leading, spacing: 0) {
                    // Header row
                    HStack {
                        Text("Top-Up Details").font(.system(size: 15, weight: .bold))
                        Spacer()
                        let (fg, bg) = statusColors
                        Text(item.statusDisplay).font(.system(size: 10, weight: .bold)).foregroundColor(fg)
                            .padding(.horizontal, 8).padding(.vertical, 4).background(bg).cornerRadius(4)
                    }
                    .padding(14)

                    Divider()

                    // Cardholder + card
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .top, spacing: 12) {
                            infoCell(label: "CARDHOLDER",
                                     value: UsersData.byId[item.userId ?? ""]?.fullName ?? ((item.holderName ?? "").isEmpty ? "—" : (item.holderName ?? "")))
                            infoCell(label: "CARD",
                                     value: (item.cardLastFour ?? "").isEmpty ? "—" : "•••• \(item.cardLastFour ?? "")",
                                     mono: true)
                        }
                        HStack(alignment: .top, spacing: 12) {
                            infoCell(label: "DEPARTMENT",
                                     value: (item.department ?? "").isEmpty ? "—" : (item.department ?? ""))
                            infoCell(label: "BS CONTROL CODE",
                                     value: (item.bsControlCode ?? "").isEmpty ? "—" : (item.bsControlCode ?? ""),
                                     mono: true)
                        }
                    }
                    .padding(14)

                    Divider()

                    // Amounts
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .top, spacing: 12) {
                            infoCell(label: "TOP-UP AMOUNT",
                                     value: FormatUtils.formatGBP(item.amount ?? 0),
                                     valueColor: Color(red: 0.95, green: 0.55, blue: 0.15), mono: true)
                            infoCell(label: "METHOD",
                                     value: (item.method ?? "").lowercased() == "restore" ? "Restore float" : item.methodDisplay)
                        }
                        HStack(alignment: .top, spacing: 12) {
                            infoCell(label: "CURRENT BALANCE",
                                     value: FormatUtils.formatGBP(item.cardBalance ?? 0),
                                     valueColor: Color(red: 0.0, green: 0.6, blue: 0.5), mono: true)
                            infoCell(label: "CARD LIMIT",
                                     value: FormatUtils.formatGBP(item.cardLimit ?? 0),
                                     mono: true)
                        }
                        HStack(alignment: .top, spacing: 12) {
                            infoCell(label: "SPENT",
                                     value: FormatUtils.formatGBP(item.cardSpent ?? 0), mono: true)
                            infoCell(label: "REMAINING",
                                     value: FormatUtils.formatGBP(max(0, (item.cardLimit ?? 0) - (item.cardSpent ?? 0))), mono: true)
                        }
                    }
                    .padding(14)

                    // Receipt source
                    if !(item.receiptMerchant ?? "").isEmpty || (item.receiptAmount ?? 0) > 0 {
                        Divider()
                        VStack(alignment: .leading, spacing: 6) {
                            Text("SOURCE RECEIPT").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
                            HStack {
                                Text((item.receiptMerchant ?? "").isEmpty ? "—" : (item.receiptMerchant ?? ""))
                                    .font(.system(size: 13, weight: .semibold))
                                Spacer()
                                if (item.receiptAmount ?? 0) > 0 {
                                    Text(FormatUtils.formatGBP(item.receiptAmount ?? 0))
                                        .font(.system(size: 12, design: .monospaced)).foregroundColor(.gray)
                                }
                            }
                        }
                        .padding(14)
                    }

                    // Note
                    if !(item.note ?? "").isEmpty {
                        Divider()
                        VStack(alignment: .leading, spacing: 4) {
                            Text("NOTE").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
                            Text(item.note ?? "").font(.system(size: 12)).italic()
                        }.padding(14)
                    }

                    // Dates
                    Divider()
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .top, spacing: 12) {
                            infoCell(label: "CREATED",
                                     value: (item.createdAt ?? 0) > 0 ? FormatUtils.formatTimestamp(item.createdAt ?? 0) : "—")
                            infoCell(label: "UPDATED",
                                     value: (item.updatedAt ?? 0) > 0 ? FormatUtils.formatTimestamp(item.updatedAt ?? 0) : "—")
                        }
                    }
                    .padding(14)
                }
                .background(Color.bgSurface).cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.borderColor, lineWidth: 1))
            }
            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 24)
        }
        .background(Color.bgBase)
        .navigationBarTitle(Text("Top-Up Details"), displayMode: .inline)
    }

    private func infoCell(label: String, value: String, valueColor: Color = .primary, mono: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
            Text(value)
                .font(mono ? .system(size: 14, weight: .bold, design: .monospaced) : .system(size: 13, weight: .semibold))
                .foregroundColor(valueColor)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
