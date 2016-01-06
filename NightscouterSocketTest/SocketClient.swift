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
import ReactiveCocoa

public class NightscoutSocketIOClient {
    
    // From ericmarkmartin... RAC integration
    public let sginal: Signal<[AnyObject], NSError>
    
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
    private let socket: SocketIOClient
    private var authorizationJSON: AnyObject {
        // Turn the the authorization dictionary into a JSON object.
        
        var json = JSON([SocketHeader.Client : JSON(SocketValue.ClientMobile), SocketHeader.Secret: JSON(apiSecret ?? "")])
        
        return json.object
    }
    
    private convenience init () {
        self.init(url: NSURL(string: "https://nscgm.herokuapp.com")!)
    }
    
    public init(url: NSURL, apiSecret: String? = nil) {
        
        self.url = url
        self.apiSecret = apiSecret
        
        // Create a socket.io client with a url string.
        self.socket = SocketIOClient(socketURL: url.absoluteString, options: [.Log(false), .ForcePolling(false)])
        
        
        // From ericmarkmartin... RAC integration
        self.sginal = socket.rac_socketSignal()
        
        // Listen to connect.
        socket.on(WebEvents.connect.rawValue) { data, ack in
            print("socket connected")
            self.socket.emit(WebEvents.authorize.rawValue, self.authorizationJSON)
        }
        
        // Listen to disconnect.
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
        
        
        if self.site == nil {
            self.site = Site()
        }
        
        if var site = self.site {
            if let lastUpdated = json[JSONProperty.lastUpdated].int {
                // print(lastUpdated)
                site.milliseconds = lastUpdated
                //site.lastUpdated = NSDate(timeIntervalSince1970: (Double(lastUpdated) / 1000))
            }
            
            if let uploaderBattery = json[JSONProperty.devicestatus][JSONProperty.uploaderBattery].int {
                site.deviceStatus.append(DeviceStatus(uploaderBattery: uploaderBattery, milliseconds: 0))
            }
            
            let deviceStatus = json[JSONProperty.devicestatus]
            
            for (_, subJson) in deviceStatus {
                
                print(subJson.description)
                if let mills = subJson[JSONProperty.mills].int {
                    if let uploaderBattery = subJson[JSONProperty.uploader, JSONProperty.battery].int {
                        site.deviceStatus.append(DeviceStatus(uploaderBattery: uploaderBattery, milliseconds: mills))
                    }
                }
                
                
            }
            
            
            let sgvs = json[JSONProperty.sgvs]
            for (_, subJson) in sgvs {
                if let device = subJson[JSONProperty.device].string, rssi = subJson[JSONProperty.rssi].int, unfiltered = subJson[JSONProperty.unfiltered].int, direction = subJson[JSONProperty.direction].string, filtered = subJson[JSONProperty.filtered].int, noise = subJson[JSONProperty.noise].int, mills = subJson[JSONProperty.mills].int, mgdl = subJson[JSONProperty.mgdl].int {
                    
                    guard let typedNoise = Noise(rawValue: noise) else {
                        let sensorValue = SensorGlucoseValue(device: device, rssi: rssi, unfiltered: unfiltered, direction: direction, filtered: filtered, noise: .Unknown, milliseconds: mills, mgdl: mgdl)
                        site.sgvs.append(sensorValue)
                        return
                    }
                    
                    let sensorValue = SensorGlucoseValue(device: device, rssi: rssi, unfiltered: unfiltered, direction: direction, filtered: filtered, noise: typedNoise , milliseconds: mills, mgdl: mgdl)
                    
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
                if let slope = subJson[JSONProperty.slope].double, intercept = subJson[JSONProperty.intercept].double, scale = subJson[JSONProperty.scale].double, mills = subJson[JSONProperty.mills].int {
                    
                    let calibration = Calibration(slope: slope, intercept: intercept, scale: scale, milliseconds: mills)
                    
                    site.cals.append(calibration)
                    // print(calibration)
                }
            }
            // print(site)
            
            // makes sure things are sorted correctly by date. When delta's come in they might screw up the order.
            site.sgvs = site.sgvs.sort{(item1:SensorGlucoseValue, item2:SensorGlucoseValue) -> Bool in
                item1.date.compare(item2.date) == NSComparisonResult.OrderedDescending
            }
            site.cals = site.cals.sort{(item1:Calibration, item2:Calibration) -> Bool in
                item1.date.compare(item2.date) == NSComparisonResult.OrderedDescending
            }
            site.mbgs = site.mbgs.sort{(item1:MeteredGlucoseValue, item2:MeteredGlucoseValue) -> Bool in
                item1.date.compare(item2.date) == NSComparisonResult.OrderedDescending
            }
            
            
            self.site = site
            
        }
    }
}

// All the JSON keys I saw when parsing the socket.io output for dataUpdate
struct JSONProperty {
    static let lastUpdated = "lastUpdated"
    static let devicestatus = "devicestatus"
    static let uploader = "uploader"
    static let battery = "battery"
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
    static let profiles = "profiles"
    static let treatments = "treatments"
    static let deltaCount = "delta"
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
    var isSGVOk: Bool { get }
}

public extension GlucoseValueHolder {
    public var isSGVOk: Bool {
        return mgdl >= 13
    }
}

public protocol DeviceOwnable {
    var device: String { get }
}

func rawIsigToRawBg(sgValue: SensorGlucoseValue, calValue: Calibration) -> Double {
    
    var raw: Double = 0
    
    let unfiltered = Double(sgValue.unfiltered)
    let filtered = Double(sgValue.filtered)
    let sgv: Double = Double(sgValue.mgdl)//sgValue.sgv.isInteger ? sgValue.sgv : sgValue.sgv.toMgdl
    let slope = calValue.slope
    let scale = calValue.scale
    let intercept = calValue.intercept
    
    if (slope == 0 || unfiltered == 0 || scale == 0) {
        raw = 0;
    } else if (filtered == 0 || sgv < 40) {
        raw = scale * (unfiltered - intercept) / slope
    } else {
        let ratioCalc = scale * (filtered - intercept) / slope
        let ratio = ratioCalc / sgv
        
        let rawCalc = scale * (unfiltered - intercept) / slope
        raw = rawCalc / ratio
    }
    
    return round(raw)
}


public struct DeviceStatus: CustomStringConvertible, Dateable {
    public let uploaderBattery: Int
    public var milliseconds: Int
    public var batteryLevel: String {
        get {
            let numFormatter = NSNumberFormatter()
            
            numFormatter.locale = NSLocale.systemLocale()
            numFormatter.numberStyle = .PercentStyle
            numFormatter.zeroSymbol = "--%"
            
            let precentage = Float(uploaderBattery)/100
            
            return numFormatter.stringFromNumber(precentage ?? 0)!
        }
    }
    
