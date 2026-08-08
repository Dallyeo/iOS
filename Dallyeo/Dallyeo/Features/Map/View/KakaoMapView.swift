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
    /// 경로선(폴리라인) 좌표 — V07/V08 도보경로. 비어있으면 미표시.
    var routePolyline: [CLLocationCoordinate2D] = []
    /// 종류별 마커 (출발/경유/도착/현재위치). 지정 시 place 마커 대신 이걸 표시.
    var markers: [MapMarker] = []

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
        if !markers.isEmpty {
            context.coordinator.updateMarkers(markers)
        } else if showsPlaceMarkers {
            context.coordinator.updatePlaces(places)
        }
        context.coordinator.updateRoute(routePolyline)
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
        private var pendingMarkers: [MapMarker]?
        private var pendingLocation: CLLocationCoordinate2D?
        private var pendingRoute: [CLLocationCoordinate2D]?
        private var didCenterOnUser = false

        private let poiLayerID = "placeLayer"
        private let poiStyleID = "placeMarker"

        // 경로선
        private let routeLayerID = "routeLayer"
        private let routeStyleID = "routeStyleSet"
        private var didRegisterRouteStyle = false
        private var lastRouteSignature = ""

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
            if let pendingMarkers { renderTypedMarkers(pendingMarkers) }
            else if let pendingPlaces { renderMarkers(pendingPlaces) }
            if let pendingRoute { renderRoute(pendingRoute) }
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

            addPoiStyle(manager, styleID: poiStyleID, image: markerImage())

            // 종류별 마커 스타일 (디자인시스템 마커 세트)
            addPoiStyle(manager, styleID: "m_current", image: currentLocationImage())
            addPoiStyle(manager, styleID: "m_start", image: startMarkerImage())
            addPoiStyle(manager, styleID: "m_dest", image: destinationMarkerImage())
            for n in 1...5 {
                // 번호 원은 지점 위 중앙 정렬
                addPoiStyle(manager, styleID: "m_wp\(n)", image: waypointMarkerImage(n),
                            anchor: CGPoint(x: 0.5, y: 0.5))
            }
        }

        private func addPoiStyle(_ manager: LabelManager, styleID: String, image: UIImage,
                                 anchor: CGPoint = CGPoint(x: 0.5, y: 1.0)) {
            let iconStyle = PoiIconStyle(symbol: image, anchorPoint: anchor)
            let perLevel = PerLevelPoiStyle(iconStyle: iconStyle, level: 0)
            manager.addPoiStyle(PoiStyle(styleID: styleID, styles: [perLevel]))
        }

        private func styleID(for kind: MapMarker.Kind) -> String {
            switch kind {
            case .place: return poiStyleID
            case .currentLocation: return "m_current"
            case .start: return "m_start"
            case .destination: return "m_dest"
            case .waypoint(let n): return "m_wp\(min(max(n, 1), 5))"
            }
        }

        // MARK: - 종류별 마커

        func updateMarkers(_ markers: [MapMarker]) {
            guard mapView != nil else { pendingMarkers = markers; return }
            renderTypedMarkers(markers)
        }

        private func renderTypedMarkers(_ markers: [MapMarker]) {
            guard let mapView else { return }
            let manager = mapView.getLabelManager()
            guard let layer = manager.getLabelLayer(layerID: poiLayerID) else { return }
            layer.clearAllItems()
            for marker in markers {
                let options = PoiOptions(styleID: styleID(for: marker.kind))
                options.rank = 0
                let point = MapPoint(longitude: marker.coordinate.longitude, latitude: marker.coordinate.latitude)
                layer.addPoi(option: options, at: point)?.show()
            }
            if let first = markers.first {
                let point = MapPoint(longitude: first.coordinate.longitude, latitude: first.coordinate.latitude)
                mapView.moveCamera(CameraUpdate.make(target: point, zoomLevel: 15, mapView: mapView))
            }
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

        // MARK: - 경로선 (T MAP 폴리라인)

        func updateRoute(_ coords: [CLLocationCoordinate2D]) {
            guard mapView != nil else { pendingRoute = coords; return }
            renderRoute(coords)
        }

        private func registerRouteStyleIfNeeded() {
            guard let mapView, !didRegisterRouteStyle else { return }
            let manager = mapView.getRouteManager()
            _ = manager.addRouteLayer(layerID: routeLayerID, zOrder: 10_000)

            let green = UIColor(red: 0x13 / 255, green: 0xC6 / 255, blue: 0x74 / 255, alpha: 1)
            let perLevel = PerLevelRouteStyle(
                width: 14, color: green,
                strokeWidth: 3, strokeColor: .white, level: 0
            )
            let style = RouteStyle(styles: [perLevel])
            let styleSet = RouteStyleSet(styleID: routeStyleID)
            styleSet.addStyle(style)
            manager.addRouteStyleSet(styleSet)
            didRegisterRouteStyle = true
        }

        private func renderRoute(_ coords: [CLLocationCoordinate2D]) {
            guard let mapView else { return }
            let signature = coords.map { "\($0.latitude),\($0.longitude)" }.joined(separator: "|")
            guard signature != lastRouteSignature else { return }
            lastRouteSignature = signature

            registerRouteStyleIfNeeded()
            let manager = mapView.getRouteManager()
            guard let layer = manager.getRouteLayer(layerID: routeLayerID) else { return }
            layer.clearAllRoutes()
            guard coords.count >= 2 else { return }

            let points = coords.map { MapPoint(longitude: $0.longitude, latitude: $0.latitude) }
            let segment = RouteSegment(points: points, styleIndex: 0)
            let options = RouteOptions(routeID: "route", styleID: routeStyleID, zOrder: 0)
            options.segments = [segment]
            let route = layer.addRoute(option: options)
            route?.show()
        }

        private static let markerGreen = UIColor(red: 0x13 / 255, green: 0xC6 / 255, blue: 0x74 / 255, alpha: 1)

        /// 초록 물방울 핀 + 중앙 글리프(흰색) 그리기 공용 헬퍼
        private func teardropMarker(_ drawGlyph: (_ center: CGPoint, _ radius: CGFloat) -> Void) -> UIImage {
            let size = CGSize(width: 30, height: 40)
            let r: CGFloat = 13
            let center = CGPoint(x: size.width / 2, y: r)
            let renderer = UIGraphicsImageRenderer(size: size)
            return renderer.image { _ in
                let body = UIBezierPath()
                body.addArc(withCenter: center, radius: r,
                            startAngle: .pi * 0.78, endAngle: .pi * 0.22, clockwise: true)
                body.addLine(to: CGPoint(x: center.x, y: size.height))
                body.close()
                Self.markerGreen.setFill()
                body.fill()
                drawGlyph(center, r)
            }
        }

        // 일반 장소 / 현재위치: 흰 점
        private func markerImage() -> UIImage {
            teardropMarker { center, _ in
                let dotR: CGFloat = 5
                UIColor.white.setFill()
                UIBezierPath(ovalIn: CGRect(x: center.x - dotR, y: center.y - dotR,
                                            width: dotR * 2, height: dotR * 2)).fill()
            }
        }

        private func currentLocationImage() -> UIImage { markerImage() }

        // 출발: 흰 내비 화살표(위쪽 삼각형)
        private func startMarkerImage() -> UIImage {
            teardropMarker { center, _ in
                let w: CGFloat = 12, h: CGFloat = 12
                let tri = UIBezierPath()
                tri.move(to: CGPoint(x: center.x, y: center.y - h / 2))          // 꼭짓점(위)
                tri.addLine(to: CGPoint(x: center.x - w / 2, y: center.y + h / 2)) // 좌하
                tri.addLine(to: CGPoint(x: center.x, y: center.y + h / 4))        // 중앙 하단 노치
                tri.addLine(to: CGPoint(x: center.x + w / 2, y: center.y + h / 2)) // 우하
                tri.close()
                UIColor.white.setFill()
                tri.fill()
            }
        }

        // 도착: 흰 깃발
        private func destinationMarkerImage() -> UIImage {
            teardropMarker { center, _ in
                UIColor.white.setStroke()
                UIColor.white.setFill()
                let poleX = center.x - 4.5
                let top = center.y - 6.0
                // 깃대
                let pole = UIBezierPath()
                pole.move(to: CGPoint(x: poleX, y: top))
                pole.addLine(to: CGPoint(x: poleX, y: center.y + 6))
                pole.lineWidth = 1.6
                pole.lineCapStyle = .round
                pole.stroke()
                // 깃발(삼각형)
                let flag = UIBezierPath()
                flag.move(to: CGPoint(x: poleX, y: top))
                flag.addLine(to: CGPoint(x: poleX + 9, y: top + 3))
                flag.addLine(to: CGPoint(x: poleX, y: top + 6))
                flag.close()
                flag.fill()
            }
        }

        // 경유: 26×26 흰 원 + 초록 테두리 + 초록 번호
        private func waypointMarkerImage(_ number: Int) -> UIImage {
            let size = CGSize(width: 26, height: 26)
            let renderer = UIGraphicsImageRenderer(size: size)
            return renderer.image { _ in
                let inset: CGFloat = 1.5
                let rect = CGRect(x: inset, y: inset, width: size.width - inset * 2, height: size.height - inset * 2)
                let circle = UIBezierPath(ovalIn: rect)
                UIColor.white.setFill()
                circle.fill()
                Self.markerGreen.setStroke()
                circle.lineWidth = 2
                circle.stroke()

                let text = "\(number)" as NSString
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 14, weight: .bold),
                    .foregroundColor: Self.markerGreen
                ]
                let ts = text.size(withAttributes: attrs)
                text.draw(at: CGPoint(x: (size.width - ts.width) / 2, y: (size.height - ts.height) / 2),
                          withAttributes: attrs)
            }
        }
    }
}
