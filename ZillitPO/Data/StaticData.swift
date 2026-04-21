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

// MARK: - All 56 Users (6 accounts + 50 department)

struct UsersData {
    static let accountsTeam: [AppUser] = [
        AppUser(id:"mock-sa",fullName:"Sarah Alderton",firstName:"Sarah",lastName:"Alderton",departmentId:"68877f89a6569e29caee0a84",departmentName:"accounts_label",departmentIdentifier:"department_accounts",designationId:"mock-desg-prod-acct",designationName:"production_accountant_label",designationIdentifier:"designation_production_accountant_accounts",status:"accepted",isAdmin:true,isOwner:false,email:"sarahalderton.ztpayrollmodules@zillit.net"),
        AppUser(id:"mock-jw",fullName:"James Whitfield",firstName:"James",lastName:"Whitfield",departmentId:"68877f89a6569e29caee0a84",departmentName:"accounts_label",departmentIdentifier:"department_accounts",designationId:"mock-desg-fin-ctrl",designationName:"financial_controller_label",designationIdentifier:"designation_financial_controller_accounts",status:"accepted",isAdmin:true,isOwner:false,email:"jameswhitfield.ztpayrollmodules@zillit.net"),
        AppUser(id:"mock-ec",fullName:"Emma Clarke",firstName:"Emma",lastName:"Clarke",departmentId:"68877f89a6569e29caee0a84",departmentName:"accounts_label",departmentIdentifier:"department_accounts",designationId:"mock-desg-1st-asst-acct",designationName:"1st_assistant_accountant_label",designationIdentifier:"designation_1st_assistant_accountant_accounts",status:"accepted",isAdmin:false,isOwner:false,email:"emmaclarke.ztpayrollmodules@zillit.net"),
        AppUser(id:"mock-rb",fullName:"Rachel Byrne",firstName:"Rachel",lastName:"Byrne",departmentId:"68877f89a6569e29caee0a84",departmentName:"accounts_label",departmentIdentifier:"department_accounts",designationId:"mock-desg-2nd-asst-acct",designationName:"2nd_assistant_accountant_label",designationIdentifier:"designation_2nd_assistant_accountant_accounts",status:"accepted",isAdmin:false,isOwner:false,email:"rachelbyrne.ztpayrollmodules@zillit.net"),
        AppUser(id:"mock-pb",fullName:"Priya Bhatt",firstName:"Priya",lastName:"Bhatt",departmentId:"68877f89a6569e29caee0a84",departmentName:"accounts_label",departmentIdentifier:"department_accounts",designationId:"mock-desg-asst-acct",designationName:"assistant_accountant_label",designationIdentifier:"designation_assistant_accountant_accounts",status:"accepted",isAdmin:false,isOwner:false,email:"priyabhatt.ztpayrollmodules@zillit.net"),
        AppUser(id:"mock-oc",fullName:"Oliver Chen",firstName:"Oliver",lastName:"Chen",departmentId:"68877f89a6569e29caee0a84",departmentName:"accounts_label",departmentIdentifier:"department_accounts",designationId:"mock-desg-acct-asst-cashier",designationName:"accounts_assistant_cashier_label",designationIdentifier:"designation_accounts_assistant_cashier_accounts",status:"accepted",isAdmin:false,isOwner:false,email:"oliverchen.ztpayrollmodules@zillit.net"),
    ]

