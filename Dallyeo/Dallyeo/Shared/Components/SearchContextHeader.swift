//
//  SearchContextHeader.swift
//  Dallyeo
//
//  V05 검색결과뷰 / V06 위치정보뷰 공용 상단 검색바.
//  Figma 542:992(V05_검색상세) 기준 — 두 화면이 같은 헤더를 쓴다.
//
//  구성: [뒤로가기 40] [검색바(검색어 + 지역칩)] [닫기 40], 좌우 여백 16
//  402pt 기준 16 + 40 + 290 + 40 + 16 = 402 이라 검색바는 남는 폭을 채우면 된다.
//

import SwiftUI

struct SearchContextHeader: View {

    /// 검색바에 표시할 검색어
    let query: String
    /// 지역 칩 텍스트
    let regionText: String

    /// 뒤로가기 — V05는 V04로, V06은 V05로
    var onBack: () -> Void
    /// 검색바 탭 — V04 검색뷰로 이동해 검색어 수정 (스펙 V05/V06 "상단 검색바")
    var onEditQuery: () -> Void
    /// 닫기 — 검색 초기 화면(V03 지도뷰)으로
    var onClose: () -> Void

    // Figma 실측
    private let iconSize: CGFloat = 40
    private let barHeight: CGFloat = 50
    private let barInset: CGFloat = 9      // (290 - 272) / 2

    var body: some View {
        HStack(spacing: 0) {
            iconButton("ic_west", action: onBack)
            searchBar
            iconButton("ic_close", action: onClose)
        }
        .padding(.horizontal, 16)
    }

    private func iconButton(_ name: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(name)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .foregroundStyle(AppColor.gray900)
                .frame(width: iconSize, height: iconSize)
                .contentShape(Rectangle())
        }
    }

    /// 검색어는 편집 필드가 아니라 버튼이다.
    /// 탭하면 V04로 돌아가 수정한다(스펙: "검색바 선택 → V04로 이동하여 검색어 수정").
    private var searchBar: some View {
        Button(action: onEditQuery) {
            HStack(spacing: 8) {
                Text(query)
                    .font(AppFont.pretendard(15, .medium))
                    .tracking(AppFont.tracking(-2, size: 15))
                    .foregroundStyle(AppColor.gray500)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Text(regionText)
                    .font(AppFont.pretendard(15, .semibold))
                    .foregroundStyle(AppColor.white)
                    .frame(height: 29)
                    .padding(.horizontal, 16)
                    .background(AppColor.primary, in: RoundedRectangle(cornerRadius: 8))
            }
            .padding(.horizontal, barInset)
            .frame(maxWidth: .infinity)
            .frame(height: barHeight)
            .background {
                RoundedRectangle(cornerRadius: 10)
                    .fill(AppColor.white)
                    .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 2)
            }
        }
        .buttonStyle(.plain)
    }
}
