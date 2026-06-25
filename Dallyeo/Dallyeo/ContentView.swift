//
//  ContentView.swift
//  Dallyeo
//
//  Created by 내꺼다 on 6/3/26.
//

import SwiftUI

struct ContentView: View {

    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            MapView(
                onSearchTap: { path.append(SearchRoute.search) },
                bottomSheetVisible: path.isEmpty
            )
                .navigationDestination(for: SearchRoute.self) { _ in
                    SearchView(onSubmit: { _ in
                        // TODO: V05 검색결과뷰로 이동. 지금은 검색뷰만 닫음
                        path.removeLast()
                    })
                }
        }
    }
}

/// V03 → V04 진입 경로
enum SearchRoute: Hashable {
    case search
}

#Preview {
    ContentView()
}
