//
//  MasterViewController.swift
//  NightscouterSocketTest
//
//  Created by Peter Ina on 1/4/16.
//  Copyright © 2016 Nothingonline. All rights reserved.
//

import UIKit
import Keys

class MasterViewController: UITableViewController {
    
    var detailViewController: DetailTableViewController? = nil
    var objects = [SectionData]()
    
    var timer: NSTimer?
    var socketClient: NightscoutSocketIOClient?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if let split = self.splitViewController {
            let controllers = split.viewControllers
            self.detailViewController = (controllers[controllers.count-1] as! UINavigationController).topViewController as? DetailTableViewController
        }
        
        self.title = "Socket.io Test VC"
        
        
        let keys = NightscoutersockettestKeys()
        
        socketClient = NightscoutSocketIOClient(url: NSURL(string: keys.nightscoutDevSite())!, apiSecret: keys.nightscoutSecretSHA1Key())

        NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("populateDataSource:"), name: ClientNotifications.comNightscouterDataUpdate.rawValue, object: nil)
        
        timer = NSTimer.scheduledTimerWithTimeInterval(30, target: self, selector: "update", userInfo: nil, repeats: true)
        timer?.fire()

        /*
        // From ericmarkmartin... RAC integration
        socketClient?.sginal.observeNext{ data in
            
            // RAW data is returned from the socket... it ins't processed into JSON or a model yet.
            print("mark \(data)")
        }
        */
    }
    
    func update() {
        print("updateTable")
        tableView.reloadData()
    }
    
    override func viewWillAppear(animated: Bool) {
        self.clearsSelectionOnViewWillAppear = self.splitViewController!.collapsed
        super.viewWillAppear(animated)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
        timer?.invalidate()
    }
    
    // MARK: - Segues
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "showDetail" {
            if let indexPath = self.tableView.indexPathForSelectedRow {
                let object = objects[indexPath.row]
                let controller = (segue.destinationViewController as! UINavigationController).topViewController as! DetailTableViewController
                controller.detailItem = object.data
                controller.navigationItem.leftBarButtonItem = self.splitViewController?.displayModeButtonItem()
                controller.navigationItem.leftItemsSupplementBackButton = true
            }
        }
    }
    
    // MARK: - Table View
    
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return objects.count
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("Cell", forIndexPath: indexPath)
        
        if indexPath.row <= 3 {
            cell.accessoryType = .None
        }
        
        let object = objects[indexPath.row]
        cell.textLabel!.text = object.name
        cell.detailTextLabel?.text = object.detail
        return cell
    }
    
    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return false
    }
    
    func populateDataSource(notification: NSNotification) {
        if let client = notification.object as? NightscoutSocketIOClient, site = client.site {
            // print(client.site)
            
            objects.removeAll()
            
            let last = site.date
            let status = site.deviceStatus.first
            
            let sgvs = site.sgvs.map({
                SectionData(name: "\($0.date.timeAgoSinceNow()) : \($0.date)" , detail: "device: \($0.device) mgdl: \($0.mgdl)\nfiltered: \($0.filtered) unfiltered: \($0.unfiltered) direction: \($0.direction)", data: nil)
            })
            let cals = site.cals.map({
                SectionData(name: "\($0.date.timeAgoSinceNow()) : \($0.date)", detail: "intercept: \($0.intercept) scale: \($0.scale) slope: \($0.slope)", data: nil)
            })
            
            let mbgs = site.mbgs.map({
                SectionData(name: "\($0.date.timeAgoSinceNow()) : \($0.date)", detail: "device: \($0.device) mgdl: \($0.mgdl)", data: nil)
            })
            
            var delta: Int = 0
            var raw: Double = 0
            var detail: String = ""
            var lastReading: String = ""
            if let latestSgv = site.sgvs.first {
                
                lastReading = latestSgv.date.timeAgoSinceNow()
                
                if let previousSgv = site.sgvs[safe:1] where latestSgv.isSGVOk {
                    delta = latestSgv.mgdl - previousSgv.mgdl
                }
                if let cal = site.cals.first {
                    raw = rawIsigToRawBg(latestSgv, calValue: cal)
                }
                detail = "\(latestSgv.mgdl) \(latestSgv.direction) -- \(raw) : \(latestSgv.noise)"
            }
            
            let deltaNumberFormat =  NSNumberFormatter()
            deltaNumberFormat.numberStyle = .DecimalStyle
            deltaNumberFormat.positivePrefix = deltaNumberFormat.plusSign
            deltaNumberFormat.negativePrefix = deltaNumberFormat.minusSign
            // deltaNumberFormat.zeroSymbol = "---"
            
            let section0 = SectionData(name: "Battery", detail: String(status!.batteryLevel), data: nil)
            let section1 = SectionData(name: "Last Socket Update", detail: last.timeAgoSinceNow(), data: nil)
            let watchData0 = SectionData(name: "Watchface Data next row...", detail: lastReading, data: nil)
            let watchData = SectionData(name: "\(deltaNumberFormat.stringFromNumber(delta) ?? "---") UNITS", detail: detail, data: nil)
            
            let section2 = SectionData(name: "Sensor Glucose Values", detail: "count \(sgvs.count)", data: sgvs)
            let section3 = SectionData(name: "Calibration Values", detail: "count \(cals.count)", data: cals)
            let section4 = SectionData(name: "Meter Glucose Values", detail: "count \(mbgs.count)", data: mbgs)
            
            objects.appendContentsOf([section0, section1, watchData0, watchData, section2, section3, section4])
            
            self.navigationController?.popToRootViewControllerAnimated(true)
            tableView.reloadData()
        }
    }
}

struct SectionData {
    let name: String
    let detail: String?
    let data: [SectionData]?
}