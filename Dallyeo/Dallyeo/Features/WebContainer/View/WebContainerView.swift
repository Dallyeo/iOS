//
//  WebContainerView.swift
//  Dallyeo
//
//  웹뷰 컨테이너 메인 뷰
//

import SwiftUI

struct WebContainerView: View {
    @State private var coordinator: AppCoordinator
    @State private var bridge: DallYeoBridge

    init(coordinator: AppCoordinator) {
        self._coordinator = State(initialValue: coordinator)
        self._bridge = State(initialValue: DallYeoBridge())
    }

    var body: some View {
        ZStack {
            // 웹뷰
            WebViewRepresentable(bridge: bridge)
                .ignoresSafeArea()

            // 네이티브 화면 오버레이
            if let nativeScreen = coordinator.currentNativeScreen {
                nativeScreenView(for: nativeScreen)
                    .transition(.move(edge: .trailing))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: coordinator.currentNativeScreen)
        .onAppear {
            bridge.coordinator = coordinator
        }
        .gesture(
            DragGesture()
                .onEnded { value in
                    // 좌측 스와이프 뒤로가기
                    if value.translation.width > 100 && value.startLocation.x < 50 {
                        coordinator.goBack()
                    }
                }
        )
    }

    // MARK: - Native Screen Builder

    @ViewBuilder
    private func nativeScreenView(for screen: AppCoordinator.NativeScreen) -> some View {
        switch screen {
        case .map:
            // V03 지도뷰 (추후 구현)
            PlaceholderView(title: "V03 지도뷰", coordinator: coordinator)

        case .search:
            // V04 검색뷰 (추후 구현)
            PlaceholderView(title: "V04 검색뷰", coordinator: coordinator)

        case .searchResult(let query):
            // V05 검색결과뷰 (추후 구현)
            PlaceholderView(title: "V05 검색결과뷰\n검색어: \(query)", coordinator: coordinator)

        case .locationInfo:
            // V06 위치정보뷰 (추후 구현)
            PlaceholderView(title: "V06 위치정보뷰", coordinator: coordinator)

        case .routeEdit:
            // V07 경로수정뷰 (추후 구현)
            PlaceholderView(title: "V07 경로수정뷰", coordinator: coordinator)

        case .courseConfirm:
            // V08 코스확인뷰 (추후 구현)
            PlaceholderView(title: "V08 코스확인뷰", coordinator: coordinator)

        case .running:
            // V09 코스진행뷰 (추후 구현)
            PlaceholderView(title: "V09 코스진행뷰", coordinator: coordinator)
        }
    }
}

// MARK: - Placeholder View (개발용)

private struct PlaceholderView: View {
    let title: String
    let coordinator: AppCoordinator

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)

                Button("뒤로가기") {
                    coordinator.goBack()
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

#Preview {
    WebContainerView(coordinator: AppCoordinator())
}
