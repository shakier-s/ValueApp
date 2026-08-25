import CoreLocation
import Foundation
import UserNotifications

@MainActor
final class ProximityService: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate {
    @Published private(set) var location: CLLocation?
    @Published private(set) var authorization: CLAuthorizationStatus
    @Published var alertsEnabled: Bool {
        didSet { UserDefaults.standard.set(alertsEnabled, forKey: Self.alertsKey) }
    }
    @Published var radiusKilometres: Double {
        didSet { UserDefaults.standard.set(radiusKilometres, forKey: Self.radiusKey); evaluateNearbyDeals() }
    }

    private static let alertsKey = "valueapp.nearbyAlerts"
    private static let radiusKey = "valueapp.nearbyRadius"
    private let manager = CLLocationManager()
    private weak var store: DealStore?

    override init() {
        authorization = manager.authorizationStatus
        alertsEnabled = UserDefaults.standard.bool(forKey: Self.alertsKey)
        radiusKilometres = UserDefaults.standard.object(forKey: Self.radiusKey) as? Double ?? 5
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func connect(to store: DealStore) {
        self.store = store
        if authorization == .authorizedWhenInUse || authorization == .authorizedAlways { manager.startUpdatingLocation() }
    }

    func enableLocation() {
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    func setNearbyAlerts(_ enabled: Bool) async {
        if enabled {
            let granted = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            alertsEnabled = granted == true
            if alertsEnabled { enableLocation(); evaluateNearbyDeals() }
        } else { alertsEnabled = false }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorization = manager.authorizationStatus
        if authorization == .authorizedWhenInUse || authorization == .authorizedAlways { manager.startUpdatingLocation() }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let newest = locations.last else { return }
        location = newest
        store?.updateDistances(from: newest)
        evaluateNearbyDeals()
    }

    func evaluateNearbyDeals() {
        guard alertsEnabled, let store else { return }
        var notified = Set(UserDefaults.standard.stringArray(forKey: "valueapp.notifiedDeals") ?? [])
        for deal in store.activeDeals where deal.distance <= radiusKilometres && !notified.contains(deal.id.uuidString) {
            let content = UNMutableNotificationContent()
            content.title = "Deal nearby at \(deal.merchant)"
            content.body = "\(deal.offerText): \(deal.title)"
            content.sound = .default
            UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "nearby-\(deal.id)", content: content, trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)))
            notified.insert(deal.id.uuidString)
        }
        UserDefaults.standard.set(Array(notified), forKey: "valueapp.notifiedDeals")
    }
}
