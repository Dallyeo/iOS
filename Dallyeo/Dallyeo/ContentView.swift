//
//  ContentView.swift
//  Dallyeo
//
//  Created by 내꺼다 on 6/3/26.
//

import SwiftUI

/// 네이티브 화면 전환 경로 (V03 → V04 → V05 → V06 → V07)
enum AppRoute: Hashable {
    case search                       // V04
    case searchResult(query: String)  // V05
    case locationInfo(place: MapPlace) // V06
    case routeEdit                     // V07
    /// V08. `courseId`가 있으면 BE 추천 코스, nil이면 V07에서 만든 코스(RouteDraft)
    case courseConfirm(courseId: String?)
    /// V09. `courseId`가 있으면 웹에서 바로 시작한 경우라 코스를 직접 불러온다.
    /// nil이면 V08에서 확정한 코스를 그대로 쓴다.
    case running(courseId: String?)
}

struct ContentView: View {

    @State private var path: [AppRoute] = []
    @State private var routeDraft = RouteDraft()
    /// V08에서 확정된 코스. V09가 이걸 그대로 받아 진행한다.
    @State private var runningCourse: RunCourse?

    /// 진입 시 곧바로 밀어 넣을 화면. 웹에서 브릿지로 특정 화면을 열 때 쓴다.
    /// nil이면 V03 지도부터 시작(네이티브 단독 실행).
    var initialRoute: AppRoute?
    /// 러닝 완료. 웹 컨테이너가 받아 `runCompleted` 이벤트로 넘긴다.
    var onRunFinished: ((RunResult) -> Void)?
    /// 네이티브 흐름을 빠져나감(뿌리에서 뒤로가기). 웹으로 돌아갈 때 쓴다.
    var onExit: (() -> Void)?

    var body: some View {
        NavigationStack(path: $path) {
            MapView(
                onSearchTap: { path.append(.search) },
                onSelectPlace: { path.append(.locationInfo(place: $0)) },
                onBack: onExit,
                bottomSheetVisible: path.isEmpty
            )
            .navigationDestination(for: AppRoute.self) { route in
                destination(for: route)
            }
        }
        .environment(routeDraft)
        .task {
            LocationProvider.shared.start()
            if let initialRoute, path.isEmpty { path.append(initialRoute) }
        }
    }

    @ViewBuilder
    private func destination(for route: AppRoute) -> some View {
        switch route {
        case .search:
            SearchView(onSubmit: { query in
                path.append(.searchResult(query: query))
            })
        case .searchResult(let query):
            SearchResultView(
                query: query,
                bottomSheetVisible: isTop(route),
                onSelectPlace: { place in
                    if let slot = routeDraft.editingSlot {
                        // V07에서 지점 편집 중 → 슬롯에 할당하고 V07로 복귀
                        routeDraft.assign(place, to: slot)
                        routeDraft.editingSlot = nil
                        path.removeLast(2)   // searchResult + search 제거 → routeEdit
                    } else {
                        path.append(.locationInfo(place: place))
                    }
                }
            )
        case .locationInfo(let place):
            LocationInfoView(
                place: place,
                bottomSheetVisible: isTop(route),
                onRoleSet: { path.append(.routeEdit) }
            )
        case .routeEdit:
            RouteEditView(
                draft: routeDraft,
                onConfirm: { path.append(.courseConfirm(courseId: nil)) },
                onEditSlot: { slot in
                    routeDraft.editingSlot = slot
                    path.append(.search)
                }
            )
        case .courseConfirm(let courseId):
            if let courseId {
                // 추천 코스 — 경로/지점 모두 BE에서 로드
                CourseConfirmView(
                    courseId: courseId,
                    onEdit: { path.removeLast() },
                    onStart: { course in
                        runningCourse = course
                        path.append(.running(courseId: nil))
                    }
                )
            } else {
                CourseConfirmView(
                    draft: routeDraft,
                    onEdit: { path.removeLast() },     // V07 경로수정으로 복귀
                    onStart: { course in
                        runningCourse = course
                        path.append(.running(courseId: nil))
                    }
                )
            }
        case .running(let courseId):
            let finish: (RunResult) -> Void = { result in
                path.removeAll()
                // 웹이 붙어 있으면 V10 완주 결과로 넘긴다. 없으면 지도로 복귀.
                onRunFinished?(result)
            }
            if let courseId {
                // 웹에서 바로 시작 — 코스를 먼저 불러온다
                RunCourseLoader(courseId: courseId) { course in
                    RunningView(course: course, onFinish: finish)
                }
            } else if let runningCourse {
                RunningView(course: runningCourse, onFinish: finish)
            }
        }
    }

    /// 해당 라우트가 스택 최상단인지
    private func isTop(_ route: AppRoute) -> Bool {
        path.last == route
    }
}

#Preview {
    ContentView()
}
