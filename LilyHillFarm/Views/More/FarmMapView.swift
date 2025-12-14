//
//  FarmMapView.swift
//  LilyHillFarm
//
//  Farm-wide map view displaying all pastures with boundaries and labels
//

import SwiftUI
import MapKit
internal import CoreData

struct FarmMapView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Pasture.name, ascending: true)],
        predicate: NSPredicate(format: "deletedAt == nil AND isActive == true"),
        animation: .default)
    private var pastures: FetchedResults<Pasture>

    @State private var region: MKCoordinateRegion?
    @State private var pasturePolygons: [PasturePolygonData] = []
    @State private var showBoundaryLayer = true
    @State private var showForageLayer = true

    var body: some View {
        VStack(spacing: 0) {
            if let region = region, !pasturePolygons.isEmpty {
                ZStack(alignment: .topTrailing) {
                    FarmMapViewRepresentable(
                        region: region,
                        pasturePolygons: pasturePolygons,
                        showBoundaryLayer: showBoundaryLayer,
                        showForageLayer: showForageLayer
                    )
                    .ignoresSafeArea(edges: .bottom)

                    // Layer toggle controls
                    VStack(spacing: 8) {
                        Button(action: { showBoundaryLayer.toggle() }) {
                            HStack(spacing: 6) {
                                Image(systemName: showBoundaryLayer ? "checkmark.square.fill" : "square")
                                    .font(.system(size: 16))
                                Text("Boundary")
                                    .font(.caption)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.white)
                            .cornerRadius(8)
                            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                        }
                        .buttonStyle(.plain)

                        Button(action: { showForageLayer.toggle() }) {
                            HStack(spacing: 6) {
                                Image(systemName: showForageLayer ? "checkmark.square.fill" : "square")
                                    .font(.system(size: 16))
                                Text("Forage")
                                    .font(.caption)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.white)
                            .cornerRadius(8)
                            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding()
                }
            } else if pastures.isEmpty {
                emptyStateView
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "map")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    Text("No pastures with map data")
                        .font(.headline)
                    Text("Add boundary coordinates to pastures to see them on the map")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Farm Map")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            setupMapData()
        }
        .onChange(of: pastures.count) { _ in
            setupMapData()
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "map")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("No Pastures")
                .font(.headline)
            Text("Create pastures to see them on the farm map")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func setupMapData() {
        var polygons: [PasturePolygonData] = []
        var allCoordinates: [CLLocationCoordinate2D] = []

        for pasture in pastures {
            // Parse boundary polygon
            guard let boundaryJSON = pasture.boundaryCoordinates,
                  !boundaryJSON.isEmpty,
                  let polygon = parseGeoJSONPolygon(boundaryJSON) else {
                continue
            }

            // Parse forage polygon if available
            var foragePolygon: MKPolygon? = nil
            if let forageJSON = pasture.forageBoundaryCoordinates,
               !forageJSON.isEmpty {
                foragePolygon = parseGeoJSONPolygon(forageJSON)
            }

            // Extract coordinates from polygon
            let points = polygon.points()
            let coords = UnsafeBufferPointer(start: points, count: polygon.pointCount)
            let coordinates = coords.map { $0.coordinate }
            allCoordinates.append(contentsOf: coordinates)

            // Calculate animal count for this pasture
            let animalFetch: NSFetchRequest<Cattle> = Cattle.fetchRequest()
            animalFetch.predicate = NSPredicate(format: "deletedAt == nil AND location != nil")
            let allCattle = (try? viewContext.fetch(animalFetch)) ?? []
            let animalCount = allCattle.filter { cattle in
                cattle.locationArray.contains(pasture.name ?? "")
            }.count

            let data = PasturePolygonData(
                id: pasture.id ?? UUID(),
                name: pasture.name ?? "Unknown",
                boundaryPolygon: polygon,
                foragePolygon: foragePolygon,
                centerCoordinate: polygon.coordinate,
                totalAcres: pasture.acreage,
                forageAcres: pasture.forageAcres,
                animalCount: animalCount
            )
            polygons.append(data)
        }

        pasturePolygons = polygons

        // Calculate region to fit all pastures
        if !allCoordinates.isEmpty {
            region = calculateRegion(for: allCoordinates)
        }
    }

    private func parseGeoJSONPolygon(_ jsonString: String) -> MKPolygon? {
        guard let jsonData = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let type = json["type"] as? String,
              type == "Polygon",
              let coordinates = json["coordinates"] as? [[[Double]]] else {
            return nil
        }

        // GeoJSON uses [longitude, latitude], MapKit uses CLLocationCoordinate2D(latitude, longitude)
        let outerRing = coordinates.first?.compactMap { coord -> CLLocationCoordinate2D? in
            guard coord.count >= 2 else { return nil }
            return CLLocationCoordinate2D(latitude: coord[1], longitude: coord[0])
        } ?? []

        guard !outerRing.isEmpty else { return nil }

        return MKPolygon(coordinates: outerRing, count: outerRing.count)
    }

    private func calculateRegion(for coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        guard !coordinates.isEmpty else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        }

        var minLat = coordinates[0].latitude
        var maxLat = coordinates[0].latitude
        var minLon = coordinates[0].longitude
        var maxLon = coordinates[0].longitude

        for coord in coordinates {
            minLat = min(minLat, coord.latitude)
            maxLat = max(maxLat, coord.latitude)
            minLon = min(minLon, coord.longitude)
            maxLon = max(maxLon, coord.longitude)
        }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )

        let span = MKCoordinateSpan(
            latitudeDelta: (maxLat - minLat) * 1.3, // Add 30% padding
            longitudeDelta: (maxLon - minLon) * 1.3
        )

        return MKCoordinateRegion(center: center, span: span)
    }
}

