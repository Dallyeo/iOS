//
//  KakaoMapView.swift
//  Dallyeo
//
//  카카오맵 SDK UIViewRepresentable 래핑
//

import SwiftUI
import CoreLocation
import KakaoMapsSDK

struct KakaoMapView: UIViewRepresentable {

    var userLocation: CLLocationCoordinate2D?
    var places: [MapPlace]
    /// 마커 표시 여부 (V05 검색결과 등에서 사용). 기본은 표시 안 함(V03).
    var showsPlaceMarkers: Bool = false
    /// 현위치를 따라 카메라 계속 이동 (V09 러닝). 기본은 최초 1회만.
    var followsUser: Bool = false

    func makeUIView(context: Context) -> KMViewContainer {
        let bounds = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.bounds ?? UIScreen.main.bounds
        let container = KMViewContainer(frame: bounds)
        context.coordinator.setup(container: container)
        return container
    }

    func updateUIView(_ container: KMViewContainer, context: Context) {
        context.coordinator.syncViewRect(container.bounds.size)
        context.coordinator.updateLocation(userLocation, follow: followsUser)
        if showsPlaceMarkers {
            context.coordinator.updatePlaces(places)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
}

// MARK: - Coordinator

extension KakaoMapView {

    final class Coordinator: NSObject, MapControllerDelegate {

        private var controller: KMController?
        private var mapView: KakaoMap?
        private weak var container: KMViewContainer?

        // 엔진 준비 전 도착한 데이터 보류용
        private var pendingPlaces: [MapPlace]?
        private var pendingLocation: CLLocationCoordinate2D?
        private var didCenterOnUser = false

        private let poiLayerID = "placeLayer"
        private let poiStyleID = "placeMarker"

        func setup(container: KMViewContainer) {
            self.container = container
            controller = KMController(viewContainer: container)
            controller?.delegate = self
            _ = controller?.prepareEngine()
            controller?.activateEngine()
        }

        // MARK: - MapControllerDelegate

        func addViews() {
            let defaultPosition = MapPoint(longitude: 126.7107, latitude: 35.9676) // 기본: 군산
            let mapviewInfo = MapviewInfo(
                viewName: "mapview",
                viewInfoName: "map",
                defaultPosition: defaultPosition,
                defaultLevel: 15
            )
            controller?.addView(mapviewInfo)
        }

        func addViewSucceeded(_ viewName: String, viewInfoName: String) {
            mapView = controller?.getView("mapview") as? KakaoMap
            // 엔진 준비 시점에 컨테이너 실제 크기로 viewRect 설정 (찌그러짐 방지)
            if let size = container?.bounds.size, size.width > 0, size.height > 0 {
                mapView?.viewRect = CGRect(origin: .zero, size: size)
            }
            registerMarkerStyle()
            // 준비 전 보류된 데이터 반영
            if let pendingLocation { updateLocation(pendingLocation) }
            if let pendingPlaces { renderMarkers(pendingPlaces) }
        }

        func addViewFailed(_ viewName: String, viewInfoName: String) {
            print("🗺️ 지도 뷰 추가 실패: \(viewName)")
        }

        func containerDidResized(_ size: CGSize) {
            mapView?.viewRect = CGRect(origin: .zero, size: size)
        }

        /// SwiftUI 레이아웃 크기로 viewRect 동기화 (초기 찌그러짐 방지)
        func syncViewRect(_ size: CGSize) {
            guard let mapView, size.width > 0, size.height > 0 else { return }
            if mapView.viewRect.size != size {
                mapView.viewRect = CGRect(origin: .zero, size: size)
            }
        }

        // MARK: - 위치

        func updateLocation(_ coordinate: CLLocationCoordinate2D?, follow: Bool = false) {
            guard let coord = coordinate else { return }
            guard let mapView else { pendingLocation = coord; return }
            // follow=false면 최초 1회만, follow=true면 매번 카메라 이동(V09 러닝)
            if !follow {
                guard !didCenterOnUser else { return }
            }
            didCenterOnUser = true
            let point = MapPoint(longitude: coord.longitude, latitude: coord.latitude)
            mapView.moveCamera(CameraUpdate.make(target: point, zoomLevel: 16, mapView: mapView))
        }

        // MARK: - 마커

        func updatePlaces(_ places: [MapPlace]) {
            guard mapView != nil else { pendingPlaces = places; return }
            renderMarkers(places)
        }

        private func registerMarkerStyle() {
            guard let mapView else { return }
            let manager = mapView.getLabelManager()
            let layerOption = LabelLayerOptions(
                layerID: poiLayerID,
                competitionType: .none,
                competitionUnit: .symbolFirst,
                orderType: .rank,
                zOrder: 10_001
            )
            _ = manager.addLabelLayer(option: layerOption)

            let iconStyle = PoiIconStyle(symbol: markerImage(), anchorPoint: CGPoint(x: 0.5, y: 1.0))
            let perLevel = PerLevelPoiStyle(iconStyle: iconStyle, level: 0)
            let poiStyle = PoiStyle(styleID: poiStyleID, styles: [perLevel])
            manager.addPoiStyle(poiStyle)
        }

        private func renderMarkers(_ places: [MapPlace]) {
            guard let mapView else { return }
            let manager = mapView.getLabelManager()
            guard let layer = manager.getLabelLayer(layerID: poiLayerID) else { return }
            layer.clearAllItems()
            for place in places {
                let options = PoiOptions(styleID: poiStyleID)
                options.rank = 0
                let point = MapPoint(longitude: place.longitude, latitude: place.latitude)
                let poi = layer.addPoi(option: options, at: point)
                poi?.show()
            }
            // 첫 마커로 카메라 이동
            if let first = places.first {
                let point = MapPoint(longitude: first.longitude, latitude: first.latitude)
                mapView.moveCamera(CameraUpdate.make(target: point, zoomLevel: 15, mapView: mapView))
            }
        }

        private func markerImage() -> UIImage {
            // 초록 물방울(teardrop) 핀 + 흰 점 (Figma 마커 스타일)
            let green = UIColor(red: 0x13 / 255, green: 0xC6 / 255, blue: 0x74 / 255, alpha: 1)
            let size = CGSize(width: 30, height: 40)
            let r: CGFloat = 13
            let cx = size.width / 2
            let cy = r

            let renderer = UIGraphicsImageRenderer(size: size)
            return renderer.image { _ in
                // 물방울 본체: 위쪽 원 + 아래 꼭지점
                let body = UIBezierPath()
                body.addArc(withCenter: CGPoint(x: cx, y: cy), radius: r,
                            startAngle: .pi * 0.78, endAngle: .pi * 0.22, clockwise: true)
                body.addLine(to: CGPoint(x: cx, y: size.height))
                body.close()
                green.setFill()
                body.fill()

                // 흰 점
                let dotR: CGFloat = 5
                let dot = UIBezierPath(ovalIn: CGRect(x: cx - dotR, y: cy - dotR,
                                                      width: dotR * 2, height: dotR * 2))
                UIColor.white.setFill()
                dot.fill()
            }
        }
    }
}
