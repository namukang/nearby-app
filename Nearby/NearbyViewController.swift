//
//  ViewController.swift
//  Nearby
//
//  Created by Dan Kang on 3/10/15.
//  Copyright (c) 2015 Dan Kang. All rights reserved.
//

import UIKit
import Parse
import CoreLocation
import MapKit

class NearbyViewController: UIViewController, PFLogInViewControllerDelegate, CLLocationManagerDelegate, UITableViewDataSource, UITableViewDelegate {

    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var tableView: UITableView!

    let locationManager = CLLocationManager()
    let geocoder = CLGeocoder()
    let nearbyDistance = 150.0
    var refreshControl: UIRefreshControl!

    var userLocation: CLLocation = CLLocation(latitude: 0, longitude: 0) {
        willSet {
            if userLocation.coordinate.latitude == 0 && userLocation.coordinate.longitude == 0 {
                centerAndZoomMapOnCoordinate(newValue.coordinate)
            }
        }
        didSet {
            let timestamp = userLocation.timestamp.timeIntervalSince1970
            let latitude = userLocation.coordinate.latitude
            let longitude = userLocation.coordinate.longitude
            let accuracy = userLocation.horizontalAccuracy
            let location: [String: Double] = [
                "timestamp": timestamp,
                "latitude": latitude,
                "longitude": longitude,
                "accuracy": accuracy
            ]
            let user = PFUser.currentUser()
            user["location"] = location
            user.saveInBackground()
        }
    }

