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
//  이 줄은 지도 위에 떠 있는 게 아니라 **불투명한 헤더 패널 위에** 얹힌다
//  (Figma "Rectangle 58" 402×125, #FAFAFA, 그림자 0/4/4 5%).
//  패널 없이 아이콘만 띄우면 지도 위에 뒤로가기·X가 둥둥 뜬다 — QA V05-1/V06-1.
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
    /// 상태바 아래 여백 (Figma: 검색바 y=64 - 상태바 62)
    private let topGap: CGFloat = 2
    /// 패널 하단 여백 (Figma: 패널 125 - 검색바 아래 114)
    private let bottomGap: CGFloat = 11

    var body: some View {
        HStack(spacing: 0) {
            // 두 SVG의 박스 규격이 다르다 — 같은 프레임에 넣으면 크기가 어긋난다.
            //   ic_west  : 글리프만 잘라낸 21.2×14.2
            //   ic_close : 40×40 머티리얼 박스 안에 13.15 글리프
            // 24×24로 똑같이 그리던 탓에 화살표는 30% 커지고 X는 40% 작아졌다(QA V05-1/V06-1).
            // Figma(785:2008 / 785:2016)가 그리는 글리프 크기에 각각 맞춘다.
            iconButton("ic_west", imageSize: CGSize(width: 19.575, height: 13.15), action: onBack)
            searchBar
            iconButton("ic_close", imageSize: CGSize(width: iconSize, height: iconSize), action: onClose)
        }
        .padding(.horizontal, 16)
        .padding(.top, topGap)
        .padding(.bottom, bottomGap)
        .frame(maxWidth: .infinity)
        .background {
            // 상태바 뒤까지 채워야 패널로 보인다. 화면 높이는 기기 안전영역만큼 달라진다.
            AppColor.whiteDim
                .ignoresSafeArea(edges: .top)
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 4)
        }
    }

    /// `imageSize`는 아이콘 자체를 그릴 크기다. 탭 영역은 항상 40×40.
    private func iconButton(_ name: String, imageSize: CGSize,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(name)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: imageSize.width, height: imageSize.height)
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
                    // Figma 785:2006 — 칩 60×29 안에 글자 26 → 좌우 17
                    .padding(.horizontal, 17)
                    .background(AppColor.primary, in: RoundedRectangle(cornerRadius: 8))
            }
            .padding(.horizontal, barInset)
            .frame(maxWidth: .infinity)
            .frame(height: barHeight)
            // 그림자 없음. HiFi의 검색바는 패널 위에 그냥 얹힌 흰 사각형이다
            // (Figma 785:1994 / 785:2003 모두 `bg-white rounded-[10px]`뿐).
            .background(AppColor.white, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}
