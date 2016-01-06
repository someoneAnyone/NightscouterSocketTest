//
//  SocketSignal.swift
//  NightscouterSocketTest
//
//  Created by Eric Martin on 1/5/16.
//  Copyright © 2016 Nothingonline. All rights reserved.
//

import Foundation
import Socket_IO_Client_Swift
import SwiftyJSON
import ReactiveCocoa

//public class SocketSignal {
//    var signal : Signal<>
//    var socketIOClient : SocketIOClient
//    
//    public init() {
//        let (signal, observer) = Signal.pipe()
//        
//    }
//    
//}

public extension SocketIOClient {
    public func rac_socketSignal() -> Signal<[AnyObject], NSError> {
        let (signal, observer) = Signal<[AnyObject], NSError>.pipe()
        
        self.on(WebEvents.connect.rawValue) { data, ack in
            print("socketSignal connected")
            observer.sendNext(data)
        }
        
        self.on(WebEvents.disconnect.rawValue) { data, ack in
            print("socketSignal complete")
            observer.sendCompleted()
        }
        
        self.on(WebEvents.dataUpdate.rawValue) { data, ack in
            print("socketSignal dataUpdate")
            observer.sendNext(data)
        }
        
        return signal
    }
}