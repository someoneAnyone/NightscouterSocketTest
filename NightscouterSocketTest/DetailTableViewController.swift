//
//  DetailTableViewController.swift
//  NightscouterSocketTest
//
//  Created by Peter Ina on 1/5/16.
//  Copyright © 2016 Nothingonline. All rights reserved.
//

import UIKit
import DateTools

class DetailTableViewController: UITableViewController {
    
    var detailItem: [SectionData]? = nil{
        didSet {
            // Update the view.
            tableView.reloadData()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.tableView.estimatedRowHeight = 100
        self.tableView.rowHeight = UITableViewAutomaticDimension
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        self.tableView.reloadData()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - Table view data source
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return detailItem?.count ?? 0
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("reuseIdentifier", forIndexPath: indexPath)
        
        // Configure the cell...
        if let object = detailItem?[indexPath.row] {
            cell.textLabel?.text = object.name
            cell.detailTextLabel?.text = object.detail
        }
        
        return cell
    }
}