    static let departmentUsers: [AppUser] = [
        AppUser(id:"mock-u-dir",fullName:"Michael Hargreaves",firstName:"Michael",lastName:"Hargreaves",departmentId:"68877f89a6569e29caee0a67",departmentName:"direction_label",departmentIdentifier:"department_direction",designationId:"mock-desg-director",designationName:"director_label",designationIdentifier:"designation_director_direction",status:"accepted",isAdmin:false,isOwner:false,email:"michaelhargreaves.ztpayrollmodules@zillit.net"),
        AppUser(id:"mock-u-wri",fullName:"Charlotte Osei",firstName:"Charlotte",lastName:"Osei",departmentId:"68877f89a6569e29caee0a6a",departmentName:"writer_label",departmentIdentifier:"department_writer",designationId:"mock-desg-writer",designationName:"writer_label",designationIdentifier:"designation_writer_writer",status:"accepted",isAdmin:false,isOwner:false,email:"charlotteosei.ztpayrollmodules@zillit.net"),
        AppUser(id:"mock-u-pro",fullName:"Liz Hargreaves",firstName:"Liz",lastName:"Hargreaves",departmentId:"68877f89a6569e29caee0a6d",departmentName:"producers_label",departmentIdentifier:"department_producers",designationId:"mock-desg-line-prod",designationName:"line_producer_label",designationIdentifier:"designation_line_producer_producers",status:"accepted",isAdmin:false,isOwner:false,email:"lizhargreaves.ztpayrollmodules@zillit.net"),
        AppUser(id:"mock-u-prd",fullName:"Mark Jennings",firstName:"Mark",lastName:"Jennings",departmentId:"68877f89a6569e29caee0a73",departmentName:"production_department_label",departmentIdentifier:"department_production",designationId:"mock-desg-prod-mgr",designationName:"production_manager_label",designationIdentifier:"designation_production_manager_production",status:"accepted",isAdmin:false,isOwner:false,email:"markjennings.ztpayrollmodules@zillit.net"),
        AppUser(id:"mock-u-pst",fullName:"Hannah Price",firstName:"Hannah",lastName:"Price",departmentId:"68877f89a6569e29caee0a7f",departmentName:"post_production_label",departmentIdentifier:"department_post_production",designationId:"mock-desg-post-sup",designationName:"post_supervisor_label",designationIdentifier:"designation_post_supervisor_post_production",status:"accepted",isAdmin:false,isOwner:false,email:"hannahprice.ztpayrollmodules@zillit.net"),
        AppUser(id:"mock-u-anw",fullName:"Fiona Gallagher",firstName:"Fiona",lastName:"Gallagher",departmentId:"68877f89a6569e29caee0a8d",departmentName:"animal_wranglers_label",departmentIdentifier:"department_animal_wranglers",designationId:"mock-desg-animal-wrangler",designationName:"animal_wrangler_label",designationIdentifier:"designation_animal_wrangler_animal_wranglers",status:"accepted",isAdmin:false,isOwner:false,email:"fionagallagher.ztpayrollmodules@zillit.net"),
        AppUser(id:"mock-u-arm",fullName:"Derek Shaw",firstName:"Derek",lastName:"Shaw",departmentId:"68877f89a6569e29caee0a94",departmentName:"armoury_label",departmentIdentifier:"department_armoury",designationId:"mock-desg-armourer",designationName:"armourer_label",designationIdentifier:"designation_armourer_armoury",status:"accepted",isAdmin:false,isOwner:false,email:"derekshaw.ztpayrollmodules@zillit.net"),
        AppUser(id:"mock-u-art",fullName:"Sophie Lang",firstName:"Sophie",lastName:"Lang",departmentId:"68877f89a6569e29caee0a96",departmentName:"art_department_label",departmentIdentifier:"department_art_department",designationId:"mock-desg-art-dir",designationName:"art_director_label",designationIdentifier:"designation_art_director_art_department",status:"accepted",isAdmin:false,isOwner:false,email:"sophielang.ztpayrollmodules@zillit.net"),
        AppUser(id:"mock-u-ad",fullName:"Tom Barker",firstName:"Tom",lastName:"Barker",departmentId:"68877f89a6569e29caee0ac7",departmentName:"assistant_directors_label",departmentIdentifier:"department_assistant_directors",designationId:"mock-desg-1st-ad",designationName:"1st_assistant_director_label",designationIdentifier:"designation_1st_assistant_director_assistant_directors",status:"accepted",isAdmin:false,isOwner:false,email:"tombarker.ztpayrollmodules@zillit.net"),
        AppUser(id:"mock-u-cam",fullName:"Tom Reeves",firstName:"Tom",lastName:"Reeves",departmentId:"68877f89a6569e29caee0ad9",departmentName:"camera_label",departmentIdentifier:"department_camera",designationId:"mock-desg-dop",designationName:"director_of_photography_label",designationIdentifier:"designation_director_of_photography_camera",status:"accepted",isAdmin:false,isOwner:false,email:"tomreeves.ztpayrollmodules@zillit.net"),
        AppUser(id:"mock-u-cas",fullName:"Nina Patel",firstName:"Nina",lastName:"Patel",departmentId:"68877f89a6569e29caee0af3",departmentName:"casting_label",departmentIdentifier:"department_casting",designationId:"mock-desg-casting-dir",designationName:"casting_director_label",designationIdentifier:"designation_casting_director_casting",status:"accepted",isAdmin:false,isOwner:false,email:"ninapatel.ztpayrollmodules@zillit.net"),
        AppUser(id:"mock-u-cat",fullName:"Marco Rossi",firstName:"Marco",lastName:"Rossi",departmentId:"68877f89a6569e29caee0b00",departmentName:"catering_label",departmentIdentifier:"department_catering",designationId:"mock-desg-head-chef",designationName:"head_chef_label",designationIdentifier:"designation_head_chef_catering",status:"accepted",isAdmin:false,isOwner:false,email:"marcorossi.ztpayrollmodules@zillit.net"),
        AppUser(id:"mock-u-cat2",fullName:"Sophie Turner",firstName:"Sophie",lastName:"Turner",departmentId:"68877f89a6569e29caee0b00",departmentName:"catering_label",departmentIdentifier:"department_catering",designationId:"mock-desg-catering-mgr",designationName:"catering_manager_label",designationIdentifier:"designation_catering_manager_catering",status:"accepted",isAdmin:false,isOwner:false,email:"sophieturner.ztpayrollmodules@zillit.net"),
        AppUser(id:"mock-u-clr",fullName:"Lucy Brennan",firstName:"Lucy",lastName:"Brennan",departmentId:"68877f89a6569e29caee0b06",departmentName:"clearances_label",departmentIdentifier:"department_clearances",designationId:"mock-desg-clearance",designationName:"clearance_label",designationIdentifier:"designation_clearance_clearances",status:"accepted",isAdmin:false,isOwner:false,email:"lucybrennan.ztpayrollmodules@zillit.net"),
        AppUser(id:"mock-u-cos",fullName:"Claire Winters",firstName:"Claire",lastName:"Winters",departmentId:"68877f89a6569e29caee0b2a",departmentName:"costume_and_wardrobe_department_label",departmentIdentifier:"department_costume_and_wardrobe_department",designationId:"mock-desg-cost-des",designationName:"costume_designer_label",designationIdentifier:"designation_costume_designer_costume_and_wardrobe_department",status:"accepted",isAdmin:false,isOwner:false,email:"clairewinters.ztpayrollmodules@zillit.net"),
        AppUser(id:"mock-u-ele",fullName:"Ian Fletcher",firstName:"Ian",lastName:"Fletcher",departmentId:"68877f89a6569e29caee0e78",departmentName:"electrical_department_label",departmentIdentifier:"department_electrical_department",designationId:"mock-desg-gaffer",designationName:"gaffer_label",designationIdentifier:"designation_gaffer_electrical_department",status:"accepted",isAdmin:false,isOwner:false,email:"ianfletcher.ztpayrollmodules@zillit.net"),
        AppUser(id:"mock-u-loc",fullName:"David Walsh",firstName:"David",lastName:"Walsh",departmentId:"68877f89a6569e29caee0b99",departmentName:"locations_label",departmentIdentifier:"department_locations",designationId:"mock-desg-loc-mgr",designationName:"location_manager_label",designationIdentifier:"designation_location_manager_locations",status:"accepted",isAdmin:false,isOwner:false,email:"davidwalsh.ztpayrollmodules@zillit.net"),
        AppUser(id:"mock-u-muh",fullName:"Amara Okafor",firstName:"Amara",lastName:"Okafor",departmentId:"68877f89a6569e29caee0ba2",departmentName:"make_up_hair_label",departmentIdentifier:"department_make_up_hair",designationId:"mock-desg-muh-des",designationName:"make_up_hair_designer_label",designationIdentifier:"designation_make_up_hair_designer_make_up_hair",status:"accepted",isAdmin:false,isOwner:false,email:"amaraokafor.ztpayrollmodules@zillit.net"),
        AppUser(id:"mock-u-mus",fullName:"Ethan Brooks",firstName:"Ethan",lastName:"Brooks",departmentId:"68877f89a6569e29caee0bbf",departmentName:"music_department_label",departmentIdentifier:"department_music_department",designationId:"mock-desg-music-sup",designationName:"music_supervisor_label",designationIdentifier:"designation_music_supervisor_music_department",status:"accepted",isAdmin:false,isOwner:false,email:"ethanbrooks.ztpayrollmodules@zillit.net"),
        AppUser(id:"mock-u-sfx",fullName:"Jake Holden",firstName:"Jake",lastName:"Holden",departmentId:"68877f89a6569e29caee0c0d",departmentName:"sfx_label",departmentIdentifier:"department_sfx",designationId:"mock-desg-sfx-sup",designationName:"sfx_supervisor_label",designationIdentifier:"designation_sfx_supervisor_sfx",status:"accepted",isAdmin:false,isOwner:false,email:"jakeholden.ztpayrollmodules@zillit.net"),
        AppUser(id:"mock-u-snd",fullName:"Alison Drew",firstName:"Alison",lastName:"Drew",departmentId:"68877f89a6569e29caee0c31",departmentName:"sound_label",departmentIdentifier:"department_sound",designationId:"mock-desg-sound-mixer",designationName:"production_sound_mixer_label",designationIdentifier:"designation_production_sound_mixer_sound",status:"accepted",isAdmin:false,isOwner:false,email:"alisondrew.ztpayrollmodules@zillit.net"),
        AppUser(id:"mock-u-tra",fullName:"Dan Foster",firstName:"Dan",lastName:"Foster",departmentId:"68877f89a6569e29caee0c78",departmentName:"transportation_department_label",departmentIdentifier:"department_transportation_department",designationId:"mock-desg-trans-capt",designationName:"transport_captain_label",designationIdentifier:"designation_transport_captain_transportation_department",status:"accepted",isAdmin:false,isOwner:false,email:"danfoster.ztpayrollmodules@zillit.net"),
        AppUser(id:"mock-u-vfx",fullName:"Yuki Tanaka",firstName:"Yuki",lastName:"Tanaka",departmentId:"68877f89a6569e29caee0ca2",departmentName:"vfx_visual_effects_department_label",departmentIdentifier:"department_vfx_visual_effects_department",designationId:"mock-desg-vfx-sup",designationName:"vfx_supervisor_label",designationIdentifier:"designation_vfx_supervisor_vfx_visual_effects_department",status:"accepted",isAdmin:false,isOwner:false,email:"yukitanaka.ztpayrollmodules@zillit.net"),
        AppUser(id:"mock-u-stu",fullName:"Helen Marsh",firstName:"Helen",lastName:"Marsh",departmentId:"68877f89a6569e29caee0c6a",departmentName:"stunts_department_label",departmentIdentifier:"department_stunts_department",designationId:"mock-desg-stunt-coord",designationName:"stunt_coordinator_label",designationIdentifier:"designation_stunt_coordinator_stunts_department",status:"accepted",isAdmin:false,isOwner:false,email:"helenmarsh.ztpayrollmodules@zillit.net"),
        AppUser(id:"mock-u-grp",fullName:"Neil Grant",firstName:"Neil",lastName:"Grant",departmentId:"68877f89a6569e29caee0b7b",departmentName:"grips_label",departmentIdentifier:"department_grips",designationId:"mock-desg-grips",designationName:"grips_label",designationIdentifier:"designation_grips_grips",status:"accepted",isAdmin:false,isOwner:false,email:"neilgrant.ztpayrollmodules@zillit.net"),
        AppUser(id:"mock-u-prp",fullName:"Aisha Khan",firstName:"Aisha",lastName:"Khan",departmentId:"68877f89a6569e29caee0bd8",departmentName:"props_property_department_label",departmentIdentifier:"department_props_property_department",designationId:"mock-desg-prop-master",designationName:"prop_master_label",designationIdentifier:"designation_prop_master_props_property_department",status:"accepted",isAdmin:false,isOwner:false,email:"aishakhan.ztpayrollmodules@zillit.net"),
        AppUser(id:"mock-u-set",fullName:"Gemma Lewis",firstName:"Gemma",lastName:"Lewis",departmentId:"68877f89a6569e29caee0bfe",departmentName:"set_decorating_department_label",departmentIdentifier:"department_set_decorating_department",designationId:"mock-desg-set-dec",designationName:"set_decorator_label",designationIdentifier:"designation_set_decorator_set_decorating_department",status:"accepted",isAdmin:false,isOwner:false,email:"gemmalewis.ztpayrollmodules@zillit.net"),
        AppUser(id:"mock-u-sec",fullName:"Ray Cooper",firstName:"Ray",lastName:"Cooper",departmentId:"68877f89a6569e29caee0bfc",departmentName:"security_label",departmentIdentifier:"department_security",designationId:"mock-desg-security",designationName:"security_label",designationIdentifier:"designation_security_security",status:"accepted",isAdmin:false,isOwner:false,email:"raycooper.ztpayrollmodules@zillit.net"),
        AppUser(id:"mock-u-edi",fullName:"Naomi West",firstName:"Naomi",lastName:"West",departmentId:"68877f89a6569e29caee0b5a",departmentName:"editorial_department_label",departmentIdentifier:"department_editorial_department",designationId:"mock-desg-editor",designationName:"editors_label",designationIdentifier:"designation_editors_editorial_department",status:"accepted",isAdmin:false,isOwner:false,email:"naomiwest.ztpayrollmodules@zillit.net"),
        AppUser(id:"mock-u-cov",fullName:"Sarah Mitchell",firstName:"Sarah",lastName:"Mitchell",departmentId:"68877f89a6569e29caee0b56",departmentName:"covid_label",departmentIdentifier:"department_covid",designationId:"mock-desg-covid-sup",designationName:"covid_supervisor_label",designationIdentifier:"designation_covid_supervisor_covid",status:"accepted",isAdmin:false,isOwner:false,email:"sarahmitchell.ztpayrollmodules@zillit.net"),
        AppUser(id:"mock-u-con",fullName:"Faye Moran",firstName:"Faye",lastName:"Moran",departmentId:"68877f89a6569e29caee0b23",departmentName:"script_continuity_label",departmentIdentifier:"department_script_continuity",designationId:"mock-desg-script-sup",designationName:"script_supervisor_label",designationIdentifier:"designation_script_supervisor_script_continuity",status:"accepted",isAdmin:false,isOwner:false,email:"fayemoran.ztpayrollmodules@zillit.net"),
        AppUser(id:"mock-u-pub",fullName:"Beatrice Long",firstName:"Beatrice",lastName:"Long",departmentId:"68877f89a6569e29caee0bf0",departmentName:"publicity_label",departmentIdentifier:"department_publicity",designationId:"mock-desg-publicist",designationName:"unit_publicist_label",designationIdentifier:"designation_unit_publicist_publicity",status:"accepted",isAdmin:false,isOwner:false,email:"beatricelong.ztpayrollmodules@zillit.net"),
        AppUser(id:"mock-u-ins",fullName:"Peter Lawson",firstName:"Peter",lastName:"Lawson",departmentId:"68877f89a6569e29caee0b97",departmentName:"insurances_label",departmentIdentifier:"department_insurances",designationId:"mock-desg-insurance",designationName:"insurance_coordinator_label",designationIdentifier:"designation_insurance_coordinator_insurances",status:"accepted",isAdmin:false,isOwner:false,email:"peterlawson.ztpayrollmodules@zillit.net"),
        AppUser(id:"mock-u-fin",fullName:"Robert Hayes",firstName:"Robert",lastName:"Hayes",departmentId:"68877f89a6569e29caee0f05",departmentName:"financier_label",departmentIdentifier:"department_financier",designationId:"mock-desg-financier",designationName:"financier_label",designationIdentifier:"designation_financier_financier",status:"accepted",isAdmin:false,isOwner:false,email:"roberthayes.ztpayrollmodules@zillit.net"),
        AppUser(id:"mock-u-bnd",fullName:"Victoria Clarke",firstName:"Victoria",lastName:"Clarke",departmentId:"68877f89a6569e29caee0f03",departmentName:"bond_representative_label",departmentIdentifier:"department_bond_representative",designationId:"mock-desg-bond-rep",designationName:"bond_representative_label",designationIdentifier:"designation_bond_representative_bond_representative",status:"accepted",isAdmin:false,isOwner:false,email:"victoriaclarke.ztpayrollmodules@zillit.net"),
        AppUser(id:"mock-u-std",fullName:"Andrew Bell",firstName:"Andrew",lastName:"Bell",departmentId:"68877f89a6569e29caee0f01",departmentName:"studio_label",departmentIdentifier:"department_studio",designationId:"mock-desg-studio",designationName:"studio_representative_label",designationIdentifier:"designation_studio_representative_studio",status:"accepted",isAdmin:false,isOwner:false,email:"andrewbell.ztpayrollmodules@zillit.net"),
        AppUser(id:"mock-u-cst",fullName:"Megan Taylor",firstName:"Megan",lastName:"Taylor",departmentId:"68877f89a6569e29caee0ef9",departmentName:"cast_talent_label",departmentIdentifier:"department_cast_talent",designationId:"mock-desg-cast",designationName:"cast_talent_label",designationIdentifier:"designation_cast_talent_cast_talent",status:"accepted",isAdmin:false,isOwner:false,email:"megantaylor.ztpayrollmodules@zillit.net"),
        AppUser(id:"mock-u-ani",fullName:"Kenji Nakamura",firstName:"Kenji",lastName:"Nakamura",departmentId:"68877f89a6569e29caee0e9d",departmentName:"animation_department_label",departmentIdentifier:"department_animation_department",designationId:"mock-desg-lead-anim",designationName:"lead_animator_label",designationIdentifier:"designation_lead_animator_animation_department",status:"accepted",isAdmin:false,isOwner:false,email:"kenjinakamura.ztpayrollmodules@zillit.net"),
        AppUser(id:"mock-u-dai",fullName:"Rebecca Stone",firstName:"Rebecca",lastName:"Stone",departmentId:"68877f89a6569e29caee0e76",departmentName:"dailies_label",departmentIdentifier:"department_dailies",designationId:"mock-desg-dailies",designationName:"dailies_operator_label",designationIdentifier:"designation_dailies_operator_dailies",status:"accepted",isAdmin:false,isOwner:false,email:"rebeccastone.ztpayrollmodules@zillit.net"),
        AppUser(id:"mock-u-add",fullName:"Charlotte Osei",firstName:"Charlotte",lastName:"Osei",departmentId:"68877f89a6569e29caee0ea4",departmentName:"additional_crew_label",departmentIdentifier:"department_additional_crew",designationId:"mock-desg-add-crew",designationName:"assistant_production_coordinator_label",designationIdentifier:"designation_assistant_production_coordinator_additional_crew",status:"accepted",isAdmin:false,isOwner:false,email:"charlotteosei.ztpayrollmodules@zillit.net"),
        AppUser(id:"mock-u-rig",fullName:"Sean Murphy",firstName:"Sean",lastName:"Murphy",departmentId:"68877f89a6569e29caee0bf6",departmentName:"riggers_electrical_rigging_label",departmentIdentifier:"department_riggers_electrical_rigging",designationId:"mock-desg-rig-gaffer",designationName:"rigging_gaffer_label",designationIdentifier:"designation_rigging_gaffer_riggers_electrical_rigging",status:"accepted",isAdmin:false,isOwner:false,email:"seanmurphy.ztpayrollmodules@zillit.net"),
        AppUser(id:"mock-u-mhs",fullName:"Greg Palmer",firstName:"Greg",lastName:"Palmer",departmentId:"68877f89a6569e29caee0b8f",departmentName:"medics_health_safety_label",departmentIdentifier:"department_medics_health_safety",designationId:"mock-desg-hs-advisor",designationName:"health_safety_advisor_label",designationIdentifier:"designation_health_safety_advisor_medics_health_safety",status:"accepted",isAdmin:false,isOwner:false,email:"gregpalmer.ztpayrollmodules@zillit.net"),
        AppUser(id:"mock-u-epk",fullName:"Ryan Hughes",firstName:"Ryan",lastName:"Hughes",departmentId:"68877f89a6569e29caee0b79",departmentName:"epk_label",departmentIdentifier:"department_epk",designationId:"mock-desg-epk-prod",designationName:"epk_producer_label",designationIdentifier:"designation_epk_producer_epk",status:"accepted",isAdmin:false,isOwner:false,email:"ryanhughes.ztpayrollmodules@zillit.net"),
        AppUser(id:"mock-u-comp",fullName:"Liam Doyle",firstName:"Liam",lastName:"Doyle",departmentId:"68877f89a6569e29caee0b28",departmentName:"composer_label",departmentIdentifier:"department_composer",designationId:"mock-desg-composer",designationName:"composer_label",designationIdentifier:"designation_composer_composer",status:"accepted",isAdmin:false,isOwner:false,email:"liamdoyle.ztpayrollmodules@zillit.net"),
        AppUser(id:"mock-u-osr",fullName:"Linda Parsons",firstName:"Linda",lastName:"Parsons",departmentId:"68877f89a6569e29caee0bd5",departmentName:"on_set_readers_label",departmentIdentifier:"department_on_set_readers",designationId:"mock-desg-on-set-reader",designationName:"on_set_reader_label",designationIdentifier:"designation_on_set_reader_on_set_readers",status:"accepted",isAdmin:false,isOwner:false,email:"lindaparsons.ztpayrollmodules@zillit.net"),
        AppUser(id:"mock-u-spe",fullName:"Carl Vickers",firstName:"Carl",lastName:"Vickers",departmentId:"68877f89a6569e29caee0c60",departmentName:"special_effects_department_label",departmentIdentifier:"department_special_effects_department",designationId:"mock-desg-spe-sup",designationName:"special_effects_supervisor_label",designationIdentifier:"designation_special_effects_supervisor_special_effects_department",status:"accepted",isAdmin:false,isOwner:false,email:"carlvickers.ztpayrollmodules@zillit.net"),
        AppUser(id:"mock-u-sby",fullName:"Karen Frost",firstName:"Karen",lastName:"Frost",departmentId:"68877f89a6569e29caee0c62",departmentName:"stand_by_department_label",departmentIdentifier:"department_stand_by_department",designationId:"mock-desg-standby",designationName:"stand_by_label",designationIdentifier:"designation_stand_by_stand_by_department",status:"accepted",isAdmin:false,isOwner:false,email:"karenfrost.ztpayrollmodules@zillit.net"),
        AppUser(id:"mock-u-sti",fullName:"Alex Turner",firstName:"Alex",lastName:"Turner",departmentId:"68877f89a6569e29caee0c66",departmentName:"stand_ins_label",departmentIdentifier:"department_stand_ins",designationId:"mock-desg-stand-in",designationName:"stand_in_label",designationIdentifier:"designation_stand_in_stand_ins",status:"accepted",isAdmin:false,isOwner:false,email:"alexturner.ztpayrollmodules@zillit.net"),
        AppUser(id:"mock-u-stp",fullName:"James Okafor",firstName:"James",lastName:"Okafor",departmentId:"68877f89a6569e29caee0c68",departmentName:"stills_photographer_label",departmentIdentifier:"department_stills_photographer",designationId:"mock-desg-stills",designationName:"stills_photographer_label",designationIdentifier:"designation_stills_photographer_stills_photographer",status:"accepted",isAdmin:false,isOwner:false,email:"jamesokafor.ztpayrollmodules@zillit.net"),
        AppUser(id:"mock-u-vid",fullName:"Owen Richards",firstName:"Owen",lastName:"Richards",departmentId:"68877f89a6569e29caee0c96",departmentName:"video_label",departmentIdentifier:"department_video",designationId:"mock-desg-video",designationName:"video_playback_label",designationIdentifier:"designation_video_playback_video",status:"accepted",isAdmin:false,isOwner:false,email:"owenrichards.ztpayrollmodules@zillit.net"),
    ]

