//
//  DallyeoApp.swift
//  Dallyeo
//
//  Created by 내꺼다 on 6/3/26.
//

import SwiftUI
import KakaoMapsSDK

@main
struct DallyeoApp: App {

    init() {
        // 카카오맵 SDK 초기화
        guard let appKey = Bundle.main.object(forInfoDictionaryKey: "KAKAO_APP_KEY") as? String else {
            fatalError("Info.plist에 KAKAO_APP_KEY가 없습니다.")
        }
        SDKInitializer.InitSDK(appKey: appKey)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
