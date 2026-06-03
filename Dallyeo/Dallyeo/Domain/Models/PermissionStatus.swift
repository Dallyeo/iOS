//
//  PermissionStatus.swift
//  Dallyeo
//
//  권한 상태 모델 - 브릿지 통신용
//

import Foundation

struct PermissionStatus: Codable, Sendable {
    let type: PermissionType
    let status: AuthorizationStatus
}

enum PermissionType: String, Codable, Sendable {
    case location
    case notification
    case camera
    case photoLibrary
}

enum AuthorizationStatus: String, Codable, Sendable {
    case notDetermined
    case restricted
    case denied
    case authorized
    case authorizedWhenInUse
    case authorizedAlways
}
