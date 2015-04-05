//
//  User.swift
//  Nearby
//
//  Created by Dan Kang on 4/4/15.
//  Copyright (c) 2015 Dan Kang. All rights reserved.
//

import Foundation
import Parse
import MapKit

class User: PFUser, PFSubclassing {
    override class func initialize() {
        var onceToken: dispatch_once_t = 0;
        dispatch_once(&onceToken) {
            self.registerSubclass()
        }
    }

    @NSManaged var fbId: String
    @NSManaged var name: String
    @NSManaged var location: [String: Double]

    var loc: CLLocation {
        let coordinate = CLLocationCoordinate2D(latitude: location["latitude"]!, longitude: location["longitude"]!)
        let timestamp = NSDate(timeIntervalSince1970: location["timestamp"]!)
        let horizontalAccuracy = location["accuracy"]!
        return CLLocation(coordinate: coordinate, altitude: 0, horizontalAccuracy: horizontalAccuracy, verticalAccuracy: 0, timestamp: timestamp)
    }

    let annotation = MKPointAnnotation()
}