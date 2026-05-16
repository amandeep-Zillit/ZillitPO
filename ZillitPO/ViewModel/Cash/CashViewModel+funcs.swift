//
//  CashViewModel+funcs.swift
//  ZillitPO
//

import Foundation

extension CashViewModel {

    var myPettyCashClaims: [ClaimBatch] { myClaims.filter { $0.isPettyCash } }
    var myOOPClaims: [ClaimBatch] { myClaims.filter { $0.isOutOfPocket } }
    var allPettyCashClaims: [ClaimBatch] { allClaims.filter { $0.isPettyCash } }
    var allOOPClaims: [ClaimBatch] { allClaims.filter { $0.isOutOfPocket } }
}
