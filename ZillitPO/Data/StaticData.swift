import Foundation

struct ProjectData { static let projectId = "68877f89a6569e29caee0a65" }

// MARK: - Static Payment Runs 

struct PaymentRunsData {
    static let all: [PaymentRun] = {
        var pr2 = PaymentRun()
        pr2.id = "ca32ffa1-64b5-4b47-9dd6-ad4d35240190"
        pr2.projectId = ProjectData.projectId
        pr2.name = "BACs Run"; pr2.number = "PR-002"; pr2.payMethod = "bacs"
        pr2.approval = []; pr2.status = "pending"
        pr2.totalAmount = 1320; pr2.createdBy = "mock-sa"
        pr2.createdAt = 1774508635515; pr2.updatedAt = 1774508635515
        pr2.invoiceCount = 3; pr2.computedTotal = 1320
        pr2.invoices = [
            PaymentRunInvoice(id: "pri-1", invoiceNumber: "wrq42342", supplierName: "Arri Rental UK",
                              description: "Invoice — CLOUNINE HOSPITAL-LUDHIANA", dueDate: 1741737600000, amount: 750, currency: "GBP"),
            PaymentRunInvoice(id: "pri-2", invoiceNumber: "234242", supplierName: "Costume House London",
                              description: "Invoice — CLOUNINE HOSPITAL-LUDHIANA", dueDate: 1741737600000, amount: 320, currency: "GBP"),
            PaymentRunInvoice(id: "pri-3", invoiceNumber: "342354332", supplierName: "Rose Bruford Lighting",
                              description: "Invoice — CLOUNINE HOSPITAL-LUDHIANA", dueDate: 1741132800000, amount: 250, currency: "GBP"),
        ]

        var pr1 = PaymentRun()
        pr1.id = "773bf2c1-a650-45b1-8cc4-76f8f4b8304a"
        pr1.projectId = ProjectData.projectId
        pr1.name = "BACs Run"; pr1.number = "PR-001"; pr1.payMethod = "bacs"
        pr1.approval = [
            PaymentRunApproval(userId: "mock-u-pst", approvedAt: 1774437364390, tierNumber: 1),
            PaymentRunApproval(userId: "mock-jw",    approvedAt: 1774437405828, tierNumber: 2)
        ]
        pr1.status = "approved"; pr1.totalAmount = 315; pr1.createdBy = "mock-sa"
        pr1.createdAt = 1774437260411; pr1.updatedAt = 1774437405828
        pr1.invoiceCount = 0; pr1.computedTotal = 0
        return [pr2, pr1]
    }()
}

struct NominalCodes {
    static let all: [(code: String, label: String)] = [
        ("2100","Production — General"), ("2200","Art Department — Materials"),
        ("2300","Art Department — Props"), ("2400","Camera — Equipment Hire"),
        ("2500","Camera — Purchases"), ("2600","Costume — Hire"),
        ("2700","Electrical — Equipment"), ("2716","Office Stationery"),
        ("2800","Locations — Fees"), ("2900","Transport — Vehicle Hire"),
        ("3000","Catering"), ("3100","Post Production — Edit"),
        ("3200","Music"), ("4000","Travel & Accommodation"), ("5000","Miscellaneous"),
    ]
    static let deptToNominal: [String: String] = [
        "department_production":"2100", "department_art_department":"2200",
        "department_camera":"2400", "department_costume_and_wardrobe_department":"2600",
        "department_electrical_department":"2700", "department_locations":"2800",
        "department_transportation_department":"2900", "department_catering":"3000",
        "department_post_production":"3100", "department_music_department":"3200",
    ]
    static let nominalToDept: [String: String] = {
        Dictionary(uniqueKeysWithValues: deptToNominal.map { ($0.value, $0.key) })
    }()
}

let expenditureTypes = ["Purchase", "Consumption", "Rent"]

// MARK: - PO Quick Templates

let poQuickTemplates: [(id: String, icon: String, color: String, name: String, extras: [String])] = [
    ("studio","house.fill","blue","Studio / Location Hire",["Accrual-ready","Multi-week"]),
    ("crew","person.fill","purple","Crew Contract",["CIS auto-tag","Holiday accrual"]),
    ("equip","camera.fill","teal","Equipment Rental",["Rental splits","Cross-hire"]),
    ("consumables","cart.fill","orange","Consumables & Supplies",["Single line"]),
]
