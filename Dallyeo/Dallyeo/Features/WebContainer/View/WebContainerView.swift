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
                    onRunFinished: { result, snapshot in
                        Task {
                            // 저장 → 이미지 업로드까지 마치고 웹에 넘긴다.
                            // 이미지가 붙기 전에 넘기면 웹이 조회했을 때 imageUrl이
                            // 아직 비어 있어 지도가 회색으로 뜬다.
                            let saved = await RunRecorder.save(result, snapshot: snapshot)
                            switch saved {
                            case .success(let record):
                                bridge.emitRunCompleted(result, saved: record)
                            case .failure(let reason):
                                // 저장이 안 돼도 결과는 보여준다. 달리고 나서 아무것도
                                // 못 보는 게 최악이다. 실패 사유는 웹이 결과화면에서
                                // 안내하도록 payload로 넘긴다.
                                bridge.emitRunCompleted(result, saved: nil, saveFailure: reason)
                            }
                            coordinator.dismissToWebView()
                        }
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
