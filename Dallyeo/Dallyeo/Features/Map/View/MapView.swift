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
    /// 뒤로가기(웹 컨테이너 복귀). 웹뷰 연동 전까지는 placeholder.
    var onBack: (() -> Void)?
    /// 지도가 네비게이션 최상단일 때만 바텀시트 표시 (push된 화면 위로 시트가 뜨는 충돌 방지)
    var bottomSheetVisible: Bool = true

    var body: some View {
        KakaoMapView(
            userLocation: viewModel.userLocation,
            places: viewModel.currentPlaces
        )
        .ignoresSafeArea()
        .overlay(alignment: .top) {
            // 바텀시트가 올라와도 항상 위에 표시
            VStack {
                HStack(spacing: 8) {
                    backButton
                    searchBar
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                Spacer()
            }
        }
        .sheet(isPresented: .constant(bottomSheetVisible)) {
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

    // MARK: - 뒤로가기 (플로팅 원형)

    private var backButton: some View {
        Button {
            onBack?()
        } label: {
            Image(systemName: "arrow.backward")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(AppColor.gray900)
                .frame(width: 48, height: 48)
                .background {
                    Circle()
                        .fill(AppColor.white)
                        .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 2)
                }
        }
    }

    // MARK: - 검색바 (장소 검색 + 지역칩)

    private var searchBar: some View {
        Button {
            onSearchTap?()
        } label: {
            HStack(spacing: 8) {
                Text("장소 검색")
                    .font(.system(size: 16))
                    .foregroundStyle(AppColor.gray500)
                Spacer()
                // 현재 지역 칩 (초록). TODO: 지역 선택/필터 연동
                Text("군산")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColor.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(AppColor.primary, in: Capsule())
            }
            .padding(.leading, 18)
            .padding(.trailing, 6)
            .padding(.vertical, 6)
            .background {
                Capsule()
                    .fill(AppColor.white)
                    .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 2)
            }
        }
    }
}
