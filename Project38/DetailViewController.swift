//
//  DetailViewController.swift
//  Project38
//
//  Created by Caseiro Dev on 12/15/23.
//

import UIKit

class DetailViewController: UIViewController {
    @IBOutlet weak var detailLabel: UILabel!
    
    var detailItem: Commit?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        if let detailItem {
            detailLabel.text = detailItem.message
//            navigationItem.rightBarButtonItem = UIBarButtonItem(
//                title: "Commit 1/\(detailItem.author.commits.count)",
//                style: .plain,
//                target: self,
//                action: #selector(showAuthorCommits)
//            )
        }
    }
    
    @objc func showAuthorCommits() {
        // TODO: fill this in
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
