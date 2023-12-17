//
//  Commit+CoreDataClass.swift
//  Project38
//
//  Created by Caseiro Dev on 12/15/23.
//
//

import Foundation
import CoreData

@objc(Commit)
public class Commit: NSManagedObject {
    @MainActor
    convenience init(context: NSManagedObjectContext, sha: String, message: String, url: String, date: Date, author: Author) {
        self.init(context: context)
        self.sha = sha
        self.message = message
        self.url = url
        self.date = date
        self.author = author
    }
}
