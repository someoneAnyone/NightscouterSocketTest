//
//  SocketClient.swift
//  NightscouterSocketTest
//
//  Created by Peter Ina on 1/4/16.
//  Copyright © 2016 Nothingonline. All rights reserved.
//

import Foundation
import Socket_IO_Client_Swift
import SwiftyJSON
import Keys

public class NightscoutSocketIOClient {
    
    public var url: NSURL!
    public var site: Site? {
        didSet {
            if let _ = site {
                NSOperationQueue.mainQueue().addOperationWithBlock({ () -> Void in
                    NSNotificationCenter.defaultCenter().postNotificationName(ClientNotifications.comNightscouterDataUpdate.rawValue, object: self)
                })
            }
        }
    }
    private var apiSecret: String?
    private let authorizationDictionary: [String : AnyObject]
    private let socket: SocketIOClient
    private var authorizationJSON: String? {
        // Turn the the authorization dictionary into a JSON object.
        guard let jsonData = try? NSJSONSerialization.dataWithJSONObject(self.authorizationDictionary, options: NSJSONWritingOptions()) else {
            return nil
        }
        
        return String(data: jsonData, encoding: NSUTF8StringEncoding)
    }
    
    public convenience init () {
        // This project uses cocoapods-keys to store secrets.
        // Get all the keys.
         let keys = NightscoutersockettestKeys()

        self.init(url: NSURL(string: keys.nightscoutTestSite())!, apiSecret: keys.nightscoutSecretSHA1Key())
    }
    
    public init(url: NSURL, apiSecret: String? = nil) {
        
        self.url = url
        self.apiSecret = apiSecret
        
        // Create a dictionary for authorization.
        self.authorizationDictionary = [SocketHeader.Client: SocketValue.ClientMobile, SocketHeader.Secret: apiSecret ?? ""]
        
        // Create a socket.io client with a url string.
        self.socket = SocketIOClient(socketURL: url.absoluteString, options: [.Log(false), .ForcePolling(false)])
        
        // Listen to connect
        socket.on(WebEvents.connect.rawValue) { data, ack in
            print("socket connected")
            self.socket.emit(WebEvents.authorize.rawValue, self.authorizationJSON ?? "{}")
        }
        
        // Listen to disconnect
        socket.on(WebEvents.disconnect.rawValue) { data, ack in
            print("socket disconnect")
        }
        
        // Listen to data update.
        socket.on(WebEvents.dataUpdate.rawValue) { data, ack in
            print("socket dataUpdate")
            // Create a JSON object using SwiftyJSON
            let json = JSON(data[0])
            // Process the JSON into structs... add to arrays and what not.
            self.processJSON(json)
        }
        
        // Start up the whole thing.
        socket.connect()
    }
    
    deinit {
        socket.close()
    }
}

// Extending the VC, but all of this should be in a data store of some kind.
extension NightscoutSocketIOClient {
    func processJSON(json: JSON) {
        
        var site = Site()
        
        if let lastUpdated = json[JSONProperty.lastUpdated].int {
            // print(lastUpdated)
            site.lastUpdated = NSDate(timeIntervalSince1970: (Double(lastUpdated) / 1000))
            
        }
        if let uploaderBattery = json[JSONProperty.devicestatus][JSONProperty.uploaderBattery].int {
            // print(uploaderBattery)
            site.deviceStatus = DeviceStatus(uploaderBattery: uploaderBattery)
        }
        
        let sgvs = json[JSONProperty.sgvs]
        for (_, subJson) in sgvs {
            if let device = subJson[JSONProperty.device].string, rssi = subJson[JSONProperty.rssi].int, unfiltered = subJson[JSONProperty.unfiltered].int, direction = subJson[JSONProperty.direction].string, filtered = subJson[JSONProperty.filtered].int, noise = subJson[JSONProperty.noise].int, mills = subJson[JSONProperty.mills].int, mgdl = subJson[JSONProperty.mgdl].int {
                
                let sensorValue = SensorGlucoseValue(device: device, rssi: rssi, unfiltered: unfiltered, direction: direction, filtered: filtered, noise: noise, milliseconds: mills, mgdl: mgdl)
                
                site.sgvs.append(sensorValue)
                // print(sensorValue)
            }
        }
        
        let mbgs = json[JSONProperty.mbgs]
        for (_, subJson) in mbgs {
            if let device = subJson[JSONProperty.device].string, mills = subJson[JSONProperty.mills].int, mgdl = subJson[JSONProperty.mgdl].int {
                
                let meter = MeteredGlucoseValue(milliseconds: mills, device: device, mgdl: mgdl)
                site.mbgs.append(meter)
                // print(meter)
            }
        }
        
        let cals = json[JSONProperty.cals]
        for (_, subJson) in cals {
            if let slope = subJson[JSONProperty.slope].double, intercept = subJson[JSONProperty.intercept].double, scale = subJson[JSONProperty.scale].int, mills = subJson[JSONProperty.mills].int {
                
                let calibration = Calibration(slope: slope, intercept: intercept, scale: scale, milliseconds: mills)
                
                site.cals.append(calibration)
                // print(calibration)
            }
        }
        // print(site)
        self.site = site
    }
}

