//
//  POBadgeViewModel.swift
//  ZillitPO
//
//  Demo stub. Public surface matches the live `POBadgeViewModel` (same
//  class name, same `@Published` properties, same `setupObserver` /
//  `readPoBadges` / `badgeCount(forPoId:)` signatures, same nested
//  `ToolUnit` / `PurchaseOrderUnit` / `PurchaseOrderSection` / `Level2Bucket`
//  / `PurchaseOrderAction` enums) but every observer is a no-op because
//  the demo doesn't have Firebase RTDB / Realm wired up — so badge
//  counters stay at zero and `readPoBadges` is a sink.
//
//  When pasted into live, swap this file for the real one (which
//  observes `FirebaseRTDB.shared.refInstance.getProjectCount()` and
//  reads from `NotificationLocalDBManager`).
//

import Foundation
import SwiftUI
import Combine

class POBadgeViewModel: ObservableObject {

    enum ToolUnit: String {
        case purchaseOrder = "purchase_order_label"
        case accountHub    = "account_hub_label"
    }

    enum PurchaseOrderUnit: String {
        case purchaseOrder = "purchase_order_label"
    }

    enum PurchaseOrderSection: String {
        case approvalQueue = "po_approval_queue"
        case myPO          = "my_po"
    }

    enum Level2Bucket: String {
        case poLabel   = "po_label"
        case queryChat = "query_chat"
    }

    enum PurchaseOrderAction: String {
        case poApproval = "po_accept_reject"
        case poQuery    = "query_chat"
    }

    @Published var poBadgesCount: Int = 0
    @Published var approvalQueueBadgesCount: Int = 0
    @Published var myPoBadgeCount: Int = 0

    /// Raw unread rows (live: drives per-row dots in PORow via level_3
    /// filter). Always empty in demo.
    @Published var poBadges: [LocalNotificationModel] = []

    /// Live subscribes to `FirebaseRTDB.shared.refInstance.getProjectCount()`
    /// and refreshes from `NotificationLocalDBManager`. Demo no-op.
    func setupObserver() {}

    func badgeCount(forPoId poId: String) -> Int { 0 }

    func readPoBadges(section: PurchaseOrderSection, id: String) {
        guard !id.isEmpty else { return }
        // Same no-op call as live's path — the FirebaseRTDB shim swallows it.
        FirebaseRTDB.shared.refInstance.readToolMessage(
            PurchaseOrderUnit.purchaseOrder.rawValue,
            action: .po,
            level1: section.rawValue,
            level2: Level2Bucket.poLabel.rawValue,
            level3: id
        )
    }
}
