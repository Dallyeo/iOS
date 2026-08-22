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
            // 앱 진입점 = 웹 컨테이너. 웹(V01/V02/V10~) 위에 네이티브(V03~V09)를 얹는다.
            WebContainerView(coordinator: AppCoordinator())
        }
    }
}
