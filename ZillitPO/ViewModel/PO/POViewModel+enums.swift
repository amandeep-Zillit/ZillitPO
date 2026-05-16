//
//  POViewModel+enums.swift
//  ZillitPO
//
//  PO-scoped enums. The module-scope `DeptTab` / `QuickFilter` /
//  `SortKey` / `POFormData` declared in the legacy
//  `/ViewModel/LegacyPOViewModel+enums.swift` are intentionally shared
//  — both `POViewModel` and `LegacyPOViewModel` reference them, so
//  they stay where they are until the legacy file is removed.
//

import Foundation

extension POViewModel {
    enum POAlert {
        case success
        case fail
        case confirmDeletePO(PurchaseOrder)
        case confirmDeleteTemplate(String)
        case confirmDeleteDraft(String)
        case confirmDeleteVendor(String)
    }
}