    public var description: String {
        return "{ DeviceStatus: { uploaderBattery: \(uploaderBattery),  batteryLevel: \(batteryLevel) } }"
    }
}

public struct MeteredGlucoseValue: CustomStringConvertible, Dateable, GlucoseValueHolder, DeviceOwnable {
    public let milliseconds: Int
    public let device: String
    public let mgdl: Int
    
    public var description: String {
        return "{ MeteredGlucoseValue: { milliseconds: \(milliseconds),  device: \(device), mgdl: \(mgdl) } }"
    }
}

public struct SensorGlucoseValue: CustomStringConvertible, Dateable, GlucoseValueHolder, DeviceOwnable {
    public let device: String
    public let rssi: Int
    public let unfiltered: Int
    public let direction: String
    public let filtered: Int
    public let noise: Noise
    public let milliseconds: Int
    public let mgdl: Int
    
    public var description: String {
        return "{ SensorGlucoseValue: { device: \(device), mgdl: \(mgdl), date: \(date), direction: \(direction) } }"
    }
}

public struct Calibration: CustomStringConvertible, Dateable {
    public let slope: Double
    public let intercept: Double
    public let scale: Double
    public let milliseconds: Int
    
    public var description: String {
        return "{ Calibration: { slope: \(slope), intercept: \(intercept), scale: \(scale), date: \(date) } }"
    }
}

public enum Noise: Int {
    case None = 0, Clean, Light, Medium, Heavy, Unknown
    
    public init () {
        self = .None
    }
}

public struct Site: Dateable {
    public var sgvs: [SensorGlucoseValue] = []
    public var cals: [Calibration] = []
    public var mbgs: [MeteredGlucoseValue] = []
    public var deviceStatus: [DeviceStatus] = [] //DeviceStatus(uploaderBattery: 0, milliseconds: 0)
    public var milliseconds: Int =  Int(NSDate().timeIntervalSince1970 * 1000)
    //    public var lastUpdated: NSDate = NSDate(timeIntervalSince1970: 0)
}

// Thanks Mike Ash
extension Array {
    subscript (safe index: UInt) -> Element? {
        return Int(index) < count ? self[Int(index)] : nil
    }
}