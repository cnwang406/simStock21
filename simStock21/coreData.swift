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
            if predicates.count > 1 { //只查sId時回傳就是該股即使不在股群內
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
    
    static func new(_ context:NSManagedObjectContext, sId:String, sName:String?=nil, group:String?=nil) -> Stock {
        let stocks = fetch(context, sId:[sId])
        if stocks.count == 0 {
            let stock = Stock(context: context)
            stock.sId    = sId
            stock.sName  = sName ?? sId
            stock.group = group ?? ""
            return stock
        } else {
            for (index,stock) in stocks.enumerated() {
                if let sName = sName {
                    stock.sName = sName
                }
                if let group = group {
                    stock.group = group
                }
                if index > 0 {
                    NSLog("\(stock.sId)\(stock.sName)\t重複\(index)???")
                }
            }
        }
        return stocks[0]

    }
    
    var context:NSManagedObjectContext {
        return self.managedObjectContext ?? coreData.shared.context
    }
    
    func save() {
        DispatchQueue.main.async {
            try? self.context.save()
        }        
    }


//}
//
//extension Stock {
//
//    @nonobjc public class func fetchRequest() -> NSFetchRequest<Stock> {
//        return NSFetchRequest<Stock>(entityName: "Stock")
//    }


    @NSManaged public var sId: String
    @NSManaged public var sName: String
    @NSManaged public var group: String
    @NSManaged public var dateFirst: Date   //歷史價格起始
    @NSManaged public var dateStart: Date   //模擬交易起始
    @NSManaged public var moneyBase: Double     //每次投入本金額度
    @NSManaged public var stockTrades: NSSet?
    
    
    var prefix:String {
        String(sName.first ?? Character(""))
    }
    
    var trades:[Trade] {    //只給swiftui用的
        let context = self.managedObjectContext ?? coreData.shared.context
        return Trade.fetch(context, stock: self, asc: false)
    }
    
    func firstTrade(_ context:NSManagedObjectContext) -> Trade? {
        let trades = Trade.fetch(context, stock: self, fetchLimit: 1, asc: true)
        return trades.first
    }
    
    func lastTrade(_ context:NSManagedObjectContext) -> Trade? {
        let trades = Trade.fetch(context, stock: self, fetchLimit: 1, asc: false)
        return trades.first
    }

    
    
//    @objc(addTradeObject:)
//    @NSManaged public func addToTrade(_ value: Trade)
//
//    @objc(removeTradeObject:)
//    @NSManaged public func removeFromTrade(_ value: Trade)
//
//    @objc(addTrade:)
//    @NSManaged public func addToTrade(_ values: NSSet)
//
//    @objc(removeTrade:)
//    @NSManaged public func removeFromTrade(_ values: NSSet)

}

@objc(Trade)
public class Trade: NSManagedObject {
    static func fetchRequest (stock:Stock, fetchLimit:Int?=nil, asc:Bool=false) -> NSFetchRequest<Trade> {
        let fetchRequest = NSFetchRequest<Trade>(entityName: "Trade")
        fetchRequest.predicate = NSPredicate(format: "stock == %@", stock)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "dateTime", ascending: asc)]
        if let limit = fetchLimit {
            fetchRequest.fetchLimit = limit
        }
        return fetchRequest
    }
    
    static func fetch (_ context:NSManagedObjectContext, stock:Stock, fetchLimit:Int?=nil, asc:Bool=false) -> [Trade] {
        let fetchRequest = self.fetchRequest(stock: stock, fetchLimit: fetchLimit, asc: asc)
        return (try? context.fetch(fetchRequest)) ?? []
    }

//    static func new(_ context:NSManagedObjectContext, stock:Stock, dateTime:Date) -> Trade {
//        let trade = Trade(context: context)
//        trade.stock = stock
//        trade.dateTime = dateTime
//        return trade
//    }

//}
//
//extension Trade {
//
//    @nonobjc public class func fetchRequest() -> NSFetchRequest<Trade> {
//        return NSFetchRequest<Trade>(entityName: "Trade")
//    }

    @NSManaged public var dateTime: Date
    @NSManaged public var priceClose: Double
    @NSManaged public var priceHigh: Double
    @NSManaged public var priceLow: Double
    @NSManaged public var priceOpen: Double
    @NSManaged public var rollAmtCost: Double
    @NSManaged public var rollAmtProfit: Double
    @NSManaged public var rollAmtRoi: Double
    @NSManaged public var rollDays: Double
    @NSManaged public var rollRounds: Double
    @NSManaged public var simAmtBalance: Double
    @NSManaged public var simAmtCost: Double
    @NSManaged public var simAmtProfit: Double
    @NSManaged public var simAmtRoi: Double
    @NSManaged public var simDays: Double
    @NSManaged public var simInvestTimes: Double
    @NSManaged public var simQtyBuy: Double
    @NSManaged public var simQtyInventory: Double
    @NSManaged public var simQtySell: Double
    @NSManaged public var simUnitCost: Double
    @NSManaged public var simUnitIncome: Double
    @NSManaged public var simUpdated: Bool
    @NSManaged public var tKdD: Double
    @NSManaged public var tKdJ: Double
    @NSManaged public var tKdK: Double
    @NSManaged public var tKdKZ125: Double
    @NSManaged public var tKdKZ250: Double
    @NSManaged public var tKdKZ375: Double
    @NSManaged public var tMa20: Double
    @NSManaged public var tMa20Days: Double
    @NSManaged public var tMa20Diff: Double
    @NSManaged public var tMa20DiffMax9: Double
    @NSManaged public var tMa20DiffMin9: Double
    @NSManaged public var tMa60: Double
    @NSManaged public var tMa60Days: Double
    @NSManaged public var tMa60Diff: Double
    @NSManaged public var tMa60DiffMax9: Double
    @NSManaged public var tMa60DiffMin9: Double
    @NSManaged public var tMa60DiffZ125: Double
    @NSManaged public var tMa60DiffZ250: Double
    @NSManaged public var tMa60DiffZ375: Double
    @NSManaged public var tOsc: Double
    @NSManaged public var tOscEma12: Double
    @NSManaged public var tOscEma26: Double
    @NSManaged public var tOscMacd9: Double
    @NSManaged public var tOscMax9: Double
    @NSManaged public var tOscMin9: Double
    @NSManaged public var tOscZ125: Double
    @NSManaged public var tOscZ250: Double
    @NSManaged public var tOscZ375: Double
    @NSManaged public var tSource: String
    @NSManaged public var tUpdated: Bool
    @NSManaged public var stock: Stock
    
    var date:Date {
        twDateTime.startOfDay(dateTime)
    }
}
