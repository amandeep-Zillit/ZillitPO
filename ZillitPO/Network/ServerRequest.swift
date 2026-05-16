//
//  ServerRequest.swift
//  ZillitPO
//
//  Single source of truth for base URLs. Every microservice constant
//  spells its URL out explicitly so each one can be repointed
//  independently (matches live's `RequestConstraint.swift` style —
//  each `*_BASE_URL` is its own literal).
//
//  On copy-paste to live, swap this file for live's
//  `Zillit/NetworkRequest/RequestConstraint.swift` which exposes the
//  same constants keyed off the build scheme + per-microservice
//  subdomain.
//

import Foundation

struct ServerRequest {

    // Demo backend host. Kept as a named constant so the few legacy
    // callers (`APIClient.shared.baseURL`) still have a single host to
    // resolve — every per-microservice URL below uses the same string
    // literal explicitly, though, so any of them can be redirected
    // independently if needed.
    static let DEMO_BASE_HOST = "https://accounthub-dev.zillit.com"

    // MARK: - AccountHub (vendors, queries, approval-tiers, form-templates, bank accounts)
    static let ACC_HUB_BASE_URL = "https://accounthub-dev.zillit.com/api/v2/"

    // MARK: - Purchase Orders
    static let PO_BASE_URL = "https://accounthub-dev.zillit.com/api/v2/"

    // MARK: - Invoices
    static let INVOICES_BASE_URL = "https://accounthub-dev.zillit.com/api/v2/"

    // MARK: - Card Expenses
    static let CARD_BASE_URL = "https://accounthub-dev.zillit.com/api/v2/"

    // MARK: - Cash Expenses
    static let CASH_BASE_URL = "https://accounthub-dev.zillit.com/api/v2/"

    // MARK: - Deal Memo
    static let DEAL_MEMO_BASE_URL = "https://accounthub-dev.zillit.com/api/v2/"

    // MARK: - Time Card
    static let TIMECARD_BASE_URL = "https://accounthub-dev.zillit.com/api/v2/"

    // MARK: - Debug flag (live parity — always true for demo)
    static var IF_DEBUG: Bool { true }

    // MARK: - Raw host (no /api/v2 suffix)
    /// Used by `APIClient.shared.baseURL` so paths starting with `/api/v2/`
    /// still resolve. Live doesn't expose this — it composes via the
    /// BASE_URL constants above.
    static var DEMO_HOST_ONLY: String { DEMO_BASE_HOST }
}
