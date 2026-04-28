//
//  RegistrationModel.swift
//  ZillitPO
//
//  Stripped-down port of `Zillit/Controller/Auth/Model/RegistrationModel.swift`
//  from the parent Zillit project. Only the response-envelope type
//  `ZLGenericResponse<T>` is portable into ZillitPO without pulling in
//  Translator / Util / Realm / Firebase / AWS dependencies. The full file
//  can replace this stub at integration time.
//

import Foundation

// MARK: - Message elements (used by ZLGenericResponse on errors)

/// Stub of the parent project's `MessageElementsArray` (defined in
/// `NetworkRequest/GenericNetworkResponse.swift`). Mirrors the reference
/// signature — `search` / `replacer` are `Any?` with a custom decoder
/// that pulls them out as `String` when available. This shape is what
/// `NetworkSpecific.swift` expects, so the `as? String` cast in
/// `convertSearchReplacer` is meaningful (not a redundant downcast).
public struct MessageElementsArray: Codable {
    let search: Any?
    let replacer: Any?

    enum CodingKeys: String, CodingKey {
        case search
        case replacer
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // The server may send these as String, Int, or Bool. ZillitPO
        // only ever reads them as String, so we attempt that and fall
        // through to nil otherwise.
        search   = try? c.decodeIfPresent(String.self, forKey: .search)
        replacer = try? c.decodeIfPresent(String.self, forKey: .replacer)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(search as? String, forKey: .search)
        try c.encodeIfPresent(replacer as? String, forKey: .replacer)
    }
}

// MARK: - ZLGenericResponse

/// Generic response envelope used across the Zillit API.
/// Mirrors the parent project's `ZLGenericResponse<T>` shape.
///
/// ZillitPO intentionally constrains `T` to `Decodable` (parent uses
/// `Codable`) because all uses in this app are decode-only. When merging
/// into the parent project, this file is replaced by the full
/// `RegistrationModel.swift` and the constraint widens automatically.
public struct ZLGenericResponse<T: Codable>: Codable {
    var message: String?
    var data: T?
    var status: Int?
    var messageElements: [MessageElementsArray]?

    enum CodingKeys: String, CodingKey {
        case message
        case data
        case status
        case messageElements
    }
}

