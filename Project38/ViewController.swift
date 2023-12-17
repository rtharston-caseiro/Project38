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

    var fetchedResultsController: NSFetchedResultsController<Commit>!
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
            self.saveNewestCommitDate()
            self.loadSavedData()
        } else {
            print("NOTHING HERE")
        }
    }
    
    private static let newestCommitDateKey = "NewestCommitDate"
    
    @MainActor
    func getNewestCommitDate() -> Date? {
        UserDefaults.standard.object(forKey: Self.newestCommitDateKey) as? Date
    }
    
    @MainActor
    func saveNewestCommitDate() {
        let newestRequest = Commit.createFetchRequest()
        newestRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        newestRequest.fetchLimit = 1
        
        if let date = try? container.viewContext.fetch(newestRequest).first?.date {
            UserDefaults.standard.setValue(date, forKey: Self.newestCommitDateKey)
        }
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
        if fetchedResultsController == nil {
            let request = Commit.createFetchRequest()
            let sort = NSSortDescriptor(keyPath: \Commit.author.name, ascending: true)
            request.sortDescriptors = [sort]
            request.fetchBatchSize = 20
            
            fetchedResultsController = NSFetchedResultsController(
                fetchRequest: request,
                managedObjectContext: self.container.viewContext,
                sectionNameKeyPath: "author.name",
                cacheName: nil
            )
            fetchedResultsController.delegate = self
        }
        
        
        fetchedResultsController.fetchRequest.predicate = commitPredicate
        
        do {
            try fetchedResultsController.performFetch()
//            print("Got \(commits.count) commits from Core Data")
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
        if commitPredicate != nil {
            ac.addAction(UIAlertAction(title: "Show all commits", style: .default) { [unowned self] _ in
                self.commitPredicate = nil
                self.loadSavedData()
            })
        }
        
        ac.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(ac, animated: true)
    }
    
    // MARK: - Table view methods
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        fetchedResultsController.sections?.count ?? 0
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        // This was mostly for me for debugging, so I could easily see how many commits are loaded in the app
//        String(fetchedResultsController.sections?[section].numberOfObjects ?? 0)
        
        fetchedResultsController.sections?[section].name
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // This is only called if sections > 0, but I'm using ? just in case
        fetchedResultsController.sections?[section].numberOfObjects ?? 0
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Commit", for: indexPath)
        
        let commit = fetchedResultsController.object(at: indexPath)
        cell.textLabel!.text = commit.message
        cell.detailTextLabel!.text = "By \(commit.author.name) on \(commit.date.description)"
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let vc = storyboard?.instantiateViewController(withIdentifier: "Detail") as? DetailViewController {
            vc.detailItem = fetchedResultsController.object(at: indexPath)
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let commit = fetchedResultsController.object(at: indexPath)
            container.viewContext.delete(commit)
            saveContext()
        }
    }
}

extension ViewController: NSFetchedResultsControllerDelegate {
    func controller(
        _ controller: NSFetchedResultsController<NSFetchRequestResult>,
        didChange anObject: Any,
        at indexPath: IndexPath?,
        for type: NSFetchedResultsChangeType,
        newIndexPath: IndexPath?
    ) {
        switch type {
        case .delete:
            if tableView.numberOfRows(inSection: indexPath!.section) == 1 {
                tableView.deleteSections([indexPath!.section], with: .automatic)
            } else {
                tableView.deleteRows(at: [indexPath!], with: .automatic)
            }
        default:
            break
        }
    }
}