// All the JSON keys I saw when parsing the socket.io output for dataUpdate
struct JSONProperty {
    static let lastUpdated = "lastUpdated"
    static let devicestatus = "devicestatus"
    static let sgvs = "sgvs"
    static let mbgs = "mbgs"
    static let cals = "cals"
    static let slope = "slope"
    static let intercept = "intercept"
    static let scale = "scale"
    static let mills = "mills"
    static let mgdl = "mgdl"
    static let uploaderBattery = "uploaderBattery"
    static let device = "device"
    static let rssi = "rssi"
    static let filtered = "filtered"
    static let unfiltered = "unfiltered"
    static let direction = "direction"
    static let noise = "noise"
}

public enum ClientNotifications: String {
    case comNightscouterDataUpdate
}

// Data events that I'm aware of.
enum WebEvents: String {
    case dataUpdate
    case connect
    case disconnect
    case authorize
}

// Header strings
struct SocketHeader {
    static let Client = "client"
    static let Secret = "secret"
}

// Header values (strings)
struct SocketValue {
    static let ClientMobile = "mobile"
}


// MARK: - Things that would be in a framework... Common data structures, models, etc...

public protocol Dateable {
    var milliseconds: Int { get }
}

public extension Dateable {
    public var date: NSDate {
        return NSDate(timeIntervalSince1970: (Double(milliseconds) / 1000))
    }
}

public protocol GlucoseValueHolder {
    var mgdl: Int { get }
}

public protocol DeviceOwnable {
    var device: String { get }
}

public struct DeviceStatus: CustomStringConvertible {
    let uploaderBattery: Int
    
    public var description: String {
        return "DeviceStatus - Battery: \(uploaderBattery)"
    }
}

public struct MeteredGlucoseValue: CustomStringConvertible, Dateable, GlucoseValueHolder, DeviceOwnable {
    public let milliseconds: Int
    public let device: String
    public let mgdl: Int
    
    public var description: String {
        return "MeteredGlucoseValue - Device: \(device), mg/dL: \(mgdl) Date: \(date)"
    }
}

public struct SensorGlucoseValue: CustomStringConvertible, Dateable, GlucoseValueHolder, DeviceOwnable {
    public let device: String
    public let rssi: Int
    public let unfiltered: Int
    public let direction: String
    public let filtered: Int
    public let noise: Int
    public let milliseconds: Int
    public let mgdl: Int
    
    public var description: String {
        return "SensorGlucoseValue - Device: \(device), mg/dL: \(mgdl), Date: \(date), Direction: \(direction)"
    }

}

public struct Calibration: CustomStringConvertible, Dateable {
    public let slope: Double
    public let intercept: Double
    public let scale: Int
    public let milliseconds: Int
    
    public var description: String {
        return "Calibration - Slope: \(slope), intercept: \(intercept), scale: \(scale), Date: \(date)"
    }

}

public struct Site {
    public var sgvs: [SensorGlucoseValue] = []
    public var cals: [Calibration] = []
    public var mbgs: [MeteredGlucoseValue] = []
    public var deviceStatus: DeviceStatus = DeviceStatus(uploaderBattery: 0)
    public var lastUpdated: NSDate = NSDate(timeIntervalSince1970: 0)
}