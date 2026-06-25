//
//  UINavigationController+SwipeBack.swift
//  Dallyeo
//
//  네비게이션 바를 숨겨도(커스텀 헤더 사용) 좌측 스와이프 뒤로가기가 동작하도록 보정.
//  CLAUDE.md 하드 제약: 좌측 스와이프 뒤로가기 모든 화면에서 동작.
//

import UIKit

extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // 루트가 아닐 때만 스와이프 pop 허용
        viewControllers.count > 1
    }
}
