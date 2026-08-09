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
    /// 종류별 마커 (출발/경유/도착/현재위치). place 마커와 별도 레이어라 동시 표시된다.
    var markers: [MapMarker] = []
    /// 지정 시 이 좌표들이 모두 보이도록 카메라를 최초 1회 맞춘다 (V08 코스 전체 보기).
    /// 비어 있으면 기존 동작(첫 마커 기준 고정 줌) 유지.
    var fitCoordinates: [CLLocationCoordinate2D] = []
    /// 지도 하단이 바텀시트에 가려지는 높이(pt). 영역 맞춤 시 그만큼 보정한다.
    var fitBottomInset: CGFloat = 0
    /// 지도 상단이 상태바/다이나믹 아일랜드에 가려지는 높이(pt).
    var fitTopInset: CGFloat = 0

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
        // 영역 맞춤을 쓰면 마커별 카메라 이동은 하지 않는다 (서로 밀어내는 것 방지)
        context.coordinator.usesFitBounds = !fitCoordinates.isEmpty
        context.coordinator.updateLocation(userLocation, follow: followsUser)
        if !markers.isEmpty {
            context.coordinator.updateMarkers(markers)
        }
        if showsPlaceMarkers {
            context.coordinator.updatePlaces(places)
        }
        context.coordinator.updateRoute(routePolyline)
        context.coordinator.updateFitBounds(fitCoordinates,
                                            topInset: fitTopInset,
                                            bottomInset: fitBottomInset)
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
        private var pendingFit: [CLLocationCoordinate2D]?
        private var pendingFitInset: CGFloat = 0
        private var pendingFitTopInset: CGFloat = 0
        private var didCenterOnUser = false
        /// 마지막으로 맞춘 (좌표 집합 + 하단 가림 높이). 값이 바뀌면 다시 맞춘다.
        /// 카드 내용이 로드되며 패널 높이가 커지므로 1회성으로 두면 첫(작은) 높이에 갇힌다.
        private var lastFitKey: String?
        /// true면 render*가 카메라를 옮기지 않고 `updateFitBounds`에 맡긴다.
        var usesFitBounds = false

        private let poiLayerID = "placeLayer"
        private let poiStyleID = "placeMarker"
        /// 출발/경유/도착 마커 전용 레이어. place 마커와 분리해야 둘이 서로를 지우지 않는다.
        private let typedLayerID = "typedLayer"

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
            if let pendingPlaces { renderMarkers(pendingPlaces) }
            if let pendingRoute { renderRoute(pendingRoute) }
            if let pendingFit {
                updateFitBounds(pendingFit,
                                topInset: pendingFitTopInset,
                                bottomInset: pendingFitInset)
            }
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
            // 장소 마커는 서로/코스마커와 경쟁시켜 겹칠 때 하나만 그린다.
            // (코스 근방 검색은 반경이 겹쳐 마커가 수십 개씩 쌓인다)
            _ = manager.addLabelLayer(option: LabelLayerOptions(
                layerID: poiLayerID,
                competitionType: .upperSame,
                competitionUnit: .symbolFirst,
                orderType: .rank,
                zOrder: 10_001
            ))
            // 코스 지점 마커는 주변 장소 마커보다 위에
            _ = manager.addLabelLayer(option: LabelLayerOptions(
                layerID: typedLayerID,
                competitionType: .none,
                competitionUnit: .symbolFirst,
                orderType: .rank,
                zOrder: 10_002
            ))

            // 디자인시스템 마커 에셋(SVG). 물방울은 팁이 하단이라 anchor y≈0.95.
            let tip = CGPoint(x: 0.5, y: 0.95)
            addPoiStyle(manager, styleID: poiStyleID, image: asset("marker_pin"), anchor: tip)
            addPoiStyle(manager, styleID: "m_place_attraction", image: asset("marker_attraction"), anchor: tip)
            // 음식점 전용 마커는 디자인에 없음 → 중립 pin (임의 매핑 안 함)
            addPoiStyle(manager, styleID: "m_place_restaurant", image: asset("marker_pin"), anchor: tip)
            addPoiStyle(manager, styleID: "m_place_convenience", image: asset("marker_convenience"), anchor: tip)
            addPoiStyle(manager, styleID: "m_current", image: asset("marker_pin"), anchor: tip)
            addPoiStyle(manager, styleID: "m_start", image: asset("marker_start"), anchor: tip)
            addPoiStyle(manager, styleID: "m_dest", image: asset("marker_destination"), anchor: tip)
            for n in 1...5 {
                // 번호 원은 지점 위 중앙 정렬
                addPoiStyle(manager, styleID: "m_wp\(n)", image: waypointMarkerImage(n),
                            anchor: CGPoint(x: 0.5, y: 0.5))
            }
        }

        /// 마커 에셋 로드 (없으면 코드 렌더 폴백)
        private func asset(_ name: String) -> UIImage {
            UIImage(named: name) ?? markerImage()
        }

        private func placeStyleID(for category: PlaceCategory) -> String {
            category == .restaurant ? "m_place_restaurant" : "m_place_attraction"
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
            guard let layer = manager.getLabelLayer(layerID: typedLayerID) else { return }
            layer.clearAllItems()
            for marker in markers {
                let options = PoiOptions(styleID: styleID(for: marker.kind))
                options.rank = 0
                let point = MapPoint(longitude: marker.coordinate.longitude, latitude: marker.coordinate.latitude)
                layer.addPoi(option: options, at: point)?.show()
            }
            guard !usesFitBounds, let first = markers.first else { return }
            let point = MapPoint(longitude: first.coordinate.longitude, latitude: first.coordinate.latitude)
            mapView.moveCamera(CameraUpdate.make(target: point, zoomLevel: 15, mapView: mapView))
        }

        // MARK: - 카메라 영역 맞춤

        /// 좌표들이 모두 보이도록 최초 1회 카메라를 맞춘다.
        /// `bottomInset`(pt)만큼 하단이 가려진다고 보고 그만큼 남쪽으로 영역을 넓혀
        /// 코스가 가려지지 않은 위쪽 영역에 오도록 한다.
        func updateFitBounds(_ coords: [CLLocationCoordinate2D],
                             topInset: CGFloat, bottomInset: CGFloat) {
            guard !coords.isEmpty else { return }
            guard let mapView else {
                pendingFit = coords
                pendingFitTopInset = topInset
                pendingFitInset = bottomInset
                return
            }
            // 패널 높이는 1pt 단위 변화로도 갱신되므로 10pt 단위로 뭉쳐 불필요한 재맞춤을 막는다.
            let key = "\(coords.count)|\(coords[0].latitude),\(coords[0].longitude)"
                + "|\(coords[coords.count - 1].latitude)"
                + "|\(Int(topInset / 10))|\(Int(bottomInset / 10))"
            guard key != lastFitKey else { return }
            lastFitKey = key

            guard coords.count > 1 else {
                let p = MapPoint(longitude: coords[0].longitude, latitude: coords[0].latitude)
                mapView.moveCamera(CameraUpdate.make(target: p, zoomLevel: 15, mapView: mapView))
                return
            }

            var minLat = coords[0].latitude, maxLat = minLat
            var minLng = coords[0].longitude, maxLng = minLng
            for c in coords {
                minLat = min(minLat, c.latitude);  maxLat = max(maxLat, c.latitude)
                minLng = min(minLng, c.longitude); maxLng = max(maxLng, c.longitude)
            }

            // 마커가 화면 가장자리에 붙어 잘리지 않도록 여백. 아주 짧은 코스는 최소값 적용.
            let latPad = max((maxLat - minLat) * 0.15, 0.0008)
            let lngPad = max((maxLng - minLng) * 0.15, 0.0008)
            minLat -= latPad; maxLat += latPad
            minLng -= lngPad; maxLng += lngPad

            // 가려지는 만큼 바깥으로 확장해 코스가 실제로 보이는 영역에 들어오게 한다.
            let height = mapView.viewRect.height
            let visible = height - topInset - bottomInset
            if visible > 0, topInset + bottomInset > 0 {
                let span = maxLat - minLat
                minLat -= span * bottomInset / visible
                maxLat += span * topInset / visible
            }

            mapView.moveCamera(CameraUpdate.make(area: AreaRect(
                southWest: MapPoint(longitude: minLng, latitude: minLat),
                northEast: MapPoint(longitude: maxLng, latitude: maxLat)
            )))
        }

        private func renderMarkers(_ places: [MapPlace]) {
            guard let mapView else { return }
            let manager = mapView.getLabelManager()
            guard let layer = manager.getLabelLayer(layerID: poiLayerID) else { return }
            layer.clearAllItems()
            // 앞쪽(가까운) 장소일수록 rank를 높여 경쟁에서 살아남게 한다.
            for (index, place) in places.enumerated() {
                let options = PoiOptions(styleID: placeStyleID(for: place.category))
                options.rank = Int(max(0, places.count - index))
                let point = MapPoint(longitude: place.longitude, latitude: place.latitude)
                let poi = layer.addPoi(option: options, at: point)
                poi?.show()
            }
            // 첫 마커로 카메라 이동 (영역 맞춤 사용 시에는 건너뜀)
            guard !usesFitBounds, let first = places.first else { return }
            let point = MapPoint(longitude: first.longitude, latitude: first.latitude)
            mapView.moveCamera(CameraUpdate.make(target: point, zoomLevel: 15, mapView: mapView))
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
