//
//  NearbyFriendsManager.swift
//  Nearby
//
//  Created by Dan Kang on 4/7/15.
//  Copyright (c) 2015 Dan Kang. All rights reserved.
//

import Foundation

class NearbyFriendsManager: NSObject {
    static let sharedInstance = NearbyFriendsManager()

    let updateInterval = 30.0
    var updateTimer: NSTimer?
    var lastUpdated: NSDate?

    var nearbyFriends: [User]? {
        didSet {
            nearbyFriends?.sortInPlace({ $0.name < $1.name })
        }
    }

    var bestFriends: [User]? {
        didSet {
            bestFriends?.sortInPlace({ $0.name < $1.name })
        }
    }

    var visibleFriends: [User]? {
        if let nearbyFriends = nearbyFriends, bestFriends = bestFriends {
            return nearbyFriends + bestFriends
        } else {
            return nil
        }
    }

    func updateIfStale() {
        if let lastUpdated = lastUpdated {
            let secondsPassed = abs(lastUpdated.timeIntervalSinceNow)
            if secondsPassed >= updateInterval {
                update()
            }
        } else {
            update()
        }
    }

    func startUpdatingPeriodically() {
        updateTimer?.invalidate()
        updateTimer = NSTimer.scheduledTimerWithTimeInterval(self.updateInterval, target: self, selector: "updateWithTimer:", userInfo: nil, repeats: true)
    }

    func stopUpdatingPeriodically() {
        updateTimer?.invalidate()
    }

    func updateWithTimer(timer: NSTimer) {
        update()
    }

    func updateWithSender(sender: AnyObject) {
        update()
    }

    func update(completion: (() -> Void)? = nil) {
        PFCloud.callFunctionInBackground("nearbyFriends", withParameters: nil) { result, error in
            if let error = error {
                let message = error.userInfo["error"] as! String
                PFAnalytics.trackEvent("error", dimensions:["code": "\(error.code)", "message": message])
            } else {
                if let result = result as? [String: [User]] {
                    self.bestFriends = result["bestFriends"]
                    self.nearbyFriends = result["nearbyFriends"]
                    self.lastUpdated = NSDate()
                    NSNotificationCenter.defaultCenter().postNotificationName(GlobalConstants.NotificationKey.updatedVisibleFriends, object: self)
                    if let completion = completion {
                        completion()
                    }
                }
            }
        }
    }

    func syncFriends(completion: (() -> Void)? = nil) {
        PFCloud.callFunctionInBackground("updateFriends", withParameters: nil) { result, error in
            if let error = error {
                let message = error.userInfo["error"] as! String
                PFAnalytics.trackEvent("error", dimensions:["code": "\(error.code)", "message": message])
            } else {
                if let completion = completion {
                    completion()
                }
            }
        }
    }

    func startUpdates() {
        stopUpdates()
        // Update nearby friends when app becomes active
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "updateIfStale", name: "UIApplicationDidBecomeActiveNotification", object: nil)
        // Update nearby friends periodically when active
        if UIApplication.sharedApplication().applicationState == UIApplicationState.Active {
            update()
            updateTimer = NSTimer.scheduledTimerWithTimeInterval(updateInterval, target: self, selector: "updateWithTimer:", userInfo: nil, repeats: true)
        }
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "startUpdatingPeriodically", name: "UIApplicationDidBecomeActiveNotification", object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "stopUpdatingPeriodically", name: "UIApplicationWillResignActiveNotification", object: nil)
    }

    func stopUpdates() {
        updateTimer?.invalidate()
        NSNotificationCenter.defaultCenter().removeObserver(self, name: "UIApplicationDidBecomeActiveNotification", object: nil)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: "UIApplicationWillResignActiveNotification", object: nil)
    }
}