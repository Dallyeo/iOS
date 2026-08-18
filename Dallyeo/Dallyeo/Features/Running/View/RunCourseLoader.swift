//
//  RunCourseLoader.swift
//  Dallyeo
//
//  코스 id만 있을 때 BE에서 코스를 받아 온 뒤 내용을 그리는 래퍼.
//  웹에서 `startRun(course)`로 바로 러닝을 시작하는 경로에서 쓴다.
//  (V08을 거쳐 오면 이미 RunCourse가 있으므로 필요 없다)
//

import SwiftUI

struct RunCourseLoader<Content: View>: View {

    let courseId: String
    @ViewBuilder let content: (RunCourse) -> Content

    @State private var course: RunCourse?
    @State private var failed = false

    var body: some View {
        Group {
            if let course {
                content(course)
            } else if failed {
                failureView
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppColor.gray200)
            }
        }
        .task(id: courseId) { await load() }
    }

    private var failureView: some View {
        VStack(spacing: 12) {
            Text("코스를 불러오지 못했어요.")
                .font(AppFont.pretendard(15, .medium))
                .foregroundStyle(AppColor.gray500)
            Button("다시 시도") {
                failed = false
                Task { await load() }
            }
            .font(AppFont.pretendard(15, .semibold))
            .foregroundStyle(AppColor.primary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColor.gray200)
    }

    private func load() async {
        guard course == nil else { return }
        do {
            let detail = try await DallyeoAPI.courseDetail(id: courseId)
            course = RunCourse(detail: detail)
        } catch {
            failed = true
        }
    }
}
