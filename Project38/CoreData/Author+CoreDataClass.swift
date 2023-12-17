//
//  Author+CoreDataClass.swift
//  Project38
//
//  Created by Caseiro Dev on 12/16/23.
//
//

import Foundation
import CoreData

@objc(Author)
public class Author: NSManagedObject {
    @MainActor
    convenience init(context: NSManagedObjectContext, name: String, email: String) {
        self.init(context: context)
        self.name = name
        self.email = email
    }
}
