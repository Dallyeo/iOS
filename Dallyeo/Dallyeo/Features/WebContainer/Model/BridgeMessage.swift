//
//  BridgeMessage.swift
//  Dallyeo
//
//  브릿지 메시지 구조
//

import Foundation

// MARK: - Web → Native 메시지

struct BridgeMessage: Codable, Sendable {
    let action: String
    let requestId: String
    let payload: [String: AnyCodableValue]?
}

// MARK: - Native → Web 응답

struct BridgeResponse: Codable, Sendable {
    let requestId: String
    let success: Bool
    let data: AnyCodableValue?
    let error: BridgeError?

    static func success(requestId: String, data: AnyCodableValue? = nil) -> BridgeResponse {
        BridgeResponse(requestId: requestId, success: true, data: data, error: nil)
    }

    static func failure(requestId: String, error: BridgeError) -> BridgeResponse {
        BridgeResponse(requestId: requestId, success: false, data: nil, error: error)
    }
}

// MARK: - 브릿지 에러

struct BridgeError: Codable, Sendable {
    let code: String
    let message: String

    static let unknownAction = BridgeError(code: "UNKNOWN_ACTION", message: "알 수 없는 액션입니다.")
    static let invalidPayload = BridgeError(code: "INVALID_PAYLOAD", message: "잘못된 페이로드입니다.")
    static let permissionDenied = BridgeError(code: "PERMISSION_DENIED", message: "권한이 거부되었습니다.")
    static let notImplemented = BridgeError(code: "NOT_IMPLEMENTED", message: "아직 구현되지 않았습니다.")
}

// MARK: - 브릿지 액션

enum BridgeAction: String, CaseIterable, Sendable {
    case login
    case logout
    case openCourseSearch
    case openCourseConfirm
    case startRun
    case getPermissionStatus
    case requestPermission
    case openOSSettings
    case pickProfilePhoto
    case share
    case openExternalUrl
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
