//
//  AccountHubShims.swift
//  ZillitPO
//
//  Shim layer so the AccountHub module reads byte-for-byte the same as in
//  the live Zillit project. Each symbol below has a real implementation in
//  the live app (Util, appUserDefault, LoginUserData, FCURLRequest, etc.).
//  Delete this file when copying the AccountHub folder into live.
//

import Foundation
import SwiftUI

// MARK: - LoginUserData (live: real model bridging Firebase auth + Realm)

typealias LoginUserData = AppUser

extension AppUser {
    /// Live exposes the user id through `userID`. Mirror it here so call
    /// sites compile unchanged.
    var userID: String? { id }
}

// MARK: - Util.getLoginUserID() (live: reads keychain-backed user id)

enum Util {
    static func getLoginUserID() -> String {
        // Demo default mirrors the previous hardcoded `mock-u-cat2` (Sophie Turner)
        UserDefaults.standard.string(forKey: "demo-active-user-id") ?? "mock-u-cat2"
    }
    static func setLoginUserID(_ id: String) {
        UserDefaults.standard.set(id, forKey: "demo-active-user-id")
    }
}

// MARK: - appUserDefault.getLoginUserData() (live: Realm-backed)

enum appUserDefault {
    static func getLoginUserData() -> LoginUserData? {
        UsersData.byId[Util.getLoginUserID()]
    }
}

// MARK: - ServerRequest
//
// Moved out of this shim into its own file — `Network/ServerRequest.swift`.
// That file mirrors live's `RequestConstraint.swift` structure (env-aware
// schema switch + per-microservice constants) and exposes `DEMO_BASE_HOST`
// as the single line to edit when pointing the demo at a different backend.

// MARK: - FCURLRequest (live: shared URLRequest builder with auth headers)

/// HTTP method shim. Live's `FCURLRequest.RequestType` exposes the same
/// raw values.
enum FCRequestType {
    case get, post, patch, put, delete
    var httpMethod: String {
        switch self {
        case .get: return "GET"
        case .post: return "POST"
        case .patch: return "PATCH"
        case .put: return "PUT"
        case .delete: return "DELETE"
        }
    }
}

/// Builds the same shape of `URLRequest` the live `FCURLRequest` does so
/// the per-domain Request enums can be copy-pasted from live unchanged.
/// Internally calls `APIClient.shared.buildRequest(...)` so the demo's
/// existing networking (headers, base URL) keeps working.
struct FCURLRequest {
    var urlPath: String
    var type: FCRequestType
    var body: Any?

    init(urlPath: String, type: FCRequestType, body: Any? = nil) {
        self.urlPath = urlPath
        self.type = type
        self.body = body
    }

    /// `requestObject` mirrors live's `FCURLRequest.requestObject` — a
    /// fully-built `URLRequest` (or nil if URL construction failed).
    var requestObject: URLRequest? {
        let method: HTTPMethodType
        switch type {
        case .get: method = .get
        case .post: method = .post
        case .patch: method = .patch
        case .put: method = .put
        case .delete: method = .delete
        }
        // Strip the demo's `baseURL` prefix so APIClient can re-prepend it
        // (live uses absolute URLs because each microservice has its own host).
        let endpoint: String
        if urlPath.hasPrefix(APIClient.shared.baseURL) {
            endpoint = String(urlPath.dropFirst(APIClient.shared.baseURL.count))
        } else {
            endpoint = urlPath
        }
        if let data = body as? Data {
            return APIClient.shared.buildRequestRaw(method, endpoint, bodyData: data)
        } else if let dict = body as? [String: Any] {
            return APIClient.shared.buildRequest(method, endpoint, body: dict)
        } else {
            return APIClient.shared.buildRequest(method, endpoint)
        }
    }
}

/// Live exposes a marker protocol per microservice. The demo already
/// declares `POURLRequestProtocol` in APIClient.swift; we alias it here
/// under the live name so per-domain Request enums copied from live
/// (`extension XxxRequest: FCURLRequestProtocol`) compile unchanged.
typealias FCURLRequestProtocol = POURLRequestProtocol

/// Live's CodableTask marker protocol (provides `urlDataTask`). The
/// demo's own `PODataTaskProtocol` is the same shape.
typealias FCCodableDataTask = PODataTaskProtocol

/// Live's typed response envelope (`ZLGenericResponse<T> { data: T? }`).
/// Demo's `APIResponse<T>` has the same shape so we just alias.
typealias ZLGenericResponse = APIResponse

