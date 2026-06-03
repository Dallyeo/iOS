//
//  AppCoordinator.swift
//  Dallyeo
//
//  앱 전체 네비게이션 관리
//

import SwiftUI

@MainActor
@Observable
final class AppCoordinator {

    // MARK: - Navigation State

    var navigationPath = NavigationPath()
    var currentNativeScreen: NativeScreen?

    // MARK: - Native Screens

    enum NativeScreen: Hashable {
        case map           // V03
        case search        // V04
        case searchResult(query: String)  // V05
        case locationInfo  // V06
        case routeEdit     // V07
        case courseConfirm // V08
        case running       // V09
    }

    // MARK: - Navigation Actions

    /// V04 검색뷰로 진입
    func openCourseSearch() {
        currentNativeScreen = .search
    }

    /// V08 코스확인뷰로 진입
    func openCourseConfirm() {
        currentNativeScreen = .courseConfirm
    }

    /// V09 코스진행뷰로 진입
    func startRun() {
        currentNativeScreen = .running
    }

    /// 웹뷰로 복귀
    func dismissToWebView() {
        currentNativeScreen = nil
        navigationPath = NavigationPath()
    }

    /// 이전 화면으로 이동
    func goBack() {
        if !navigationPath.isEmpty {
            navigationPath.removeLast()
        } else {
            dismissToWebView()
        }
    }
}