    var nearbyFriends: [PFUser] = [] {
        didSet {
            nearbyFriends.sort({ ($0["name"] as String) < ($1["name"] as String) })

            for friend in nearbyFriends {
                let loc = userLocation(friend)
                let timeAgo = loc.timestamp.shortTimeAgoSinceNow()
                let annotation = MKPointAnnotation()
                annotation.title = friend["name"] as String
                annotation.subtitle = "\(timeAgo) ago"
                annotation.coordinate = loc.coordinate
                self.mapView.addAnnotation(annotation)
            }

            if nearbyFriends.count == 0 {
                let label = UILabel(frame: CGRectMake(0, 0, self.tableView.bounds.size.width, self.tableView.bounds.size.height))
                label.text = "No friends are nearby."
                label.textAlignment = NSTextAlignment.Center
                label.sizeToFit()

                self.tableView.backgroundView = label
                self.tableView.separatorStyle = UITableViewCellSeparatorStyle.None
            } else {
                self.tableView.backgroundView = nil
                self.tableView.separatorStyle = UITableViewCellSeparatorStyle.SingleLine
            }
            self.tableView.reloadData()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        if let user = PFUser.currentUser() {
            startUpdatingLocation()
            getNearbyFriends()
        }
        self.refreshControl = UIRefreshControl()
        self.refreshControl.addTarget(self, action: "getNearbyFriends", forControlEvents: UIControlEvents.ValueChanged)
        self.tableView.addSubview(refreshControl)
    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)

        if PFUser.currentUser() == nil {
            // Create the log in view controller
            let logInController = PFLogInViewController()
            logInController.delegate = self
            logInController.facebookPermissions = ["user_friends"]
            logInController.fields = (PFLogInFields.Facebook)
            // TODO: Handle user denying "user_friends" permission
            // TODO: Handle user cancelling log in

            // Present the log in view controller
            self.presentViewController(logInController, animated: true, completion: nil)
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func startUpdatingLocation() {
        if CLLocationManager.locationServicesEnabled() {
            mapView.showsUserLocation = true

            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
            locationManager.distanceFilter = kCLDistanceFilterNone

            switch CLLocationManager.authorizationStatus() {
            case .AuthorizedAlways:
                locationManager.startUpdatingLocation()
            case .NotDetermined:
                locationManager.requestAlwaysAuthorization()
            case .Restricted, .Denied:
                // TODO: Check if location disabled when the user returns to the app after it's already open
                showLocationDisabledAlert()
            default:
                break
            }
        }
    }

    func getNearbyFriends() {
        PFCloud.callFunctionInBackground("nearbyFriends", withParameters: nil, block: {
            (result, error) in
            self.nearbyFriends = result as [PFUser]
            self.refreshControl?.endRefreshing()
        })
    }

    func showLocationDisabledAlert() {
        let alertController = UIAlertController(
            title: "Background Location Access Disabled",
            message: "In order to be notified about nearby friends, please open this app's settings and set location access to 'Always'.",
            preferredStyle: .Alert)

        let cancelAction = UIAlertAction(title: "Cancel", style: .Cancel, handler: nil)
        alertController.addAction(cancelAction)

        let openAction = UIAlertAction(title: "Open Settings", style: .Default) { (action) in
            if let url = NSURL(string: UIApplicationOpenSettingsURLString) {
                UIApplication.sharedApplication().openURL(url)
            }
        }
        alertController.addAction(openAction)

        self.presentViewController(alertController, animated: true, completion: nil)
    }

    func centerAndZoomMapOnCoordinate(coordinate: CLLocationCoordinate2D) {
        let degree = (nearbyDistance + 50) / 111000.0
        let span = MKCoordinateSpan(latitudeDelta: degree, longitudeDelta: degree)
        let region = MKCoordinateRegion(center: coordinate, span: span)
        mapView.setRegion(region, animated: true)
    }

    func userLocation(user: PFUser) -> CLLocation {
        let loc = user["location"] as [String: Double]
        let coordinate = CLLocationCoordinate2D(latitude: loc["latitude"]!, longitude: loc["longitude"]!)
        let timestamp = NSDate(timeIntervalSince1970: loc["timestamp"]!)
        let horizontalAccuracy = loc["accuracy"]!
        return CLLocation(coordinate: coordinate, altitude: 0, horizontalAccuracy: horizontalAccuracy, verticalAccuracy: 0, timestamp: timestamp)
    }

    // MARK: - PFLogInViewControllerDelegate

    func logInViewController(logInController: PFLogInViewController!, didLogInUser user: PFUser!) {
        self.dismissViewControllerAnimated(true, completion: nil)
        FBRequestConnection.startForMeWithCompletionHandler({ connection, result, error in
            if error == nil {
                let userData = result as [NSObject: AnyObject]
                let name = userData["name"] as String
                let facebookID = userData["id"] as String
                user["name"] = name
                user["fbID"] = facebookID
                user.saveInBackground()
            }
            // TODO: Retry getting user's data at later point if request fails
        })
        startUpdatingLocation()
        getNearbyFriends()
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(manager: CLLocationManager!, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        if status == .AuthorizedAlways {
            locationManager.startUpdatingLocation()
        }
    }

    func locationManager(manager: CLLocationManager!, didUpdateLocations locations: [AnyObject]!) {
        let location = locations.last as CLLocation
        let recent = abs(location.timestamp.timeIntervalSinceNow) < 15.0
        let locationChanged = userLocation.distanceFromLocation(location) > 5
        if recent && locationChanged {
            userLocation = location
        }
    }

    // MARK: - UITableViewDataSource

    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return nearbyFriends.count
    }

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let identifier = "NearbyFriendCell"
        var cell = tableView.dequeueReusableCellWithIdentifier(identifier) as UITableViewCell
        let friend = nearbyFriends[indexPath.row]
        cell.textLabel!.text = friend["name"] as? String

        let loc = userLocation(friend)
        geocoder.reverseGeocodeLocation(loc, completionHandler: { placemarks, error in
            if error == nil {
                let placemark = placemarks[0] as CLPlacemark
                cell.detailTextLabel!.text = placemark.name
            }
        })
        return cell
    }

    // MARK: - UITableViewDelegate

    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let friend = nearbyFriends[indexPath.row]
        let loc = userLocation(friend)
        mapView.setCenterCoordinate(loc.coordinate, animated: true)
        tableView.deselectRowAtIndexPath(indexPath, animated: false)
    }
}

