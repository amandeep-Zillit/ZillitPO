//
//  InvoicesViewModel+funcs.swift
//  ZillitPO
//

import Foundation

extension InvoicesViewModel {
    func prepareAlert(type: InvoicesViewModel.InvoiceAlert, title: String, message: String) {
        self.alertType = type
        self.alertTitle = title
        self.alertMessage = message
        self.showAlert = true
    }
}
