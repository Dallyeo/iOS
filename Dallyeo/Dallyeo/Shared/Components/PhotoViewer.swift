//
//  PhotoViewer.swift
//  Dallyeo
//
//  전체화면 이미지 뷰어 (V06 사진 탭 → "꽉찬 화면으로 사진 보기")
//  페이징(여러 장) + 핀치 줌 + 닫기.
//

import SwiftUI

struct PhotoViewer: View {

    let urls: [String]
    @State private var index: Int
    @Environment(\.dismiss) private var dismiss

    init(urls: [String], startIndex: Int = 0) {
        self.urls = urls
        _index = State(initialValue: min(max(startIndex, 0), max(urls.count - 1, 0)))
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            TabView(selection: $index) {
                ForEach(Array(urls.enumerated()), id: \.offset) { i, urlString in
                    ZoomableImage(urlString: urlString)
                        .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: urls.count > 1 ? .automatic : .never))

            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(.black.opacity(0.4)))
            }
            .padding(.top, 8)
            .padding(.trailing, 16)
        }
        .statusBarHidden()
    }
}

/// 핀치 줌 가능한 단일 이미지. 두 손가락 축소/확대, 놓으면 1배로 복귀.
private struct ZoomableImage: View {

    let urlString: String

    @State private var scale: CGFloat = 1
    @GestureState private var pinch: CGFloat = 1

    var body: some View {
        AsyncImage(url: URL(string: urlString)) { image in
            image
                .resizable()
                .scaledToFit()
                .scaleEffect(scale * pinch)
                .gesture(
                    MagnificationGesture()
                        .updating($pinch) { value, state, _ in state = value }
                        .onEnded { value in
                            scale = min(max(scale * value, 1), 4)
                        }
                )
                .onTapGesture(count: 2) {
                    withAnimation(.spring(duration: 0.25)) {
                        scale = scale > 1 ? 1 : 2
                    }
                }
        } placeholder: {
            ProgressView().tint(.white)
        }
    }
}