    static let allUsers: [AppUser] = accountsTeam + departmentUsers
    static let byId: [String: AppUser] = Dictionary(uniqueKeysWithValues: allUsers.compactMap { u -> (String, AppUser)? in
        guard let id = u.id else { return nil }
        return (id, u)
    })
}

// MARK: - Departments (all unique from users)

struct DepartmentsData {
    static let all: [Department] = {
        var seen = Set<String>()
        return UsersData.allUsers.compactMap { u -> Department? in
            guard let deptId = u.departmentId, !seen.contains(deptId) else { return nil }
            seen.insert(deptId)
            return Department(id: deptId, projectId: ProjectData.projectId,
                              departmentName: u.departmentName, identifier: u.departmentIdentifier, systemDefined: true)
        }
    }()
    static let sorted: [Department] = all.sorted { $0.displayName < $1.displayName }
}

let poQuickTemplates: [(id: String, icon: String, color: String, name: String, extras: [String])] = [
    ("studio","house.fill","blue","Studio / Location Hire",["Accrual-ready","Multi-week"]),
    ("crew","person.fill","purple","Crew Contract",["CIS auto-tag","Holiday accrual"]),
    ("equip","camera.fill","teal","Equipment Rental",["Rental splits","Cross-hire"]),
    ("consumables","cart.fill","orange","Consumables & Supplies",["Single line"]),
]
