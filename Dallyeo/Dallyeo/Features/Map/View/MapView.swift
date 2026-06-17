//
//  MapView.swift
//  Dallyeo
//
//  V03 지도뷰 — 카카오맵 + 검색바 + 바텀시트
//

import SwiftUI

// 검색바 아래부터 채우는 커스텀 detent
struct MapFullDetent: CustomPresentationDetent {
    static func height(in context: Context) -> CGFloat? {
        // 전체 높이에서 검색바 영역(상단 safe area + 검색바 52 + 패딩 16) 제외
        context.maxDetentValue - 68
    }
}

struct MapView: View {

    @State private var viewModel = MapViewModel()
    var onSearchTap: (() -> Void)?

    var body: some View {
        KakaoMapView(
            userLocation: viewModel.userLocation,
            places: viewModel.currentPlaces
        )
        .ignoresSafeArea()
        .overlay(alignment: .top) {
            // 바텀시트가 올라와도 항상 위에 표시
            VStack {
                searchBar
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                Spacer()
            }
        }
        .sheet(isPresented: .constant(true)) {
            MapBottomSheetView(
                selectedSegment: $viewModel.selectedSegment,
                places: viewModel.currentPlaces,
                isLoading: viewModel.isLoading
            )
            // 알럿은 항상 떠있는 시트 콘텐츠에 부착 (맵 루트에 붙이면 sheet와 표시 충돌)
            .alert("위치 권한이 필요해요", isPresented: $viewModel.showPermissionAlert) {
                Button("취소", role: .cancel) {}
                Button("설정으로 이동") { viewModel.openAppSettings() }
            } message: {
                Text("주변 장소를 보려면 설정 > 달여에서 위치 접근을 허용해 주세요.")
            }
            .alert("위치를 가져올 수 없어요", isPresented: $viewModel.showGPSErrorAlert) {
                Button("취소", role: .cancel) {}
                Button("재시도") { viewModel.retryLocation() }
            } message: {
                Text("GPS 신호를 확인하고 다시 시도해 주세요.")
            }
            // 최소: 피그마 126 → 헤더 패딩 압축 방지 위해 상향
            .presentationDetents([.height(160), .medium, .custom(MapFullDetent.self)])
            .presentationDragIndicator(.visible)
            .presentationBackgroundInteraction(.enabled(upThrough: .custom(MapFullDetent.self)))
            .interactiveDismissDisabled()
        }
        .task {
            viewModel.requestLocationIfNeeded()
            await viewModel.loadPlaces()
        }
    }

    // MARK: - 검색바

    private var searchBar: some View {
        Button {
            onSearchTap?()
        } label: {
            HStack(spacing: 8) {
                Text("장소 검색")
                    .font(.system(size: 16))
                    .foregroundStyle(AppColor.gray500)
                Spacer()
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(AppColor.gray900)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(AppColor.white, in: RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
        }
    }
}