// MARK: - Pasture Polygon Data

struct PasturePolygonData: Identifiable {
    let id: UUID
    let name: String
    let boundaryPolygon: MKPolygon
    let foragePolygon: MKPolygon?
    let centerCoordinate: CLLocationCoordinate2D
    let totalAcres: Double
    let forageAcres: Double
    let animalCount: Int
}

// MARK: - Farm Map Representable

struct FarmMapViewRepresentable: UIViewRepresentable {
    let region: MKCoordinateRegion
    let pasturePolygons: [PasturePolygonData]
    let showBoundaryLayer: Bool
    let showForageLayer: Bool

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

        // Remove existing overlays and annotations
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations)

        // Add each pasture's polygons and annotation
        for pastureData in pasturePolygons {
            // Add boundary polygon if enabled
            if showBoundaryLayer {
                let points = pastureData.boundaryPolygon.points()
                let coords = UnsafeBufferPointer(start: points, count: pastureData.boundaryPolygon.pointCount)
                let coordinates = coords.map { $0.coordinate }
                let taggedBoundary = FarmBoundaryPolygon(coordinates: coordinates, count: coordinates.count)
                taggedBoundary.pastureId = pastureData.id
                mapView.addOverlay(taggedBoundary, level: .aboveLabels)
            }

            // Add forage polygon if available and enabled
            if showForageLayer, let foragePolygon = pastureData.foragePolygon {
                let foragePoints = foragePolygon.points()
                let forageCoords = UnsafeBufferPointer(start: foragePoints, count: foragePolygon.pointCount)
                let forageCoordinates = forageCoords.map { $0.coordinate }
                let taggedForage = FarmForagePolygon(coordinates: forageCoordinates, count: forageCoordinates.count)
                taggedForage.pastureId = pastureData.id
                mapView.addOverlay(taggedForage, level: .aboveLabels)
            }

            // Add center annotation with pasture name
            let annotation = PastureAnnotation()
            annotation.coordinate = pastureData.centerCoordinate
            annotation.title = pastureData.name
            annotation.subtitle = String(format: "Total: %.1f ac • Forage: %.1f ac • Animals: %d",
                                        pastureData.totalAcres,
                                        pastureData.forageAcres,
                                        pastureData.animalCount)
            annotation.pastureId = pastureData.id
            annotation.totalAcres = pastureData.totalAcres
            annotation.forageAcres = pastureData.forageAcres
            annotation.animalCount = pastureData.animalCount
            mapView.addAnnotation(annotation)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let foragePolygon = overlay as? FarmForagePolygon {
                // Forage area - green with fill
                let renderer = MKPolygonRenderer(polygon: foragePolygon)
                renderer.fillColor = UIColor.systemGreen.withAlphaComponent(0.3)
                renderer.strokeColor = UIColor.systemGreen
                renderer.lineWidth = 2
                return renderer
            } else if let boundaryPolygon = overlay as? FarmBoundaryPolygon {
                // Pasture boundary - blue outline only, no fill
                let renderer = MKPolygonRenderer(polygon: boundaryPolygon)
                renderer.fillColor = UIColor.clear
                renderer.strokeColor = UIColor.systemBlue
                renderer.lineWidth = 2
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
            guard let pastureAnnotation = annotation as? PastureAnnotation else { return nil }

            let identifier = "PasturePin"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView

            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
            } else {
                annotationView?.annotation = annotation
            }

            annotationView?.markerTintColor = .systemBlue
            annotationView?.glyphImage = UIImage(systemName: "map.fill")
            annotationView?.displayPriority = .required

            return annotationView
        }
    }
}

// MARK: - Tagged Polygon Classes

class FarmBoundaryPolygon: MKPolygon {
    var pastureId: UUID?
}

class FarmForagePolygon: MKPolygon {
    var pastureId: UUID?
}

// MARK: - Pasture Annotation

class PastureAnnotation: NSObject, MKAnnotation {
    var coordinate: CLLocationCoordinate2D = CLLocationCoordinate2D()
    var title: String?
    var subtitle: String?
    var pastureId: UUID?
    var totalAcres: Double = 0
    var forageAcres: Double = 0
    var animalCount: Int = 0
}

#Preview {
    NavigationView {
        FarmMapView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
