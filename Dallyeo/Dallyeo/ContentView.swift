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
    case running                       // V09
}

struct ContentView: View {

    @State private var path: [AppRoute] = []
    @State private var routeDraft = RouteDraft()

    var body: some View {
        NavigationStack(path: $path) {
            MapView(
                onSearchTap: { path.append(.search) },
                onSelectPlace: { path.append(.locationInfo(place: $0)) },
                bottomSheetVisible: path.isEmpty
            )
            .navigationDestination(for: AppRoute.self) { route in
                destination(for: route)
            }
        }
        .environment(routeDraft)
        .task { LocationProvider.shared.start() }
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
                    onStart: { path.append(.running) }
                )
            } else {
                CourseConfirmView(
                    draft: routeDraft,
                    onEdit: { path.removeLast() },     // V07 경로수정으로 복귀
                    onStart: { path.append(.running) }
                )
            }
        case .running:
            RunningView(
                draft: routeDraft,
                onFinish: { _ in
                    // TODO: 웹 V10으로 runCompleted 이벤트. 현재는 지도까지 pop
                    path.removeAll()
                }
            )
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
