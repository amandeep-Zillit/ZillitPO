import SwiftUI
import UIKit

struct EditCardTransactionPage: View {
    let transaction: CardTransaction
    @EnvironmentObject var appState: POViewModel
    @Environment(\.presentationMode) var presentationMode

    @State private var merchant: String = ""
    @State private var amount: String = ""
    @State private var date: Date? = nil
    @State private var costCode: String = ""
    @State private var episode: String = ""
    @State private var codingDescription: String = ""
    @State private var fileName: String = ""
    @State private var fileData: Data?
    @State private var navigateToFilePicker = false
    @State private var showCodeSheet = false
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var showError = false

    private var hasFile: Bool { fileData != nil && !fileName.isEmpty }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // Upload section
                VStack(alignment: .leading, spacing: 8) {
                    Text("RECEIPT FILE").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.5)
                    if hasFile {
                        HStack(spacing: 8) {
                            Image(systemName: "paperclip").font(.system(size: 11)).foregroundColor(.green)
                            Text(fileName).font(.system(size: 12)).foregroundColor(Color(red: 0.2, green: 0.6, blue: 0.3)).lineLimit(1)
                            Spacer()
                            Button(action: { fileName = ""; fileData = nil }) {
                                Text("Remove").font(.system(size: 9, weight: .bold)).foregroundColor(.white)
                                    .padding(.horizontal, 6).padding(.vertical, 3).background(Color.red).cornerRadius(4)
                            }.buttonStyle(BorderlessButtonStyle())
                        }
                        .padding(8).background(Color.green.opacity(0.06)).cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.green.opacity(0.2), lineWidth: 1))
                    } else {
                        Button(action: { navigateToFilePicker = true }) {
                            VStack(spacing: 6) {
                                Image(systemName: "arrow.up.doc").font(.system(size: 22)).foregroundColor(.gray.opacity(0.4))
                                Text("Upload receipt image or PDF").font(.system(size: 12, weight: .semibold)).foregroundColor(.secondary)
                                Text("Tap to browse · JPG, PNG, PDF").font(.system(size: 10)).foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 16)
                            .background(Color.bgRaised).cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6])).foregroundColor(Color.borderColor))
                        }.buttonStyle(PlainButtonStyle())
                    }
                }

                // Merchant / Description
                field(label: "MERCHANT / DESCRIPTION", binding: $merchant, placeholder: "Merchant")

                // Amount + Date
                HStack(alignment: .top, spacing: 12) {
                    field(label: "AMOUNT", binding: $amount, placeholder: "0.00", keyboard: .decimalPad)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("DATE").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
                        DateField(date: $date,
                                  placeholder: "Select date",
                                  navigationTitle: "Transaction Date")
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }

                // Budget Coding
                VStack(alignment: .leading, spacing: 10) {
                    Text("BUDGET CODING").font(.system(size: 10, weight: .bold)).foregroundColor(.secondary).tracking(0.4)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("COST CODE").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
                        Button(action: { showCodeSheet = true }) {
                            HStack {
                                Text(costCode.isEmpty ? "Select code..." : (costCodeOptions.first { $0.0 == costCode }?.1 ?? costCode))
                                    .font(.system(size: 13)).foregroundColor(costCode.isEmpty ? .gray : .primary)
                                Spacer()
                                Image(systemName: "chevron.down").font(.system(size: 10)).foregroundColor(.gray)
                            }
                            .padding(8).background(Color.bgRaised).cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                        }.buttonStyle(BorderlessButtonStyle())
                    }

                    HStack(spacing: 12) {
                        field(label: "EPISODE", binding: $episode, placeholder: "e.g. Ep.3")
                        field(label: "DESCRIPTION", binding: $codingDescription, placeholder: "Coding description")
                    }
                }
                .padding(12)
                .background(Color.bgSurface).cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))

                // Save button
                Button(action: save) {
                    HStack(spacing: 6) {
                        if isSaving { ActivityIndicator(isAnimating: true).frame(width: 16, height: 16) }
                        Text(isSaving ? "Saving..." : "Save Receipt")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(isSaving ? Color.gold.opacity(0.4) : Color.gold)
                    .cornerRadius(10)
                }
                .disabled(isSaving)
                .buttonStyle(BorderlessButtonStyle())
            }
            .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 24)
        }
        .background(Color.bgBase)
        .navigationBarTitle(Text("Edit Receipt"), displayMode: .inline)
        .background(
            NavigationLink(destination: ClaimFilePickerPage(onFilePicked: { name, data in
                fileName = name
                fileData = data
            }), isActive: $navigateToFilePicker) { EmptyView() }.frame(width: 0, height: 0).hidden()
        )
        .alert(isPresented: $showError) {
            Alert(title: Text("Error"), message: Text(saveError ?? "Unknown error"), dismissButton: .default(Text("OK")))
        }
        .appActionSheet(title: "Cost Code", isPresented: $showCodeSheet, items:
            [.action("None") { costCode = "" }]
            + costCodeOptions.map { c in .action(c.1) { costCode = c.0 } }
        )
        .onAppear {
            merchant = transaction.merchant ?? ""
            amount = (transaction.amount ?? 0) > 0 ? String(transaction.amount ?? 0) : ""
            if (transaction.transactionDate ?? 0) > 0 {
                date = Date(timeIntervalSince1970: TimeInterval(transaction.transactionDate ?? 0) / 1000)
            } else {
                date = nil
            }
            costCode = transaction.nominalCode ?? ""
            episode = transaction.episode ?? ""
            codingDescription = (transaction.codeDescription ?? "").isEmpty ? (transaction.notes ?? "") : (transaction.codeDescription ?? "")
        }
    }

    private func field(label: String, binding: Binding<String>, placeholder: String, keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 10, weight: .semibold)).foregroundColor(.secondary)
            TextField(placeholder, text: binding)
                .font(.system(size: 13)).keyboardType(keyboard)
                .padding(8).background(Color.bgRaised).cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
        }
    }

    private func save() {
        isSaving = true
        appState.updateCardTransaction(
            id: transaction.id,
            merchant: merchant,
            amount: amount,
            nominalCode: costCode,
            notes: codingDescription
        )
        // If a file was selected, upload it
        if let data = fileData, !fileName.isEmpty {
            uploadFile(data: data, name: fileName) { err in
                isSaving = false
                if let e = err { saveError = e; showError = true; return }
                appState.loadCardTransactions()
                presentationMode.wrappedValue.dismiss()
            }
        } else {
            isSaving = false
            presentationMode.wrappedValue.dismiss()
        }
    }

    private func uploadFile(data: Data, name: String, completion: @escaping (String?) -> Void) {
        guard let user = appState.currentUser else { completion("No user"); return }
        let ext = (name as NSString).pathExtension.lowercased()
        let mimeType: String = {
            switch ext {
            case "pdf": return "application/pdf"
            case "png": return "image/png"
            default: return "image/jpeg"
            }
        }()
        let boundary = "Boundary-\(UUID().uuidString)"
        guard let url = URL(string: "\(CardExpenseRequest.baseURL)/api/v2/card-expenses/receipts/upload") else {
            completion("Invalid URL"); return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"; req.timeoutInterval = 60
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.setValue(APIClient.shared.projectId, forHTTPHeaderField: "x-project-id")
        req.setValue(APIClient.shared.userId, forHTTPHeaderField: "x-user-id")

        var body = Data()
        func addField(_ k: String, _ v: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(k)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(v)\r\n".data(using: .utf8)!)
        }
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(name)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(data); body.append("\r\n".data(using: .utf8)!)
        addField("userId", user.id ?? "")
        addField("uploaderName", user.fullName ?? "")
        addField("uploaderDepartment", user.displayDepartment)
        addField("transaction_id", transaction.id)
        addField("amount", amount)
        addField("description", merchant)
        if let d = date {
            addField("date", String(Int64(d.timeIntervalSince1970 * 1000)))
        }
        if !costCode.isEmpty { addField("nominal_code", costCode) }
        if !episode.isEmpty { addField("episode", episode) }
        if !codingDescription.isEmpty { addField("coded_description", codingDescription) }
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body

        URLSession.shared.dataTask(with: req) { _, resp, err in
            DispatchQueue.main.async {
                if let err = err { completion(err.localizedDescription); return }
                if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                    completion("Upload failed (\(http.statusCode))"); return
                }
                completion(nil)
            }
        }.resume()
    }
}

