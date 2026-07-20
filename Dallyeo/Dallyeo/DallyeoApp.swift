//
//  DallyeoApp.swift
//  Dallyeo
//
//  Created by 내꺼다 on 6/3/26.
//

import SwiftUI
import KakaoMapsSDK
import KakaoSDKCommon
import KakaoSDKAuth

@main
struct DallyeoApp: App {

    init() {
        guard let appKey = Bundle.main.object(forInfoDictionaryKey: "KAKAO_APP_KEY") as? String else {
            fatalError("Info.plist에 KAKAO_APP_KEY가 없습니다.")
        }
        // 카카오맵 SDK
        SDKInitializer.InitSDK(appKey: appKey)
        // 카카오 로그인 SDK
        KakaoSDK.initSDK(appKey: appKey)
    }

    var body: some Scene {
        WindowGroup {
            // 진입점 = 웹뷰 컨테이너 (FE V01 온보딩 / V02 메인).
            // 네이티브 화면(V03~V09)은 브릿지 호출로 오버레이 진입.
            WebContainerView(coordinator: AppCoordinator())
                .onOpenURL { url in
                    // 카카오톡 로그인 콜백 처리
                    if AuthApi.isKakaoTalkLoginUrl(url) {
                        _ = AuthController.handleOpenUrl(url: url)
                    }
                }
        }
    }
}
