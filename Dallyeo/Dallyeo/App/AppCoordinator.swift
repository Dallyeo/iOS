//
//  AppCoordinator.swift
//  Dallyeo
//
//  웹 ↔ 네이티브 전환 관리.
//
//  네이티브 화면 사이의 이동(V03~V09)은 ContentView의 NavigationStack이 전부 갖고 있다.
//  여기서는 "웹이 어떤 화면으로 들어가자고 했는지"만 들고 있으면 된다.
//  (예전에는 화면 전환을 여기서 또 관리했는데, ContentView와 이중 관리가 되어 걷어냈다)
//

import SwiftUI

@MainActor
@Observable
final class AppCoordinator {

    /// 웹이 요청한 네이티브 진입점. nil이면 웹뷰만 보인다.
    var nativeEntry: NativeEntry?

    enum NativeEntry: Hashable {
        /// V04 검색뷰부터 (코스 만들기)
        case courseSearch
        /// V08 코스확인뷰 — 웹의 추천 코스
        case courseConfirm(courseId: String?)
        /// V09 코스진행뷰 — 웹에서 바로 러닝 시작
        case running(courseId: String)

        /// ContentView에 넘길 진입 라우트
        var route: AppRoute {
            switch self {
            case .courseSearch:                  .search
            case .courseConfirm(let id):         .courseConfirm(courseId: id)
            case .running(let id):               .running(courseId: id)
            }
        }
    }

    // MARK: - 브릿지에서 호출

    func openCourseSearch() {
        nativeEntry = .courseSearch
    }

    func openCourseConfirm(courseId: String?) {
        nativeEntry = .courseConfirm(courseId: courseId)
    }

    func startRun(courseId: String) {
        nativeEntry = .running(courseId: courseId)
    }

    /// 웹뷰로 복귀
    func dismissToWebView() {
        nativeEntry = nil
    }
}
