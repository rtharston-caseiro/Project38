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
    var commitPredicate: NSPredicate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Filter",
            style: .plain,
            target: self,
            action: #selector(
                changeFilter
            )
        )
        
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
        request.predicate = commitPredicate
        
        do {
            commits = try container.viewContext.fetch(request)
            print("Got \(commits.count) commits from Core Data")
            tableView.reloadData()
        } catch {
            print("Fetch failed")
        }
    }
    
    @objc func changeFilter() {
        let ac = UIAlertController(title: "Filter commits…", message: nil, preferredStyle: .actionSheet)
        
        ac.addAction(UIAlertAction(title: "Show only fixes", style: .default) { [unowned self] _ in
            self.commitPredicate = NSPredicate(format: "message CONTAINS[c] 'fix'")
            self.loadSavedData()
        })
        ac.addAction(UIAlertAction(title: "Ignore Pull Requests", style: .default) { [unowned self] _ in
            self.commitPredicate = NSPredicate(format: "NOT message BEGINSWITH 'Merge pull request'")
            self.loadSavedData()
        })
        ac.addAction(UIAlertAction(title: "Show only recent", style: .default) { [unowned self] _ in
            let twelveHoursAgo = Date().addingTimeInterval(-43200)
            self.commitPredicate = NSPredicate(format: "date > %@", twelveHoursAgo as NSDate)
            self.loadSavedData()
        })
        ac.addAction(UIAlertAction(title: "Show all commits", style: .default) { [unowned self] _ in
            self.commitPredicate = nil
            self.loadSavedData()
        })
        
        ac.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(ac, animated: true)
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
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        String(commits.count)
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

