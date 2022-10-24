//
//  UserLocation.swift
//  proxy_beta
//
//  Created by Erick Verleye on 7/9/22.
//


import Foundation
import SwiftUI
import Combine
import CoreLocation
import Firebase
import FirebaseAuthUI
import FirebaseFirestore
import FirebaseMessaging

/**
 Controls the geofencing around each supported crossing and the sending of local notifications when a user is in range of an event
 */
class UserLocation: NSObject, CLLocationManagerDelegate {
    static let shared = UserLocation()
    
    let db = Firestore.firestore()
    let locationManager: CLLocationManager
    var user: Firebase.User? = nil
    var updateTimestamp: Timestamp = Timestamp.init(date:Date.init(timeIntervalSince1970: TimeInterval(0)))
    var first: Bool = true
    @Published var userLocation: CLLocationCoordinate2D? = nil
    @Published var searchEnabled: Bool = false
    
    override init() {
        locationManager = CLLocationManager()
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
        self.locationManager.requestAlwaysAuthorization()
        self.locationManager.allowsBackgroundLocationUpdates = true
        super.init()
        self.locationManager.delegate = self
    }
    
//    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
//        switch manager.authorizationStatus {
//            case .authorizedAlways :
//                if self.selectedProjects != nil {
//                    for project in self.selectedProjects! {
//                        self.updateProjectGeofences(project: project, register: true)
//                    }
//                }
//            case .notDetermined , .denied , .restricted, .authorizedWhenInUse:
//                if self.selectedProjects != nil {
//                    for project in self.selectedProjects! {
//                        self.updateProjectGeofences(project: project, register: false)
//                    }
//                }
//            default:
//                break
//        }
//    }

//    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
//            if let region = region as? CLCircularRegion {
//                let ts = Timestamp.init()
//                let diff = Date().distance(to: self.enterTimestamp.dateValue())
//                let project = String(region.identifier.split(separator: "*")[0])
//                let crossing = String(region.identifier.split(separator: "*")[1])
//
//                // Sometimes the didEnter will trigger twice so make sure there are at least 30 seconds in between sending local notifications
//                if diff.magnitude > 30 {
//                    let projectCollection = Projects(project_name: project)
//                    self.db.collection(projectCollection.subcollections.REALTIME.path).document(crossing).getDocument(completion: {
//                        crossingData, _ in
//                        print("READ Z")
//                        let state = crossingData?[projectCollection.subcollections.REALTIME.fields.STATE] as? String ?? ""
//                        if state == BLOCKED {
//                            let estWait = crossingData?[projectCollection.subcollections.REALTIME.fields.DURATION_PREDICTION] as? String ?? "N/A"
//                            self.sendLocalNotification(project: project, crossing: crossing, estimatedWait: estWait)
//                        }
//                    })
//                }
//                self.enterTimestamp = ts
//                self.updateLocationFlags(region: region, crossing: Crossing(localFirebaseRep: crossing, appRep: "", project: Project(firebaseRep: project, appRep: "")), flag: true)
//        }
//    }

    func removeRegisteredRegions() {
        for region in self.locationManager.monitoredRegions {
            self.locationManager.stopMonitoring(for: region)
        }
    }
    
    func registerRegionAtLocation(center: CLLocationCoordinate2D, radius: Double, uid: String) {
        // Make sure the devices supports region monitoring.
        if CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) {
            print("ADDING GEOFENCE")
            // Define the geofence region. Use the user's uid so that when the didExitRegion fires the database can be updated
            let region = CLCircularRegion(center: center, radius: radius, identifier: uid)
            region.notifyOnEntry = true
            region.notifyOnExit = true
            self.locationManager.startMonitoring(for: region)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        self.searchEnabled = false
        let uid = region.identifier
        let document = self.db.document("\(Users.name)/\(uid)")
        if let region = region as? CLCircularRegion {
            document.updateData([
                UsersFields.GEOHASH: nil,
                UsersFields.LATITUDE: nil,
                UsersFields.LONGITUDE: nil,
                "Geofence": Timestamp()
            ])
            self.locationManager.stopMonitoring(for: region)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        print("GETTING LOCATION")
        let ts = Timestamp.init()
        let diff = Date().distance(to: self.updateTimestamp.dateValue())
        if let location = locations.first {
            if self.first || (diff * -1) > 1 {
                print("Updating location")
                self.userLocation = location.coordinate
                self.first = false
            }
            else {
                // Wait and retry here, avoid infinite loop
            }
        }
        self.updateTimestamp = ts
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print(error.localizedDescription)
        self.userLocation = nil
    }
                    
}
