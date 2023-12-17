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
        let formatter = ISO8601DateFormatter()
        // Get the date of the newest commit, or default to the distant past if no commits were already found
        // If a date was found, add one so it will only fetch commmits _after_ the newest commit date
        let newestCommitDate = getNewestCommitDate()?.addingTimeInterval(1) ?? Date.distantPast
        let since = formatter.string(from: newestCommitDate)
        let commitQuery = URL(string: "https://api.github.com/repos/apple/swift/commits?per_page=100&since=\(since)")!

        if let (data, _) = try? await URLSession.shared.data(from: commitQuery) {
            guard let dataString = String(data: data, encoding: .utf8) else {
                print("URL data was not UTF8")
                return
            }
            
            let jsonCommits = JSON(parseJSON: dataString).arrayValue
            
            print("Received \(jsonCommits.count) new commits.")
            
            for jsonCommit in jsonCommits {
                let authorName = jsonCommit["commit"]["committer"]["name"].stringValue
                let authorEmail = jsonCommit["commit"]["committer"]["email"].stringValue
                
                let author = self.fetchOrCreateAuthor(name: authorName, email: authorEmail)
                
                let sha = jsonCommit["sha"].stringValue
                let message = jsonCommit["commit"]["message"].stringValue
                let url = jsonCommit["html_url"].stringValue
                let date = formatter.date(from: jsonCommit["commit"]["committer"]["date"].stringValue) ?? Date()
                
                self.configureCommit(sha: sha, message: message, url: url, date: date, author: author)
            }
            
            self.saveContext()
            self.loadSavedData()
        } else {
            print("NOTHING HERE")
        }
    }
    
    @MainActor
    func getNewestCommitDate() -> Date? {
        let newestRequest = Commit.createFetchRequest()
        newestRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        newestRequest.fetchLimit = 1
        
        return try? container.viewContext.fetch(newestRequest).first?.date
    }
    
    @MainActor
    private func fetchOrCreateAuthor(name: String, email: String) -> Author {
        // See if the Author already exists
        let authorRequest = Author.createFetchRequest()
        authorRequest.predicate = NSPredicate(format: "name == %@", name)
        
        if let author = try? container.viewContext.fetch(authorRequest).first {
            // we have this author already
            return author
        }
        
        // we didn't find a saved author, so we'll create a new one
        return Author(context: container.viewContext, name: name, email: email)
    }
    
    @MainActor
    private func configureCommit(sha: String, message: String, url: String, date: Date, author: Author) {
        _ = Commit(context: self.container.viewContext, sha: sha, message: message, url: url, date: date, author: author)
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
        // Joe Groff has a website called duriansoftware.com
        ac.addAction(UIAlertAction(title: "Show only Durian commits", style: .default) { [unowned self] _ in
            self.commitPredicate = NSPredicate(format: "author.name == 'Joe Groff'")
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
        cell.detailTextLabel!.text = "By \(commit.author.name) on \(commit.date.description)"
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let vc = storyboard?.instantiateViewController(withIdentifier: "Detail") as? DetailViewController {
            vc.detailItem = commits[indexPath.row]
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let commit = commits[indexPath.row]
            container.viewContext.delete(commit)
            commits.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .fade)
            
            saveContext()
        }
    }
}