// MARK: - FCURLSession (live: shared URLSession wrapper)
//
// Live calls `FCURLSession.sharedInstance.session?.codableResultTask(...)`.
// Demo's `codableResultTask` is an instance method on APIClient, so we
// expose APIClient.shared under the same `session` accessor and the
// live call shape works unchanged.

final class FCURLSession {
    static let sharedInstance = FCURLSession()
    let session: APIClient? = APIClient.shared
}

// MARK: - FCCustomError (live: typed networking error)

struct FCCustomError: Error {
    var message: String?
    var statusCode: Int?

    init(message: String? = nil, statusCode: Int? = nil) {
        self.message = message
        self.statusCode = statusCode
    }
}

// MARK: - Firebase / Badge shims (live: FirebaseRTDB.shared)

enum ToolType {
    case po, accountHub, cardExpenses, cashExpenses, invoices
}

/// Noop stand-in for the live Firebase realtime-DB helper that drives
/// unread-badge counters. The demo doesn't observe Firebase, so every
/// method is a no-op but the shape matches live verbatim.
final class FirebaseRTDB {
    static let shared = FirebaseRTDB()
    let refInstance = RefInstance()

    final class RefInstance {
        func readToolMessage(_ unit: String, action: ToolType, level1: String, level2: String, level3: String) {}
    }
}

/// Live: a Realm-backed model for a single unread notification. Badge
/// VMs filter these by `level_3 == entityId` to surface per-row dots.
/// Demo has no notification pipeline so this is just a struct shape.
struct LocalNotificationModel {
    var tool: String?
    var unit: String?
    var level_1: String?
    var level_2: String?
    var level_3: String?
    var action: String?
}

/// Tiny pill that displays an unread count. Live ships a richer version;
/// the demo only needs the public API.
struct SwiftBadgeView: View {
    let badgeCount: Int
    var body: some View {
        Text("\(badgeCount)")
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Capsule().fill(Color.red))
    }
}

// MARK: - UIColor.appPrimaryColor (live: brand colour helper)

extension UIColor {
    static var appPrimaryColor: UIColor {
        UIColor(red: 252.0/255.0, green: 148.0/255.0, blue: 4.0/255.0, alpha: 1.0)
    }
}

// MARK: - Model shims used by live network layer
//
// Live ships these as full models; the demo only needs the shape so the
// network enums + codable tasks compile. Replace with live's real models
// on copy-paste.

/// Live: `Network/AccountHub/...` returns a list of bank accounts. Demo
/// doesn't surface a bank-accounts list view yet, so this is a minimal
/// stub matching live's field names.
struct HubBankAccount: Codable, Identifiable, Equatable {
    var id: String?
    var name: String?
    var accountType: String?
    var bankName: String?
    var accountNumber: String?
    var sortCode: String?
    var currency: String?
    var isDefault: Bool?
    var active: Bool?

    enum CodingKeys: String, CodingKey {
        case id, name, currency, active
        case accountType   = "account_type"
        case bankName      = "bank_name"
        case accountNumber = "account_number"
        case sortCode      = "sort_code"
        case isDefault     = "is_default"
    }
}

/// Live: response body of `POST /purchase-orders/{id}/pdf`. The demo's
/// existing `generatePDF` flow decodes a `{ url }` payload; this struct
/// is shaped the same.
struct POPdfViewer: Codable {
    var url: String?
    var pdf: String?

    enum CodingKeys: String, CodingKey { case url, pdf }
}

/// Live: response body of `GET /invoices/settings`. Demo aliases this to
/// the existing `InvoiceSettingsRaw` so call sites that read
/// `response.data.alerts` keep working.
typealias InvoiceSettings = InvoiceSettingsRaw

// MARK: - Vendor — bank-related convenience shim
//
// Live's Vendor exposes flat bank fields (bankName / accountNumber / …),
// a `bankId`, and a computed `hasBankData`. The demo's Vendor model
// doesn't yet have those columns wired up, so these are mutable
// storage-less stubs that satisfy live's call sites. They use the
// objc_setAssociatedObject pattern only so the demo Vendor (a value
// type) stays unchanged; in live these are real stored properties.
//
// In practice the demo never persists bank data, so `hasBankData` reads
// false everywhere and the live merging logic just always copies
// incoming data — which is the desired behaviour for demo.

