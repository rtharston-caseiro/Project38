//
//  Commit+CoreDataProperties.swift
//  Project38
//
//  Created by Caseiro Dev on 12/15/23.
//
//

import Foundation
import CoreData


extension Commit {

    @nonobjc public class func createFetchRequest() -> NSFetchRequest<Commit> {
        NSFetchRequest<Commit>(entityName: "Commit")
    }

    @NSManaged public var date: Date?
    @NSManaged public var message: String?
    @NSManaged public var sha: String?
    @NSManaged public var url: String?

}

extension Commit : Identifiable {

}
