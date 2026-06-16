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

    func makeUIView(context: Context) -> KMViewContainer {
        let bounds = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.bounds ?? UIScreen.main.bounds
        let container = KMViewContainer(frame: bounds)
        context.coordinator.setup(container: container)
        return container
    }

    func updateUIView(_ container: KMViewContainer, context: Context) {
        context.coordinator.updateLocation(userLocation)
        context.coordinator.updatePlaces(places)
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

        func setup(container: KMViewContainer) {
            controller = KMController(viewContainer: container)
            controller?.delegate = self
            let prepared = controller?.prepareEngine()
            print("🗺️ prepareEngine: \(prepared ?? false)")
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
            print("🗺️ 지도 뷰 추가 성공: \(viewName)")
            mapView = controller?.getView("mapview") as? KakaoMap
        }

        func addViewFailed(_ viewName: String, viewInfoName: String) {
            print("🗺️ 지도 뷰 추가 실패: \(viewName)")
        }

        func containerDidResized(_ size: CGSize) {
            mapView?.viewRect = CGRect(origin: .zero, size: size)
        }

        // MARK: - 업데이트

        func updateLocation(_ coordinate: CLLocationCoordinate2D?) {
            guard let coord = coordinate, let mapView else { return }
            let point = MapPoint(longitude: coord.longitude, latitude: coord.latitude)
            mapView.moveCamera(CameraUpdate.make(target: point, zoomLevel: 15, mapView: mapView))
        }

        func updatePlaces(_ places: [MapPlace]) {
            // TODO: 마커 표시 구현
        }
    }
}