extension Vendor {
    var bankAccount: HubBankAccount? { get { nil } set { _ = newValue } }
    var bankId: String?              { get { nil } set { _ = newValue } }
    var bankName: String?            { get { nil } set { _ = newValue } }
    var accountHolderName: String?   { get { nil } set { _ = newValue } }
    var accountNumber: String?       { get { nil } set { _ = newValue } }
    var sortCode: String?            { get { nil } set { _ = newValue } }
    var ibanCode: String?            { get { nil } set { _ = newValue } }
    var swiftCode: String?           { get { nil } set { _ = newValue } }
    var vendorAddress: String        { get { "" } set { _ = newValue } }
    /// Always false in demo — live records bank-fetch state via these
    /// fields so the list refresh doesn't wipe data the detail page
    /// loaded. Demo has no per-vendor detail fetch yet, so the field
    /// is unused.
    var hasBankData: Bool { false }
}

// MARK: - DocumentModel (live: S3 attachment payload)
//
// Demo uploads via multipart and the server stores files locally, so the
// `media / region / bucket` fields are unused. Keeping the type with the
// same shape means every live struct that references `DocumentModel` —
// `CardReceiptCreateRequest`, `Invoice.attachments`, `Claim.attachment` —
// compiles unchanged. The demo populates only `name`, `contentType`,
// `contentSubType` (set from the multipart response).

struct DocumentModel: Codable, Equatable, Hashable {
    var id: String?
    /// File name (display + extension). Demo sets this from the
    /// multipart-upload response's `original_name` or `filename`.
    var name: String?
    var contentType: String?
    var contentSubType: String?
    /// S3 fields (unused by demo, populated by live).
    var media: String?
    var region: String?
    var bucket: String?
    /// Demo-only: server-stored path returned by the multipart endpoint.
    /// Used by `InvoiceDetailPage` etc. to build the preview URL via
    /// `\(base)/uploads/\(filename)`.
    var serverPath: String?

    enum CodingKeys: String, CodingKey {
        case id, media, region, bucket
        case name           = "name"
        case contentType    = "content_type"
        case contentSubType = "content_subtype"
        case serverPath     = "server_path"
    }
}

// MARK: - SwiftUIUtils.uploadAttachmentModel (live: S3 uploader → DocumentModel)
//
// The live helper uploads `data` to S3 and returns a `DocumentModel` with
// media/region/bucket populated. The demo posts multipart form-data to
// `/api/v2/upload` (re-using the existing invoice/receipt multipart
// pipeline) and converts the response into the same `DocumentModel`
// shape. Same call site, different transport.

enum SwiftUIUtils {
    /// Upload a file and return a `DocumentModel`. Demo path: multipart
    /// to the demo backend, then map the response → DocumentModel.
    static func uploadAttachmentModel(
        item: (baseName: String, ext: String, data: Data),
        completion: @escaping (DocumentModel?) -> Void
    ) {
        let fileName = "\(item.baseName).\(item.ext)"
        let mime = mimeType(for: item.ext)
        // Demo uses the invoices upload endpoint (it accepts any file
        // type) — the response shape is the same `{ file_name, path, … }`
        // dictionary used elsewhere.
        guard let req = APIClient.shared.buildMultipartRequest(
            "/api/v2/invoices/upload",
            fileData: item.data,
            fileName: fileName,
            mimeType: mime,
            fieldName: "file"
        ) else { completion(nil); return }

        APIClient.shared.session.dataTask(with: req) { data, _, _ in
            guard let data = data,
                  let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            let inner = (json["data"] as? [String: Any]) ?? json
            let path = (inner["path"] as? String) ?? (inner["file_path"] as? String)
            let serverName = (inner["file_name"] as? String)
                ?? (inner["original_name"] as? String)
                ?? (inner["filename"] as? String)
                ?? fileName
            let doc = DocumentModel(
                id: inner["id"] as? String ?? inner["upload_id"] as? String,
                name: serverName,
                contentType: mime.components(separatedBy: "/").first,
                contentSubType: mime.components(separatedBy: "/").last,
                serverPath: path
            )
            DispatchQueue.main.async { completion(doc) }
        }.resume()
    }

    private static func mimeType(for ext: String) -> String {
        switch ext.lowercased() {
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "pdf": return "application/pdf"
        case "heic": return "image/heic"
        default: return "application/octet-stream"
        }
    }
}
