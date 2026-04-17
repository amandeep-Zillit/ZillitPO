import SwiftUI
import UIKit

// ═══════════════════════════════════════════════════════════════════
// MARK: - PO Queries Page
// Mirrors `InvoiceQueriesPage` — single chat thread per PO sourced
// from `/api/v2/account-hub/queries/entity/purchase_order/{id}`.
// ═══════════════════════════════════════════════════════════════════

/// Flattened chat message (query root or reply) used for display.
private struct POQueryMessage: Identifiable {
    let id: String
    let userId: String?
    let userName: String?
    let text: String
    let timestamp: Int64?
    let isLocal: Bool   // optimistic local addition before server POST
}

struct POQueriesPage: View {
    @EnvironmentObject var appState: POViewModel
    let poId: String
    let poLabel: String

    @State private var draft: String = ""
    @State private var localMessages: [POQueryMessage] = []

    private var thread: InvoiceQueryThread? { appState.poQueries[poId] }

    /// Flatten the backend thread's `messages` + any optimistic local
    /// messages into a single sorted chat list.
    private var messages: [POQueryMessage] {
        var list: [POQueryMessage] = []
        if let t = thread {
            for m in t.messages ?? [] {
                guard let body = m.query, !body.isEmpty else { continue }
                list.append(POQueryMessage(
                    id: m.id,
                    userId: m.queriedBy,
                    userName: nil,        // backend doesn't ship a name; resolve via UsersData
                    text: body,
                    timestamp: m.queriedAt,
                    isLocal: false
                ))
            }
        }
        list.append(contentsOf: localMessages)
        return list.sorted { ($0.timestamp ?? 0) < ($1.timestamp ?? 0) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Header: PO number (centered) ────────────────────────
            Text(poLabel.isEmpty ? "—" : poLabel)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 10)

            Divider()

            // ── Chat area ───────────────────────────────────────────
            Group {
                if appState.poQueriesLoading && messages.isEmpty {
                    VStack { Spacer(); LoaderView(); Spacer() }
                } else if messages.isEmpty {
                    VStack(spacing: 10) {
                        Spacer()
                        Image(systemName: "text.bubble")
                            .font(.system(size: 32)).foregroundColor(.gray.opacity(0.4))
                        Text("No messages yet")
                            .font(.system(size: 13, weight: .semibold)).foregroundColor(.secondary)
                        Text("Type a message to start the conversation.")
                            .font(.system(size: 11)).foregroundColor(.gray)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    ScrollView {
                        VStack(alignment: .trailing, spacing: 16) {
                            ForEach(messages) { m in messageBubble(m) }
                        }
                        .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 16)
                    }
                }
            }
            .frame(maxHeight: .infinity)

            // ── Composer ─────────────────────────────────────────────
            Divider()
            HStack(spacing: 10) {
                TextField("Type a message…", text: $draft)
                    .font(.system(size: 14))
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Capsule().fill(Color.bgSurface))
                    .overlay(Capsule().stroke(Color.borderColor, lineWidth: 1))
                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(draft.trimmingCharacters(in: .whitespaces).isEmpty
                            ? Color.gold.opacity(0.5)
                            : Color(red: 0.95, green: 0.55, blue: 0.15)))
                }
                .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
                .buttonStyle(BorderlessButtonStyle())
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(Color.bgSurface)
        }
        .background(Color.bgSurface.edgesIgnoringSafeArea(.all))
        .navigationBarTitle(Text("Query"), displayMode: .inline)
        .onAppear { appState.loadPOQueries(poId) }
    }

    // MARK: - Chat bubble (right-aligned, orange)

    private func messageBubble(_ m: POQueryMessage) -> some View {
        let resolvedName: String = {
            if let n = m.userName, !n.isEmpty { return n }
            if let uid = m.userId { return UsersData.byId[uid].flatMap { $0.fullName } ?? "Unknown" }
            return "Unknown"
        }()
        let role: String = {
            if let uid = m.userId, let u = UsersData.byId[uid] {
                return u.displayDesignation
            }
            return ""
        }()
        let stamp: String = {
            guard let ts = m.timestamp, ts > 0 else { return "" }
            return FormatUtils.formatHistoryDateTime(ts)
        }()
        let orange = Color(red: 0.95, green: 0.55, blue: 0.15)
        return HStack {
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    Text(resolvedName).font(.system(size: 13, weight: .bold))
                    if !role.isEmpty {
                        Text(role).font(.system(size: 12)).foregroundColor(.secondary)
                    }
                }

                Text(m.text)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(orange)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .frame(maxWidth: UIScreen.main.bounds.width * 0.78, alignment: .trailing)
                    .fixedSize(horizontal: false, vertical: true)

                if !stamp.isEmpty {
                    Text(stamp)
                        .font(.system(size: 10)).foregroundColor(.gray)
                }
            }
        }
    }

    // MARK: - Send (optimistic local only — no POST endpoint wired yet)

    private func sendMessage() {
        let text = draft.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let me = appState.currentUser
        localMessages.append(POQueryMessage(
            id: UUID().uuidString,
            userId: me?.id,
            userName: me?.fullName,
            text: text,
            timestamp: now,
            isLocal: true
        ))
        draft = ""
        print("⚠️ sendPOQueryMessage: no POST endpoint wired yet. Message added locally.")
    }
}
