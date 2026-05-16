//
//  AccountHubViewModel+funcs.swift
//  ZillitPO
//

import Foundation

extension AccountHubViewModel {
    // Pure computed helpers / non-network functions for the Account Hub
    // (vendors + session) layer.

    func prepareAlert(type: AccountHubViewModel.AHAlert, title: String, message: String) {
        self.alertType = type
        self.alertTitle = title
        self.alertMessage = message
        self.showAlert = true
    }
}
