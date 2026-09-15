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

/// 웹이 물어볼 수 있는 권한.
///
/// 계약서(BRIDGE.md §2)상 `location` / `notification` 둘뿐이다.
/// 카메라·사진 라이브러리는 프로필 사진 기능이 생기면 그때 추가한다 —
/// 쓰지도 않으면서 Info.plist에 사용 목적을 선언해 두면 심사에서 지적받고,
/// 선언 없이 요청하면 크래시한다.
enum PermissionType: String, Codable, Sendable {
    case location
    case notification
}

enum AuthorizationStatus: String, Codable, Sendable {
    case notDetermined
    case restricted
    case denied
    case authorized
    case authorizedWhenInUse
    case authorizedAlways
}
