//
//  DallyeoAlert.swift
//  Dallyeo
//
//  공용 알럿 (Figma 569:646). 제목 + 선택적 부제 + 좌우 버튼 2개.
//  V09 일시정지/종료 확인에서 사용.
//

import SwiftUI

struct DallyeoAlert: View {

    let title: String
    var message: String? = nil
    let secondaryTitle: String       // 왼쪽(회색)
    let primaryTitle: String         // 오른쪽(초록)
    var onSecondary: () -> Void
    var onPrimary: () -> Void

    // Figma 실측
    private let boxWidth: CGFloat = 325
    private let boxHeight: CGFloat = 150
    private let contentWidth: CGFloat = 301
    private let buttonSize = CGSize(width: 140, height: 37)

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()

            VStack(spacing: 26) {
                VStack(spacing: 8) {
                    Text(title)
                        .font(AppFont.pretendard(17, .semibold))
                        .foregroundStyle(AppColor.black)
                    if let message {
                        Text(message)
                            .font(AppFont.pretendard(12, .medium))
                            .tracking(AppFont.tracking(-2, size: 12))
                            .foregroundStyle(AppColor.gray600)
                    }
                }
                .multilineTextAlignment(.center)

                HStack(spacing: 0) {
                    button(secondaryTitle, background: AppColor.gray300,
                           foreground: AppColor.whiteDim, action: onSecondary)
                    Spacer(minLength: 0)
                    button(primaryTitle, background: AppColor.primary,
                           foreground: AppColor.white, action: onPrimary)
                }
                .frame(width: contentWidth)
            }
            .frame(width: contentWidth, height: 120, alignment: .bottom)
            .padding(.leading, 12)
            .padding(.top, 14)
            .frame(width: boxWidth, height: boxHeight, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppColor.white)
                    .shadow(color: .black.opacity(0.1), radius: 10)
            )
        }
    }

    private func button(_ title: String, background: Color, foreground: Color,
                        action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(AppFont.pretendard(15, .medium))
                .tracking(AppFont.tracking(-2, size: 15))
                .foregroundStyle(foreground)
                .frame(width: buttonSize.width, height: buttonSize.height)
                .background(background, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    DallyeoAlert(
        title: "일시정지했어요.",
        message: "이어서 뛰려면 재개를 눌러주세요.",
        secondaryTitle: "끝내기",
        primaryTitle: "재개",
        onSecondary: {}, onPrimary: {}
    )
}
