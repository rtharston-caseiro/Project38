//
//  ViewController.swift
//  Project38
//
//  Created by Caseiro Dev on 12/14/23.
//

import CoreData
import UIKit

class ViewController: UITableViewController {
    var container: NSPersistentContainer!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        container = NSPersistentContainer(name: "Project38")
        container.loadPersistentStores { storeDescription, error in
//            print("sqlite url: \(String(describing: storeDescription.url))")
            if let error {
                print("Unresolved error \(error)")
            }
        }
    }

    func saveContext() {
        if container.viewContext.hasChanges {
            do {
                try container.viewContext.save()
            } catch {
                print("An error occurred while saving: \(error)")
            }
        }
    }
}

