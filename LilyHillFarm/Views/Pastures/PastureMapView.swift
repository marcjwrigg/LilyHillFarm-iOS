//
//  PastureMapView.swift
//  LilyHillFarm
//
//  MapKit view for displaying pasture boundaries
//

import SwiftUI
import MapKit

// Tagged overlay types to distinguish between boundary and forage
class BoundaryPolygon: MKPolygon {}
class ForagePolygon: MKPolygon {}

struct PastureMapView: UIViewRepresentable {
    let region: MKCoordinateRegion
    let boundaryPolygon: MKPolygon?
    let foragePolygon: MKPolygon?
    let pastureName: String

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.mapType = .hybrid
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.showsCompass = true
        mapView.showsScale = true

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Set region
        mapView.setRegion(region, animated: false)

        // Remove existing overlays
        mapView.removeOverlays(mapView.overlays)

        // Add boundary polygon (blue outline) - tagged as BoundaryPolygon
        if let boundary = boundaryPolygon {
            let points = boundary.points()
            let coords = UnsafeBufferPointer(start: points, count: boundary.pointCount)
            let coordinates = coords.map { $0.coordinate }
            let taggedBoundary = BoundaryPolygon(coordinates: coordinates, count: coordinates.count)
            mapView.addOverlay(taggedBoundary, level: .aboveLabels)
        }

        // Add forage polygon (green fill) - tagged as ForagePolygon
        if let forage = foragePolygon {
            let points = forage.points()
            let coords = UnsafeBufferPointer(start: points, count: forage.pointCount)
            let coordinates = coords.map { $0.coordinate }
            let taggedForage = ForagePolygon(coordinates: coordinates, count: coordinates.count)
            mapView.addOverlay(taggedForage, level: .aboveLabels)
        }

        // Add center annotation if we have a boundary
        if let boundary = boundaryPolygon {
            let centerCoordinate = boundary.coordinate

            // Remove existing annotations
            mapView.removeAnnotations(mapView.annotations)

            let annotation = MKPointAnnotation()
            annotation.coordinate = centerCoordinate
            annotation.title = pastureName
            mapView.addAnnotation(annotation)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let foragePolygon = overlay as? ForagePolygon {
                // Forage area - green with fill
                let renderer = MKPolygonRenderer(polygon: foragePolygon)
                renderer.fillColor = UIColor.systemGreen.withAlphaComponent(0.3)
                renderer.strokeColor = UIColor.systemGreen
                renderer.lineWidth = 3
                return renderer
            } else if let boundaryPolygon = overlay as? BoundaryPolygon {
                // Total pasture boundary - blue outline only, no fill
                let renderer = MKPolygonRenderer(polygon: boundaryPolygon)
                renderer.fillColor = UIColor.clear
                renderer.strokeColor = UIColor.systemBlue
                renderer.lineWidth = 3
                return renderer
            } else if let polygon = overlay as? MKPolygon {
                // Fallback for regular polygons
                let renderer = MKPolygonRenderer(polygon: polygon)
                renderer.fillColor = UIColor.clear
                renderer.strokeColor = UIColor.blue
                renderer.lineWidth = 2
                return renderer
            }

            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard !(annotation is MKUserLocation) else { return nil }

            let identifier = "PasturePin"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)

            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
            } else {
                annotationView?.annotation = annotation
            }

            if let markerView = annotationView as? MKMarkerAnnotationView {
                markerView.markerTintColor = .blue
                markerView.glyphImage = UIImage(systemName: "mappin.circle.fill")
            }

            return annotationView
        }
    }
}
