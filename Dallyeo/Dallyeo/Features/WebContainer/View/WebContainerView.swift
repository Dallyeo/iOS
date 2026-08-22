//
//  WebContainerView.swift
//  Dallyeo
//
//  웹뷰 컨테이너. 웹(V01/V02/V10~V14) 위에 네이티브 화면(V03~V09)을 얹는다.
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
            WebViewRepresentable(bridge: bridge)
                .ignoresSafeArea()

            // 네이티브 화면 — V03~V09 전체 흐름을 ContentView가 갖고 있다.
            // 여기서 화면 전환을 또 관리하지 않는다(이중 관리 방지).
            if let entry = coordinator.nativeEntry {
                ContentView(
                    initialRoute: entry.route,
                    onRunFinished: { result in
                        // V10 완주 결과는 웹 담당 → 결과를 넘기고 웹으로 복귀
                        bridge.emitRunCompleted(result)
                        coordinator.dismissToWebView()
                    },
                    onExit: {
                        coordinator.dismissToWebView()
                    }
                )
                .id(entry)                       // 진입점이 바뀌면 흐름을 새로 시작
                .transition(.move(edge: .trailing))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: coordinator.nativeEntry)
        .onAppear {
            bridge.coordinator = coordinator
        }
    }
}
