//
//  InvoicesViewModel+enums.swift
//  ZillitPO
//

import Foundation

// `InvoiceTab` is currently defined alongside `InvoicesModuleView`
// (Views/Invoices/InvoicesModuleView.swift) and is shared at module
// scope. New invoice/payment-run enums should be added here.

extension InvoicesViewModel {
    enum InvoiceAlert {
        case success
        case fail
        case confirmDeleteInvoice(Invoice)
    }
}
