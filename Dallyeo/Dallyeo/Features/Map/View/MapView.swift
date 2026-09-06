//
//  MapView.swift
//  Dallyeo
//
//  V03 지도뷰 — 카카오맵 + 검색바 + 바텀시트
//

import SwiftUI

struct MapView: View {

    @State private var viewModel = MapViewModel()
    var onSearchTap: (() -> Void)?
    /// 추천 카드 탭 → V06 위치정보뷰 진입
    var onSelectPlace: ((MapPlace) -> Void)?
    /// 뒤로가기(웹 컨테이너 복귀). 웹뷰 연동 전까지는 placeholder.
    var onBack: (() -> Void)?
    /// 지도가 네비게이션 최상단일 때만 바텀시트 표시 (push된 화면 위로 시트가 뜨는 충돌 방지)
    var bottomSheetVisible: Bool = true

    /// 바텀시트 현재 단. 기본은 카드 1줄이 보이는 위치.
    @State private var sheetDetent: SheetDetent = .height(380)

    /// 최소(160): 아래로 내렸을 때. 기본(380): 카드 1줄. 최대: 검색바 아래까지(상단 68 비움).
    private static let detents: [SheetDetent] = [.height(160), .height(380), .fromSafeTop(68)]

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
                Spacer()
            }
        }
        .mapBottomSheet(isPresented: bottomSheetVisible,
                        detents: Self.detents,
                        selection: $sheetDetent) {
            MapBottomSheetView(
                selectedSegment: $viewModel.selectedSegment,
                places: viewModel.currentPlaces,
                isLoading: viewModel.isLoading,
                onSelectPlace: onSelectPlace
            )
        }
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
            Image("ic_west")            // 디자인시스템 back/west
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 21, height: 15)
                .foregroundStyle(AppColor.gray900)
                .frame(width: 44, height: 44)
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
                    .font(AppFont.pretendard(15, .medium))
                    .tracking(AppFont.tracking(-2, size: 15))
                    .foregroundStyle(AppColor.gray500)
                Spacer()
                // 현재 지역 칩 (초록). TODO: 지역 선택/필터 연동
                Text(viewModel.regionText)
                    .font(AppFont.pretendard(15, .semibold))
                    .foregroundStyle(AppColor.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 5)
                    .background(AppColor.primary, in: RoundedRectangle(cornerRadius: 8))
            }
            .padding(.leading, 23)
            .padding(.trailing, 8)
            .frame(height: 50)
            .background {
                RoundedRectangle(cornerRadius: 10)
                    .fill(AppColor.white)
                    .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 2)
            }
        }
    }
}
