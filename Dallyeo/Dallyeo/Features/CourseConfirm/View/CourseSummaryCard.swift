//
//  CourseSummaryCard.swift
//  Dallyeo
//
//  V08 코스확인 흰 카드 — 총거리 / 수정 칩 / 구분선 / 지점 리스트.
//  Figma 565:528 기준.
//

import SwiftUI

struct CourseSummaryCard: View {

    let distanceText: String
    let points: [CoursePoint]
    var onEdit: (() -> Void)?

    // Figma 실측 (565:828 "실제 구현 목표")
    private let rowHeight: CGFloat = 26
    private let rowSpacing: CGFloat = 20
    /// 총거리 행 높이. Figma 565:831 = 30 (지점 행 26과 다르다)
    private let headerRowHeight: CGFloat = 30
    /// 구분선 아래 ~ 지점 리스트 위. Figma 565:836 y=80 − 헤더 프레임 높이 45
    private let listTopSpacing: CGFloat = 35
    private let badgeColumnWidth: CGFloat = 26
    private let nameColumnWidth: CGFloat = 200
    private let columnSpacing: CGFloat = 15
    /// 출발/도착 점 지름 (Figma 565:838 벡터의 끝 원 r=2.67)
    private let connectorDotSize: CGFloat = 5.33
    private let connectorLineWidth: CGFloat = 1

    var body: some View {
        VStack(alignment: .leading, spacing: listTopSpacing) {
            header
            pointList
        }
        .frame(width: 316)
        .padding(.horizontal, 27)
        .padding(.vertical, 25)
        .background(AppColor.white, in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - 총거리 + 수정 칩 + 구분선

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(distanceText)
                    .font(AppFont.pretendard(22, .bold))
                    .foregroundStyle(AppColor.gray700)

                Spacer(minLength: 0)

                // 추천 코스는 onEdit이 없다 → 칩 자체를 그리지 않는다.
                if let onEdit {
                    Button(action: onEdit) {
                        Text("수정")
                            .font(AppFont.pretendard(15, .medium))
                            .tracking(AppFont.tracking(-2, size: 15))
                            .foregroundStyle(AppColor.primary)
                            .frame(width: 55, height: 26)
                            .background(AppColor.primary200, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(height: headerRowHeight)

            RoundedRectangle(cornerRadius: 3)
                .fill(AppColor.primary500)
                .frame(height: 3)
        }
    }

    // MARK: - 지점 리스트 (번호열 + 이름열)

    private var pointList: some View {
        HStack(alignment: .top, spacing: columnSpacing) {
            // 번호열 — 세로 연결선 위에 경유지 배지, 출발/도착은 선 끝의 점
            VStack(spacing: rowSpacing) {
                ForEach(points) { point in
                    Group {
                        if case .waypoint(let n) = point.role {
                            WaypointNumberBadge(number: n)
                        } else {
                            Circle()
                                .fill(AppColor.courseConnector)
                                .frame(width: connectorDotSize, height: connectorDotSize)
                        }
                    }
                    .frame(width: badgeColumnWidth, height: rowHeight)
                }
            }
            // 배경으로 깔아야 선이 열 높이에 맞춰진다.
            // (ZStack에 넣으면 Rectangle이 고유 높이가 없어 무한정 늘어난다)
            .background(alignment: .center) { connectorLine }
            .frame(width: badgeColumnWidth)

            // 이름열 — 출발/도착은 진하게, 경유는 흐리게
            VStack(alignment: .leading, spacing: rowSpacing) {
                ForEach(points) { point in
                    nameText(for: point)
                        .frame(width: nameColumnWidth, height: rowHeight, alignment: .leading)
                }
            }
            .frame(width: nameColumnWidth)
        }
        // Figma는 리스트를 카드 콘텐츠 왼쪽에 붙인다(565:836 x=0).
        // 가운데 정렬하면 번호열이 35pt쯤 안쪽으로 밀려 들어간다.
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 첫 행 중심 ~ 마지막 행 중심을 잇는 세로선. 경유지 배지 뒤로 지나간다.
    @ViewBuilder
    private var connectorLine: some View {
        if points.count > 1 {
            Rectangle()
                .fill(AppColor.courseConnector)
                .frame(width: connectorLineWidth)
                .padding(.vertical, rowHeight / 2)
        }
    }

    @ViewBuilder
    private func nameText(for point: CoursePoint) -> some View {
        if case .waypoint = point.role {
            Text(point.name)
                .font(AppFont.pretendard(15, .medium))
                .tracking(AppFont.tracking(-2, size: 15))
                .foregroundStyle(AppColor.gray400)
                .lineLimit(1)
        } else {
            Text(point.name)
                .font(AppFont.pretendard(17, .semibold))
                .foregroundStyle(AppColor.gray750)
                .lineLimit(1)
        }
    }
}
