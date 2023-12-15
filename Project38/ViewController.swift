//
//  ViewController.swift
//  Project38
//
//  Created by Caseiro Dev on 12/14/23.
//

import CoreData
import UIKit

import SwiftyJSON

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
        
        Task.detached(priority: .userInitiated) {
            await self.fetchCommits()
        }
    }

    @MainActor
    func saveContext() {
        if container.viewContext.hasChanges {
            do {
                try container.viewContext.save()
            } catch {
                print("An error occurred while saving: \(error)")
            }
        }
    }
    
    func fetchCommits() async {
        let commitQuery = URL(string: "https://api.github.com/repos/apple/swift/commits?per_page=100")!

        if let (data, _) = try? await URLSession.shared.data(from: commitQuery) {
            guard let dataString = String(data: data, encoding: .utf8) else {
                print("URL data was not UTF8")
                return
            }
            
            let jsonCommits = JSON(parseJSON: dataString).arrayValue
            
            print("Received \(jsonCommits.count) new commits.")
            
            let formatter = ISO8601DateFormatter()
            for jsonCommit in jsonCommits {
                let sha = jsonCommit["sha"].stringValue
                let message = jsonCommit["commit"]["message"].stringValue
                let url = jsonCommit["html_url"].stringValue
                let date = formatter.date(from: jsonCommit["commit"]["committer"]["date"].stringValue) ?? Date()
                
                self.configureCommit(sha: sha, message: message, url: url, date: date)
            }
            
            self.saveContext()
        }
    }
    
    @MainActor
    private func configureCommit(sha: String, message: String, url: String, date: Date) {
        let commit = Commit(context: self.container.viewContext)
        
        commit.sha = sha
        commit.message = message
        commit.url = url
        commit.date = date
    }
}

