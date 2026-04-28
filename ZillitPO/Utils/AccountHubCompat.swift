//
//  AccountHubCompat.swift
//  ZillitPO
//

import Foundation

// MARK: - UsersData shim
//
// Compatibility wrapper around `UserManager` so existing callers
// (`UsersData.allUsers`, `UsersData.byId[...]`, etc.) keep working
// after the move from a static struct to a singleton manager.

enum UsersData {
    static var accountsTeam: [AppUser] { UserManager.shared.getAccountsTeam() }
    static var departmentUsers: [AppUser] { UserManager.shared.getDepartmentUsers() }
    static var allUsers: [AppUser] { UserManager.shared.getAllUsersInDevice() }
    static var byId: [String: AppUser] { UserManager.shared.getUserDictionary() }
}

// MARK: - DepartmentsData shim
//
// Compatibility wrapper around `DepartmentManager` so existing callers
// (`DepartmentsData.sorted`, `DepartmentsData.all`) keep working
// after the move from a static struct to a singleton manager.

enum DepartmentsData {
    static var all: [Department] { DepartmentManager.shared.getAllDepartments() }
    static var sorted: [Department] {
        DepartmentManager.shared.getAllDepartments().sorted { $0.displayName < $1.displayName }
    }
}
