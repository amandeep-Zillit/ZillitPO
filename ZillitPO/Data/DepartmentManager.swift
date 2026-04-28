//
//  DepartmentManager.swift
//  ZillitPO
//

import Foundation

class DepartmentManager {
    static let shared = DepartmentManager()

    private var localDepartments: [String: Department] = [:]

    private init() {
        var seen = Set<String>()
        let depts = UserManager.shared.getAllUsersInDevice().compactMap { u -> Department? in
            guard let deptId = u.departmentId, !seen.contains(deptId) else { return nil }
            seen.insert(deptId)
            return Department(id: deptId,
                              projectId: ProjectData.projectId,
                              departmentName: u.departmentName,
                              identifier: u.departmentIdentifier,
                              systemDefined: true)
        }
        self.localDepartments = depts.reduce(into: [:]) { dict, dept in
            if let id = dept.id { dict[id] = dept }
        }

        debugPrint("DepartmentManager Loaded")
    }

    func getDeptObject(deptID: String) -> Department? {
        guard let departmentObject = localDepartments[deptID] else {
            debugPrint("departmentObject Data not found for deptID : \(deptID)")
            return nil
        }
        return departmentObject
    }

    func getDepartmentsIds() -> [String] {
        return Array(localDepartments.keys)
    }

    // MARK: - ZillitPO-specific helper (used by DepartmentsData shim)
    func getAllDepartments() -> [Department] {
        return Array(localDepartments.values)
    }
}
