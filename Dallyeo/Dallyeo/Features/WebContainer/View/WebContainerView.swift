//
//  WebContainerView.swift
//  Dallyeo
//
//  웹뷰 컨테이너. 웹(V01/V02/V10~V14) 위에 네이티브 화면(V03~V09)을 얹는다.
//

import OSLog
import SwiftUI

struct WebContainerView: View {
    @State private var coordinator: AppCoordinator
    @State private var bridge: DallYeoBridge
    /// 거리 0으로 끝냈을 때 잠깐 띄우는 안내. nil이면 안 띄운다.
    @State private var toast: String?

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
                        // `@MainActor` 명시 — 이 클로저 타입이 isolated가 아니라
                        // 그냥 `Task {}`로 두면 백그라운드에서 돌아 `@State` 변경이
                        // 화면에 반영되지 않는다(토스트가 안 뜬다).
                        Task { @MainActor in
                            // 저장 → 이미지 업로드까지 마치고 웹에 넘긴다.
                            // 이미지가 붙기 전에 넘기면 웹이 조회했을 때 imageUrl이
                            // 아직 비어 있어 지도가 회색으로 뜬다.
                            let saved = await RunRecorder.save(result, snapshot: snapshot)
                            switch saved {
                            case .success(let record):
                                bridge.emitRunCompleted(result, saved: record)

                            // 이동 거리가 0이면 결과화면을 띄우지 않는다(기획 결정).
                            // 보여줄 거리도 지도도 없고, 사용자는 방금 "러닝을
                            // 그만두시겠어요? → 확인"을 누른 참이다. 메인뷰로 돌려보내고
                            // 안내만 띄운다.
                            case .failure(.notEnoughData):
                                bridge.emitRunCancelled()
                                toast = "기록이 저장되지 않았어요"
                                Logger(subsystem: "com.dallyeo.app", category: "run-record")
                                    .info("거리 0 — 결과화면 생략, 토스트 표시")

                            case .failure(let reason):
                                // 달리긴 했는데 저장만 실패한 경우. 결과는 보여준다 —
                                // 달리고 나서 아무것도 못 보는 게 최악이다.
                                // 실패 사유는 웹이 결과화면에서 안내하도록 넘긴다.
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

            if let toast {
                toastView(toast).transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: coordinator.nativeEntry)
        .animation(.easeInOut(duration: 0.2), value: toast)
        .onAppear {
            bridge.coordinator = coordinator
        }
        .task {
            // 지난번에 못 올린 기록이 있으면 올린다.
            // 네트워크가 끊겼거나 서버가 잠깐 죽었던 경우가 여기서 회수된다.
            // (게스트 기록은 로그인 시점에도 따로 올린다 — `AuthService.login`)
            await RunRecorder.flushPending()
        }
    }

    /// 메인뷰 위에 잠깐 떴다 사라지는 안내.
    ///
    /// 이 경우엔 웹 결과화면이 뜨지 않으므로 네이티브가 띄워도 겹치지 않는다.
    private func toastView(_ message: String) -> some View {
        Text(message)
            .font(AppFont.pretendard(14, .medium))
            .foregroundStyle(AppColor.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(AppColor.gray900.opacity(0.92), in: RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 32)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 120)   // 탭바 위
            .allowsHitTesting(false)
            .task {
                try? await Task.sleep(for: .seconds(3))
                toast = nil
            }
    }
}
