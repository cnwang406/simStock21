//
//  coreData.swift
//  simStock21
//
//  Created by peiyu on 2020/6/24.
//  Copyright © 2020 peiyu. All rights reserved.
//

import Foundation
import CoreData

public class coreData {

    static var shared = coreData()

    private init() {} // Prevent clients from creating another instance.

    lazy private var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "simStock21")
        
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
              fatalError("persistentContainer error \(storeDescription) \(error) \(error.userInfo)")
            }
        })
        return container
    }()

    lazy private var mainContext: NSManagedObjectContext = {
        let context = self.persistentContainer.viewContext
        context.automaticallyMergesChangesFromParent = true
        return context
    }()
    

    var context:NSManagedObjectContext {
        if Thread.current == Thread.main {
            return mainContext
        } else {
            let context = persistentContainer.newBackgroundContext()
            return context
        }
    }
    
}


public class Stock: NSManagedObject {
    
    static func fetchRequest (sId:[String]?=nil, sName:[String]?=nil, fetchLimit:Int?=nil) -> NSFetchRequest<Stock> {
        let fetchRequest = NSFetchRequest<Stock>(entityName: "Stock")
        var predicates:[NSPredicate] = []
        if let ids = sId {
            for sId in ids {
                let upperId = (sId == "t00" ? sId : sId.localizedUppercase)
                predicates.append(NSPredicate(format: "sId CONTAINS %@", upperId))
            }
        }
        if let names = sName {
            for sName in names {
                let upperName = sName.localizedUppercase
                predicates.append(NSPredicate(format: "sName CONTAINS %@", upperName))
            }
        }
        let grouping = NSPredicate(format: "group != %@", "")
        //合併以上條件為OR，或不搜尋sId,sName時只查回股群清單（過濾掉不在股群內的上市股）
        if predicates.count > 0 {
            if predicates.count > 1 {
                predicates.append(grouping)
            }
            fetchRequest.predicate = NSCompoundPredicate(type: .or, subpredicates: predicates)
        } else {
            fetchRequest.predicate = grouping
        }
        //固定的排序
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "sName", ascending: true)]

        if let limit = fetchLimit {
            fetchRequest.fetchLimit = limit
        }

        return fetchRequest
    }

    static func fetch (_ context:NSManagedObjectContext, sId:[String]?=nil, sName:[String]?=nil, fetchLimit:Int?=nil) -> [Stock] {
        let fetchRequest = self.fetchRequest(sId: sId, sName: sName, fetchLimit: fetchLimit)
        return (try? context.fetch(fetchRequest)) ?? []
    }

        
    static func new(_ context:NSManagedObjectContext, sId:String, sName:String, group:String?=nil) -> Stock {
        let stock = Stock(context: context)
        stock.sId    = sId
        stock.sName  = sName
//        let pName = String(sName.first ?? Character(""))
//        let prefix = StockPrefix.get(context, pName: pName)
//        stock.prefix = prefix
        if let group = group {
            stock.group = group
        }
        return stock
    }
    
    static func update(_ context:NSManagedObjectContext, sId:String, sName:String?=nil, group:String?=nil) {
        let stocks = fetch(context, sId:[sId])
        if stocks.count == 0 {
            if let sName = sName {
                let _ = new(context, sId: sId, sName: sName, group: group)
            }
        } else {
            for stock in stocks {
                if let sName = sName {
                    stock.sName = sName
//                    let pName = String(sName.first ?? Character(""))
//                    let prefix = StockPrefix.get(context, pName: pName)
//                    stock.prefix = prefix
                }
                if let group = group {
                    stock.group = group
                }
            }
        }
    }

}

extension Stock {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Stock> {
        return NSFetchRequest<Stock>(entityName: "Stock")
    }


    @NSManaged public var sId: String
    @NSManaged public var sName: String
    @NSManaged public var group: String
    
    var prefix:String {
        String(sName.first ?? Character(""))
    }

}

