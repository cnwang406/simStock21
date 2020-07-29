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
    @NSManaged public var simAddInvest:Bool         //自動加碼
    @NSManaged public var simMoneyBase: Double      //每次投入本金額度
    @NSManaged public var simReversed:Bool          //反轉買賣
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

    var years:Double {
        var years = Date().timeIntervalSince(self.dateStart) / 86400 / 365
        if years < 1 {
            years = 1
        }
        return years
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
    static func fetchRequest (stock:Stock, dateTime:Date?=nil, simReversed:Bool?=nil, fetchLimit:Int?=nil, asc:Bool=false) -> NSFetchRequest<Trade> {
        var predicates:[NSPredicate] = []
        predicates.append(NSPredicate(format: "stock == %@", stock))
        if let dt = dateTime {
            predicates.append(NSPredicate(format: "dateTime >= %@", dt as CVarArg))
        }
        if let r = simReversed, r == true  {
            predicates.append(NSPredicate(format: "simReversed != %@", ""))
        }
        let fetchRequest = NSFetchRequest<Trade>(entityName: "Trade")
        fetchRequest.predicate = NSCompoundPredicate(type: .and, subpredicates: predicates)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "dateTime", ascending: asc)]
        if let limit = fetchLimit {
            fetchRequest.fetchLimit = limit
        }
        return fetchRequest
    }
    
    static func fetch (_ context:NSManagedObjectContext, stock:Stock, dateTime:Date?=nil, simReversed:Bool?=nil, fetchLimit:Int?=nil, asc:Bool=false) -> [Trade] {
        let fetchRequest = self.fetchRequest(stock: stock, dateTime: dateTime, simReversed:simReversed, fetchLimit: fetchLimit, asc: asc)
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

    @NSManaged public var dateTime: Date            //成交/收盤時間
    @NSManaged public var priceClose: Double        //成交/收盤價
    @NSManaged public var priceHigh: Double         //最高價
    @NSManaged public var priceLow: Double          //最低價
    @NSManaged public var priceOpen: Double         //開盤價
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
    @NSManaged public var simInvestAdded: Double
    @NSManaged public var simInvestTimes: Double
    @NSManaged public var simQtyBuy: Double         //買入張數
    @NSManaged public var simQtyInventory: Double   //庫存張數
    @NSManaged public var simQtySell: Double        //賣出張數
    @NSManaged public var simReversed:String        //反轉行動
    @NSManaged public var simRule:String            //模擬預定
    @NSManaged public var simRuleBuy:String         //模擬行動：高買H或低賣L
    @NSManaged public var simRuleInvest:String      //模擬行動：加碼
    @NSManaged public var simUnitCost: Double       //成本單價
    @NSManaged public var simUnitRoi: Double
    @NSManaged public var simUpdated: Bool
    @NSManaged public var tHighDiff: Double       //最高價差比
    @NSManaged public var tHighDiff125: Double
    @NSManaged public var tHighDiff250: Double
    @NSManaged public var tHighDiff375: Double
    @NSManaged public var tKdD: Double              //K,D,J
    @NSManaged public var tKdDZ125: Double          //0.5年標準差分
    @NSManaged public var tKdDZ250: Double          //1.0年標準差分
    @NSManaged public var tKdDZ375: Double          //1.5年標準差分
    @NSManaged public var tKdJ: Double
    @NSManaged public var tKdJZ125: Double          //0.5年標準差分
    @NSManaged public var tKdJZ250: Double          //1.0年標準差分
    @NSManaged public var tKdJZ375: Double          //1.5年標準差分
    @NSManaged public var tKdK: Double
    @NSManaged public var tKdKMax9: Double
    @NSManaged public var tKdKMin9: Double
    @NSManaged public var tKdKZ125: Double          //0.5年標準差分
    @NSManaged public var tKdKZ250: Double          //1.0年標準差分
    @NSManaged public var tKdKZ375: Double          //1.5年標準差分
    @NSManaged public var tLowDiff: Double          //最低價差比
    @NSManaged public var tLowDiff125: Double
    @NSManaged public var tLowDiff250: Double
    @NSManaged public var tLowDiff375: Double
    @NSManaged public var tMa20: Double             //20天均價
    @NSManaged public var tMa20Days: Double         //Ma20延續漲跌天數
    @NSManaged public var tMa20Diff: Double
    @NSManaged public var tMa20DiffMax9: Double
    @NSManaged public var tMa20DiffMin9: Double
    @NSManaged public var tMa20DiffZ125: Double     //Ma20Diff於0.5年標準差分
    @NSManaged public var tMa20DiffZ250: Double     //Ma20Diff於1.0年標準差分
    @NSManaged public var tMa20DiffZ375: Double     //Ma20Diff於1.5年標準差分
    @NSManaged public var tMa60: Double             //60天均價
    @NSManaged public var tMa60Days: Double         //Ma60延續漲跌天數
    @NSManaged public var tMa60Diff: Double         //現價對Ma60差比
    @NSManaged public var tMa60DiffMax9: Double     //Ma60Diff於9天內最高
    @NSManaged public var tMa60DiffMin9: Double     //Ma60Diff於9天內最低
    @NSManaged public var tMa60DiffZ125: Double     //Ma60Diff於0.5年標準差分
    @NSManaged public var tMa60DiffZ250: Double     //Ma60Diff於1.0年標準差分
    @NSManaged public var tMa60DiffZ375: Double     //Ma60Diff於1.5年標準差分
    @NSManaged public var tOsc: Double              //Macd的Osc
    @NSManaged public var tOscEma12: Double
    @NSManaged public var tOscEma26: Double
    @NSManaged public var tOscMacd9: Double
    @NSManaged public var tOscMax9: Double
    @NSManaged public var tOscMin9: Double
    @NSManaged public var tOscZ125: Double          //0.5年標準差分
    @NSManaged public var tOscZ250: Double          //1.0年標準差分
    @NSManaged public var tOscZ375: Double          //1.5年標準差分
    @NSManaged public var tSource: String           //價格來源
    @NSManaged public var tUpdated: Bool
    @NSManaged public var stock: Stock
    
    var date:Date {
        twDateTime.startOfDay(dateTime)
    }
    
    var simQty:(action:String,qty:Double) {
        if self.simQtySell > 0 {
            return ("賣", simQtySell)
        } else if self.simQtyBuy > 0 {
            return ("買", simQtyBuy)
        } else if self.simQtyInventory > 0 {
            return ("餘", simQtyInventory)
        } else {
            return ("", 0)
        }
    }
    
    func resetSimValues() {
        self.simAmtCost = 0
        self.simAmtProfit = 0
        self.simAmtRoi = 0
        self.simDays = 0
        if self.simRuleInvest != "A" {
            self.simInvestAdded = 0
        }
        self.simQtyBuy = 0         //買入張數
        self.simQtyInventory = 0   //庫存張數
        self.simQtySell = 0        //賣出張數
        self.simUnitCost = 0       //成本單價
        self.simUnitRoi = 0
        self.simRule = ""
        self.simRuleBuy = ""
        self.simRuleInvest = ""
//        self.simReversed = ""
    }
    
    func setDefaultValues() {
        self.rollAmtCost = 0
        self.rollAmtProfit = 0
        self.rollAmtRoi = 0
        self.rollDays = 0
        self.rollRounds = 0
        
        self.resetSimValues()
        self.simInvestTimes = 0
        self.simAmtBalance = 0
        self.simReversed = ""
    }
}
