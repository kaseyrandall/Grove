import CoreLocation

/// Turns a catch's coordinates into a friendly place name (a park, landmark, or
/// neighborhood) so a friend can read "Met at Cedar Park" instead of raw numbers.
enum Geocoder {
    static func placeName(latitude: Double, longitude: Double) async -> String? {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        guard let placemark = try? await CLGeocoder().reverseGeocodeLocation(location).first else {
            return nil
        }
        // Prefer the most evocative label available: a named place (park,
        // landmark), then a neighborhood, then the city.
        return placemark.areasOfInterest?.first
            ?? placemark.subLocality
            ?? placemark.locality
            ?? placemark.name
    }
}
