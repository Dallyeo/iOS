//
//  PermissionHandler.swift
//  Dallyeo
//
//  권한 처리 핸들러
//

import Foundation
import CoreLocation
import AVFoundation
import Photos
import UserNotifications

@MainActor
final class PermissionHandler {

    private let locationManager = CLLocationManager()

    // MARK: - Get Permission Status

    func getPermissionStatus(type: PermissionType) -> PermissionStatus {
        let status: AuthorizationStatus

        switch type {
        case .location:
            status = mapLocationStatus(locationManager.authorizationStatus)
        case .camera:
            status = mapAVStatus(AVCaptureDevice.authorizationStatus(for: .video))
        case .photoLibrary:
            status = mapPhotoStatus(PHPhotoLibrary.authorizationStatus(for: .readWrite))
        case .notification:
            // 동기적으로 상태를 반환할 수 없으므로 notDetermined 반환
            // 실제 상태는 requestPermission에서 확인
            status = .notDetermined
        }

        return PermissionStatus(type: type, status: status)
    }

    // MARK: - Request Permission

    func requestPermission(type: PermissionType) async -> PermissionStatus {
        let status: AuthorizationStatus

        switch type {
        case .location:
            locationManager.requestWhenInUseAuthorization()
            // 권한 요청 후 약간의 딜레이
            try? await Task.sleep(for: .milliseconds(500))
            status = mapLocationStatus(locationManager.authorizationStatus)

        case .camera:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            status = granted ? .authorized : .denied

        case .photoLibrary:
            let photoStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            status = mapPhotoStatus(photoStatus)

        case .notification:
            do {
                let granted = try await UNUserNotificationCenter.current()
                    .requestAuthorization(options: [.alert, .badge, .sound])
                status = granted ? .authorized : .denied
            } catch {
                status = .denied
            }
        }

        return PermissionStatus(type: type, status: status)
    }

    // MARK: - Status Mapping

    private func mapLocationStatus(_ status: CLAuthorizationStatus) -> AuthorizationStatus {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        case .denied:
            return .denied
        case .authorizedAlways:
            return .authorizedAlways
        case .authorizedWhenInUse:
            return .authorizedWhenInUse
        @unknown default:
            return .notDetermined
        }
    }

    private func mapAVStatus(_ status: AVAuthorizationStatus) -> AuthorizationStatus {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        case .denied:
            return .denied
        case .authorized:
            return .authorized
        @unknown default:
            return .notDetermined
        }
    }

    private func mapPhotoStatus(_ status: PHAuthorizationStatus) -> AuthorizationStatus {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        case .denied:
            return .denied
        case .authorized, .limited:
            return .authorized
        @unknown default:
            return .notDetermined
        }
    }
}
