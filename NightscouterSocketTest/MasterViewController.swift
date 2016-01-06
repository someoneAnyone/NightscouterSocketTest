//
//  MasterViewController.swift
//  NightscouterSocketTest
//
//  Created by Peter Ina on 1/4/16.
//  Copyright © 2016 Nothingonline. All rights reserved.
//

import UIKit

class MasterViewController: UITableViewController {

    var detailViewController: DetailViewController? = nil
    var objects = [SectionData]()


    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        // self.navigationItem.leftBarButtonItem = self.editButtonItem()

        // let addButton = UIBarButtonItem(barButtonSystemItem: .Add, target: self, action: "insertNewObject:")
        // self.navigationItem.rightBarButtonItem = addButton
        if let split = self.splitViewController {
            let controllers = split.viewControllers
            self.detailViewController = (controllers[controllers.count-1] as! UINavigationController).topViewController as? DetailViewController
        }
        
        NightscoutSocketIOClient()
        NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("populateDataSource:"), name: ClientNotifications.comNightscouterDataUpdate.rawValue, object: nil)
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
    }

    func insertNewObject(sender: AnyObject) {
//        objects.insert(NSDate(), atIndex: 0)
//        let indexPath = NSIndexPath(forRow: 0, inSection: 0)
//        self.tableView.insertRowsAtIndexPaths([indexPath], withRowAnimation: .Automatic)
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

        if indexPath.row <= 1 {
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
            print(client.site)
            
            let last = site.lastUpdated
            let status = site.deviceStatus
            
            let sgvs = site.sgvs.map({
                SectionData(name: $0.date.description, detail: "device: \($0.device) mgdl: \($0.mgdl)", data: nil)
            })
            let cals = site.cals.map({
                SectionData(name: $0.date.description, detail: "intercept: \($0.intercept)", data: nil)
            })

            let mbgs = site.mbgs.map({
                SectionData(name: $0.date.description, detail: "mgdl: \($0.mgdl)", data: nil)
            })

            
            
            let section0 = SectionData(name: "Battery", detail: String(status.uploaderBattery), data: nil)
            let section1 = SectionData(name: "Last Update", detail: last.description, data: nil)
            let section2 = SectionData(name: "Sensor Glucose Values", detail: "count: \(sgvs.count)", data: sgvs)
            let section3 = SectionData(name: "Calibration Values", detail: "count: \(cals.count)", data: cals)
            let section4 = SectionData(name: "Meter Glucose Values", detail: "count: \(mbgs.count)", data: mbgs)
            
        objects.appendContentsOf([section0, section1, section2, section3, section4])
            
            tableView.reloadData()
            
        }
    }
    
   
}

struct SectionData {
    let name: String
    let detail: String?
    let data: [SectionData]?
}

