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

    var commits = [Commit]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        container = NSPersistentContainer(name: "Project38")
        container.loadPersistentStores { storeDescription, error in
//            print("sqlite url: \(String(describing: storeDescription.url))")
            self.container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            
            if let error {
                print("Unresolved error \(error)")
            }
        }
        
        loadSavedData()
        
        Task.detached(priority: .userInitiated) {
            await self.fetchCommits()
        }
    }

    // MARK: - CoreData management

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
            self.loadSavedData()
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
    
    @MainActor
    func loadSavedData() {
        let request = Commit.createFetchRequest()
        let sort = NSSortDescriptor(keyPath: \Commit.date, ascending: false)
        request.sortDescriptors = [sort]
        
        do {
            commits = try container.viewContext.fetch(request)
            print("Got \(commits.count) commits from Core Data")
            tableView.reloadData()
        } catch {
            print("Fetch failed")
        }
    }
    
//    func clearSavedData() {
//        for commit in commits {
//            container.viewContext.delete(commit)
//        }
//    }
    
    // MARK: - Table view methods
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        commits.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Commit", for: indexPath)
        
        let commit = commits[indexPath.row]
        cell.textLabel!.text = commit.message
        cell.detailTextLabel!.text = commit.date?.description
        
        return cell
    }
}

