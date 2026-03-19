import Foundation

struct ApprovalVisibility {
    let visible: Bool; let canApprove: Bool; let nextTier: Int?
    let totalTiers: Int; let approvedCount: Int; let isCreator: Bool
}

struct ApproverDeptInfo { let approverDeptIds: [String]; let isApproverInAllScope: Bool }

struct ApprovalHelpers {
    static func getTotalTiers(_ c: LegacyTierConfig?) -> Int { c?.count ?? 0 }

    static func getNextTier(po: PurchaseOrder, config: LegacyTierConfig) -> Int? {
        let total = getTotalTiers(config); guard total > 0 else { return nil }
        let done = Set(po.approvals.map { $0.tierNumber })
        for t in 1...total { if !done.contains(t) { return t } }
        return nil
    }

    static func canApproveAtTier(_ c: LegacyTierConfig, tier: Int, userId: String, deptId: String?) -> Bool {
        guard let entries = c[String(tier)] else { return false }
        return entries.contains { $0.userId == userId && ($0.departmentId == nil || $0.departmentId == deptId) }
    }

    static func getAutoApprovals(_ c: LegacyTierConfig?, userId: String, deptId: String?) -> [Approval] {
        guard let c = c else { return [] }; var out: [Approval] = []
        for t in 1...getTotalTiers(c) {
            if canApproveAtTier(c, tier: t, userId: userId, deptId: deptId) {
                out.append(Approval(userId: userId, tierNumber: t, approvedAt: Int64(Date().timeIntervalSince1970 * 1000)))
            } else { break }
        }; return out
    }

    static func getVisibility(po: PurchaseOrder, config: LegacyTierConfig, userId: String) -> ApprovalVisibility {
        let total = getTotalTiers(config); let count = po.approvals.count
        let next = getNextTier(po: po, config: config); let creator = po.userId == userId
        guard po.status.uppercased() == "PENDING", total > 0 else {
            return ApprovalVisibility(visible: true, canApprove: false, nextTier: nil,
                                      totalTiers: total, approvedCount: count, isCreator: creator)
        }
        let can = next.map { canApproveAtTier(config, tier: $0, userId: userId, deptId: po.departmentId) } ?? false
        var vis = creator
        if !vis, let n = next { for t in n...total { if canApproveAtTier(config, tier: t, userId: userId, deptId: po.departmentId) { vis = true; break } } }
        return ApprovalVisibility(visible: vis, canApprove: can, nextTier: next,
                                   totalTiers: total, approvedCount: count, isCreator: creator)
    }

    static func resolveConfig(_ rows: [ApprovalTierConfig]?, deptId: String?, amount: Double? = nil) -> LegacyTierConfig? {
        guard let rows = rows, !rows.isEmpty else { return nil }
        let cfg = (deptId.flatMap { d in rows.first { $0.scope == "department" && $0.departmentId == d } }) ?? rows.first { $0.scope == "all" }
        guard let cfg = cfg else { return nil }
        let hasAmt = amount != nil
        var legacy: LegacyTierConfig = [:]; var idx = 0
        for tier in cfg.tiers {
            if let g = tier.gate { if !g.enabled { continue }; if hasAmt, g.type == "amount", let th = g.amountThreshold, (amount ?? 0) < th { continue } }
            var users: [String] = []
            if hasAmt {
                let cond = tier.rules.filter { $0.type != "default" }; var matched: [String] = []
                for r in cond { if r.type == "amount", let th = r.amountThreshold, (amount ?? 0) >= th { matched += r.userIds } }
                users = matched.isEmpty ? tier.rules.filter { $0.type == "default" }.flatMap { $0.userIds } : matched
            } else { users = tier.rules.flatMap { $0.userIds } }
            guard !users.isEmpty else { continue }; idx += 1
            var seen = Set<String>()
            legacy[String(idx)] = users.compactMap { uid in guard !seen.contains(uid) else { return nil }; seen.insert(uid)
                return LegacyTierEntry(userId: uid, departmentId: deptId, tierNumber: idx) }
        }
        return legacy.isEmpty ? nil : legacy
    }

    static func getApproverDeptIds(_ rows: [ApprovalTierConfig]?, userId: String) -> ApproverDeptInfo {
        guard let rows = rows, !userId.isEmpty else { return ApproverDeptInfo(approverDeptIds: [], isApproverInAllScope: false) }
        var depts = Set<String>(); var allScope = false
        for r in rows {
            let found = r.tiers.contains { $0.rules.contains { $0.userIds.contains(userId) } }
            if found { if r.scope == "all" { allScope = true } else if let d = r.departmentId { depts.insert(d) } }
        }
        return ApproverDeptInfo(approverDeptIds: Array(depts), isApproverInAllScope: allScope)
    }
}
