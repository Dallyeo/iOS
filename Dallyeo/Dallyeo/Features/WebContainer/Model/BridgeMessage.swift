//
//  BridgeMessage.swift
//  Dallyeo
//
//  브릿지 메시지 구조
//

import Foundation

// MARK: - Web → Native 메시지
// 규격: { "id": "req_1", "method": "login", "params": { ... } }
// 단방향(응답 불필요)은 id 없음: { "method": "openCourseSearch", "params": {} }

struct BridgeMessage: Codable, Sendable {
    let method: String
    let id: String?       // 없으면 단방향 (응답 불필요)
    let params: [String: AnyCodableValue]?
}

// MARK: - Native → Web 응답
// window.__dallyeoBridgeResolve({ id, ok, data }) / { id, ok: false, error: { kind } }

struct BridgeResponse: Codable, Sendable {
    let id: String
    let ok: Bool
    let data: AnyCodableValue?
    let error: BridgeErrorPayload?

    static func success(id: String, data: AnyCodableValue? = nil) -> BridgeResponse {
        BridgeResponse(id: id, ok: true, data: data, error: nil)
    }

    static func failure(id: String, error: BridgeErrorPayload) -> BridgeResponse {
        BridgeResponse(id: id, ok: false, data: nil, error: error)
    }
}

// MARK: - 브릿지 에러
// { kind: "cancelled" } 형식 (FE 명세 기준)

struct BridgeErrorPayload: Codable, Sendable {
    let kind: String

    static let cancelled     = BridgeErrorPayload(kind: "cancelled")
    static let unknownMethod = BridgeErrorPayload(kind: "unknown_method")
    static let invalidParams = BridgeErrorPayload(kind: "invalid_params")
    static let notImplemented = BridgeErrorPayload(kind: "not_implemented")
    static let permissionDenied = BridgeErrorPayload(kind: "permission_denied")
    static func custom(_ kind: String) -> BridgeErrorPayload { BridgeErrorPayload(kind: kind) }
}

// MARK: - 브릿지 메서드 (현재 명세 기준)

enum BridgeMethod: String, CaseIterable, Sendable {
    // 응답 필요
    case login
    case logout
    case getCurrentSession
    case requestPermission
    case getPermissionStatus
    // 단방향
    case openCourseSearch
    case openCourseConfirm
    // 향후 예약 (지금 호출 안 함)
    // case startRun
    // case openOSSettings
    // case pickProfilePhoto
    // case share
    // case openExternalUrl
}

// MARK: - AnyCodableValue (JSON 타입 래퍼)

enum AnyCodableValue: Codable, Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([AnyCodableValue])
    case dictionary([String: AnyCodableValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let int = try? container.decode(Int.self) {
            self = .int(int)
        } else if let double = try? container.decode(Double.self) {
            self = .double(double)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([AnyCodableValue].self) {
            self = .array(array)
        } else if let dictionary = try? container.decode([String: AnyCodableValue].self) {
            self = .dictionary(dictionary)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "지원하지 않는 타입입니다.")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .string(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .dictionary(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }

    // MARK: - Value Accessors

    var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    var intValue: Int? {
        if case .int(let value) = self { return value }
        return nil
    }

    var boolValue: Bool? {
        if case .bool(let value) = self { return value }
        return nil
    }
}
