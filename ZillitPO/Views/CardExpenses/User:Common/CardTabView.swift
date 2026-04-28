import SwiftUI

struct CardTabView: View {
    @EnvironmentObject var appState: POViewModel
    @State private var navigateToRequestCard = false
    @State private var selectedCard: ExpenseCard?
    @State private var navigateToCardDetail = false
    @State private var activeFilter: CardFilter = .all
    @State private var showFilterSheet = false
    @State private var searchText: String = ""

    /// Status filter options for the card list. Each case maps to one or
    /// more raw `ExpenseCard.status` values — mirrors
    /// `ExpenseCard.statusDisplay(isAccountant:)` so labels and matching
    /// agree.
    enum CardFilter: String, CaseIterable, Identifiable {
        case all              = "All Status"
        case active           = "Active"
        case approved         = "Approved"
        case pendingApproval  = "Pending Approval"
        case requested        = "Requested"
        case rejected         = "Rejected"
        var id: String { rawValue }
        var matchStatuses: [String] {
            switch self {
            case .all:             return []
            case .active:          return ["active"]
            case .approved:        return ["approved", "override"]
            case .pendingApproval: return ["pending"]
            case .requested:       return ["requested"]
            case .rejected:        return ["rejected"]
            }
        }
    }

    private var filteredCards: [ExpenseCard] {
        var list = appState.userCards
        // Status filter
        if activeFilter != .all {
            let matches = Set(activeFilter.matchStatuses)
            list = list.filter { matches.contains(($0.status ?? "").lowercased()) }
        }
        // Search — matches holder name, card last 4, department, designation,
        // bank name, and BS control code so the user can find a card by any
        // human-meaningful detail visible on the row.
        let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        if !q.isEmpty {
            list = list.filter { card in
                card.holderFullName.lowercased().contains(q) ||
                (card.lastFour ?? "").lowercased().contains(q) ||
                (card.department ?? "").lowercased().contains(q) ||
                card.holderDesignation.lowercased().contains(q) ||
                card.bankName.lowercased().contains(q) ||
                (card.bsControlCode ?? "").lowercased().contains(q)
            }
        }
        return list
    }

    @available(iOS, deprecated: 16.0, message: "iOS 13 compat — uses legacy NavigationLink(destination:isActive:label:)")
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.bgBase.edgesIgnoringSafeArea(.all)
            ScrollView {
                VStack(spacing: 12) {
                    // Filter + search row — same pattern as ReceiptsTabView.
                    // Hidden on the zero-cards empty state so the "Request
                    // Card" CTA stays front and center.
                    if !appState.userCards.isEmpty {
                        HStack(spacing: 8) {
                            // Search field (takes remaining width)
                            HStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.gray).font(.system(size: 14))
                                TextField("Search cards…", text: $searchText).font(.system(size: 14))
                                if !searchText.isEmpty {
                                    Button(action: { searchText = "" }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 14)).foregroundColor(.gray)
                                    }.buttonStyle(BorderlessButtonStyle())
                                }
                            }
                            .padding(10).background(Color.bgSurface).cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))

                            // Status filter pill
                            Button(action: { showFilterSheet = true }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "line.3.horizontal.decrease")
                                        .font(.system(size: 10, weight: .medium)).foregroundColor(.goldDark)
                                    Text(activeFilter.rawValue)
                                        .font(.system(size: 12, weight: .semibold)).foregroundColor(.primary).lineLimit(1)
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 8, weight: .medium)).foregroundColor(.gray)
                                }
                                .padding(.horizontal, 10).padding(.vertical, 10)
                                .background(Color.bgSurface).cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(BorderlessButtonStyle())
                            .selectionActionSheet(
                                title: "Filter by Status",
                                isPresented: $showFilterSheet,
                                options: CardFilter.allCases,
                                isSelected: { $0 == activeFilter },
                                label: { $0.rawValue },
                                onSelect: { activeFilter = $0 }
                            )
                        }
                    }

                    if appState.isLoadingCards && appState.userCards.isEmpty {
                        LoaderView()
                    } else if appState.userCards.isEmpty {
                        VStack(spacing: 12) {
                            Spacer(minLength: 0)
                            Image(systemName: "creditcard").font(.system(size: 32)).foregroundColor(.gray.opacity(0.3))
                            Text("No cards yet").font(.system(size: 14, weight: .semibold)).foregroundColor(.secondary)
                            Text("Request a new card to get started").font(.system(size: 12)).foregroundColor(.gray)
                            Spacer(minLength: 0)
                        }.frame(maxWidth: .infinity, minHeight: 480)
                    } else if filteredCards.isEmpty {
                        // Cards exist but none match the filter/search — show
                        // a context-aware empty state rather than the generic
                        // zero-cards CTA. The sub-copy adapts to whether
                        // only the filter, only the search, or both narrowed
                        // the list to zero.
                        let hasQuery = !searchText.trimmingCharacters(in: .whitespaces).isEmpty
                        VStack(spacing: 12) {
                            Spacer(minLength: 0)
                            Image(systemName: hasQuery ? "magnifyingglass" : "line.3.horizontal.decrease")
                                .font(.system(size: 28)).foregroundColor(.gray.opacity(0.3))
                            Text(hasQuery ? "No cards match \"\(searchText)\"" : "No \(activeFilter.rawValue.lowercased()) cards")
                                .font(.system(size: 13, weight: .semibold)).foregroundColor(.secondary)
                                .multilineTextAlignment(.center).padding(.horizontal, 16)
                            Text("Try a different filter or search term.")
                                .font(.system(size: 11)).foregroundColor(.gray)
                            Spacer(minLength: 0)
                        }.frame(maxWidth: .infinity, minHeight: 400)
                    } else {
                        ForEach(filteredCards) { card in
                            Button(action: {
                                selectedCard = card
                                navigateToCardDetail = true
                            }) {
                                CardRow(card: card, isAccountant: appState.currentUser?.isAccountant ?? false)
                            }.buttonStyle(PlainButtonStyle())
                        }
                    }
                }.padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 80)
            }

            // Request new card button
            Button(action: { navigateToRequestCard = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus").font(.system(size: 14, weight: .bold))
                    Text("Request Card").font(.system(size: 14, weight: .bold))
                }.foregroundColor(.black)
                .padding(.horizontal, 20).padding(.vertical, 14)
                .background(Color.gold).cornerRadius(28)
            }.padding(.trailing, 20).padding(.bottom, 24)
        }
        .background(
            Group {
                NavigationLink(destination: RequestCardPage().environmentObject(appState), isActive: $navigateToRequestCard) { EmptyView() }
                    .frame(width: 0, height: 0).hidden()
                NavigationLink(destination: Group {
                    if let c = selectedCard { CardDetailPage(card: c).environmentObject(appState) }
                    else { EmptyView() }
                }, isActive: $navigateToCardDetail) { EmptyView() }.frame(width: 0, height: 0).hidden()
            }
        )
        .onAppear {
            // Reset the filter + search when the tab reappears (e.g. after
            // returning from a tapped card) so the list isn't stuck on a
            // stale filter or search term.
            activeFilter = .all
            searchText = ""
            appState.loadUserCards()
        }
    }
}
