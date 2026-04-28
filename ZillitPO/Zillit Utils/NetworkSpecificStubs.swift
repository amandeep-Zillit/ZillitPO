//
//  NetworkSpecificStubs.swift
//  ZillitPO
//
//  Dummy stand-ins for parent-Zillit dependencies referenced by
//  `NetworkSpecific.swift`. Every method here returns inert data so the
//  file compiles inside ZillitPO's standalone target. At integration
//  time, delete this file — the real `Util`, `Translator`, `CONSTANTS`,
//  `appUserDefault`, etc. from the parent project take over.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Util

/// Stub of `Util` — provides the device / app metadata that
/// `FCURLRequest` injects into outbound headers. Returns empty
/// strings so requests still build.
enum Util {
    static func deviceId() -> String { "stub-device-id" }
    static func getAppVersion() -> String { "1.0.0" }
    static func getDeviceInfo() -> String { "stub-device-info" }
    static func getCurrentDeviceType() -> String { "ios" }
    static func getDeviceName() -> String { "stub-device-name" }
    static func getDeviceType() -> String { "ios" }
    static func generateSHA256WithSalt(requestBody: String) -> String { "" }
    static func getBoxFileID(_ media: String) -> String? { nil }
    static func logOutUser() { /* no-op */ }
    static func redirectAllProjectScreen() { /* no-op */ }
}

// MARK: - SocketIOManager

/// Stub of `SocketIOManager` — the parent project encrypts header
/// payloads here. The stub passes the input through unchanged so
/// requests are still well-formed JSON.
final class SocketIOManager {
    static let `default_` = SocketIOManager()
    private init() {}
    func getEncryptedHeaderText(string: String) -> String { string }
    func getDecriptionheaderText(string: String) -> String { string }
}

// MARK: - Translator

/// Stub of `Translator` — returns the key as-is so any string flowing
/// through the translator path is preserved.
final class Translator {
    static let shared = Translator()
    private init() {}
    func translate(key: String) -> String { key }
}

// MARK: - CONSTANTS

/// Stub of `CONSTANTS`. Only the symbols touched by `NetworkSpecific.swift`
/// are defined here.
enum CONSTANTS {
    static let SERVER_400_ERROR = "Bad request"
    static let SERVER_401_ERROR = "Unauthorized"
    static let SERVER_403_ERROR = "Forbidden"
    static let SERVER_404_ERROR = "Not found"
    static let SERVER_406_ERROR = "Not acceptable"
    static let SERVER_500_ERROR = "Internal server error"
    static let SERVER_502_ERROR = "Bad gateway"
    static let ChatGPTURL = ""
}

// MARK: - LOCSTRINGS

/// Stub of `LOCSTRINGS` — only the keys touched here.
enum LOCSTRINGS {
    static let InternetConnectionPopUp = "No internet connection"
}

// MARK: - String helpers (parent project provides these as extensions)

extension String {
    /// Stub of `.localized()` — the parent project routes this through
    /// the localization table. Here it returns the receiver unchanged.
    func localized() -> String { self }

    /// Stub of `.trunc(_:)` — used only for debug logging in
    /// `NetworkSpecific.swift`. Returns the first `length` characters.
    func trunc(_ length: Int) -> String {
        count > length ? String(prefix(length)) + "…" : self
    }
}

// MARK: - Reachability

/// Stub of `Reachability.getNetworkType()`.
enum Reachability {
    static func getNetworkType() -> String { "wifi" }
}

// MARK: - GenericNetworkResponse

/// Stub of `GenericNetworkResponse` (defined in the parent project's
/// `NetworkRequest/GenericNetworkResponse.swift`). Only the fields
/// `NetworkSpecific.swift` reads (`message`, `messageElements`) are kept.
struct GenericNetworkResponse: Codable {
    let message: String?
    let messageElements: [MessageElementsArray]?
}

// MARK: - appUserDefault

/// Subset of the parent project's `AppOpenScreen` enum — only the cases
/// that `NetworkSpecific.swift` compares against.
enum AppOpenScreen {
    case registartion   // sic — typo preserved from the parent project
    case intro
    case allProjects
}

/// Subset of `LoginUserData` exposing only the fields read here.
struct LoginUserDataStub {
    let userID: String?
    let projectID: String?
}

/// Subset of dynamic-region payload — only the AWS bucket / region.
struct DynamicRegionDataStub {
    let upload_bucket: String?
    let aws_region: String?
}

/// Subset of project metadata — only the Box enterprise client id.
struct ProjectDataStub {
    let enterpriseClientId: String?
}

/// Stub of `appUserDefault` (the global user-defaults singleton in the
/// parent project). All accessors return nil / `.allProjects` so the
/// guard branches in `NetworkSpecific.swift` short-circuit safely.
final class AppUserDefaultStub {
    func getAppOpenScreen() -> AppOpenScreen { .allProjects }
    func getLoginUserData() -> LoginUserDataStub? { nil }
    func getDynamicRegionData() -> DynamicRegionDataStub? { nil }
    func getProjectData() -> ProjectDataStub? { nil }
}

/// Global singleton matching the parent project's `appUserDefault`
/// (lowercase, no `shared`). `NetworkSpecific.swift` references this name
/// directly.
let appUserDefault = AppUserDefaultStub()

// MARK: - AnalyticsManager

/// Stub of `AnalyticsManager` — the parent project ships success/failure
/// telemetry to Firebase here. The stub is a no-op.
enum AnalyticsManager {
    static func logApiFailure(request: URLRequest,
                              httpResponse: HTTPURLResponse?,
                              error: Error?,
                              translatedMessage: String?) { /* no-op */ }

    static func logApiSuccess(request: URLRequest,
                              error: Error?,
                              translatedMessage: String?) { /* no-op */ }
}

// MARK: - ServerRequest

/// Stub of `ServerRequest` — only the namespace constants
/// `NetworkSpecific.swift` reads.
enum ServerRequest {
    static let IF_DEBUG: Bool = false
    static let MEDIA_Base_URL: String = ""
}

// MARK: - InternetConnectionManager

/// Stub of `InternetConnectionManager`. Returns `true` so the offline
/// cache fallback path is skipped.
enum InternetConnectionManager {
    static func isConnectedToNetwork() -> Bool { true }
}

// MARK: - S3FileUploadMangerConfig

/// Stub of `S3FileUploadMangerConfig` — only the `storageSource` enum
/// is touched.
final class S3FileUploadMangerConfig {
    enum StorageSource {
        case box(String, String)   // (clientId, fileId) — values not inspected here
        case s3
    }

    static let shared = S3FileUploadMangerConfig()
    private init() {}

    var storageSource: StorageSource = .s3
}
