//
//  coreData.swift
//  simStock21
//
//  Created by peiyu on 2020/6/24.
//  Copyright © 2020 peiyu. All rights reserved.
//

import Foundation
import CoreData
import SwiftUI

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
                if ids.count == 1 && sName == nil {
                    predicates.append(NSPredicate(format: "sId == %@", upperId))
                } else {
                    predicates.append(NSPredicate(format: "sId CONTAINS %@", upperId))
                }
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
                    NSLog("\(stock.sId)\(stock.sName) 重複\(index)???")
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
    @NSManaged public var simAddInvest:Bool         //停用，改為simAutoInvest
    @NSManaged public var simAutoInvest:Double      //自動加碼次數：0～9，10為無限次
    @NSManaged public var simMoneyBase: Double      //每次投入本金額度
    @NSManaged public var simReversed:Bool          //反轉買賣
    @NSManaged public var stockTrades: NSSet?
    
    
    var prefix:String {
        String(sName.first ?? Character(""))
    }
    
    var trades:[Trade] {    //只給swiftui用的
        let context = self.context
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
    
    func deleteTrades(oneMonth:Bool=false) {
        let context = coreData.shared.context
        var mStart:Date? = nil
        if oneMonth {
            if let last = self.lastTrade(context) {
                mStart = twDateTime.startOfMonth(last.date)
            }
        }
        let trades = Trade.fetch(context, stock: self, dateTime: mStart)
        NSLog("\(self.sId)\(self.sName) 刪除trades:共\(trades.count)筆")
        for trade in trades {
            context.delete(trade)
        }
        try? context.save()
    }

    var years:Double {
        var years = Date().timeIntervalSince(self.dateStart) / 86400 / 365
        if years < 1 {
            years = 1
        }
        return years
    }
    
    var p10:P10 = P10()
    
    
    
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

struct P10 {    //五檔價格試算建議
    var rule:String? = nil
    var action:String = ""
    var date:Date = Date.distantPast
    var L:[(price:Double,action:String,qty:Double,roi:Double)] = []
    var H:[(price:Double,action:String,qty:Double,roi:Double)] = []
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
    @NSManaged public var simInvestByUser: Double
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
    @NSManaged public var tHighDiff: Double         //最高價差比
    @NSManaged public var tHighDiff125: Double
    @NSManaged public var tHighDiff250: Double
    @NSManaged public var tHighDiff375: Double      //＊＊停用＊＊
    @NSManaged public var tKdD: Double              //K,D,J
    @NSManaged public var tKdDZ125: Double          //0.5年標準差分
    @NSManaged public var tKdDZ250: Double          //1.0年標準差分
    @NSManaged public var tKdDZ375: Double          //1.5年標準差分  //＊＊停用＊＊
    @NSManaged public var tKdJ: Double
    @NSManaged public var tKdJZ125: Double          //0.5年標準差分
    @NSManaged public var tKdJZ250: Double          //1.0年標準差分
    @NSManaged public var tKdJZ375: Double          //1.5年標準差分  //＊＊停用＊＊
    @NSManaged public var tKdK: Double
    @NSManaged public var tKdKMax9: Double
    @NSManaged public var tKdKMin9: Double
    @NSManaged public var tKdKZ125: Double          //0.5年標準差分
    @NSManaged public var tKdKZ250: Double          //1.0年標準差分
    @NSManaged public var tKdKZ375: Double          //1.5年標準差分  //＊＊停用＊＊
    @NSManaged public var tLowDiff: Double          //最低價差比
    @NSManaged public var tLowDiff125: Double
    @NSManaged public var tLowDiff250: Double
    @NSManaged public var tLowDiff375: Double       //＊＊停用＊＊
    @NSManaged public var tMa20: Double             //20天均價
    @NSManaged public var tMa20Days: Double         //Ma20延續漲跌天數
    @NSManaged public var tMa20Diff: Double
    @NSManaged public var tMa20DiffMax9: Double
    @NSManaged public var tMa20DiffMin9: Double
    @NSManaged public var tMa20DiffZ125: Double     //Ma20Diff於0.5年標準差分
    @NSManaged public var tMa20DiffZ250: Double     //Ma20Diff於1.0年標準差分
    @NSManaged public var tMa20DiffZ375: Double     //Ma20Diff於1.5年標準差分 //＊＊停用＊＊
    @NSManaged public var tMa60: Double             //60天均價
    @NSManaged public var tMa60Days: Double         //Ma60延續漲跌天數
    @NSManaged public var tMa60Diff: Double         //現價對Ma60差比
    @NSManaged public var tMa60DiffMax9: Double     //Ma60Diff於9天內最高
    @NSManaged public var tMa60DiffMin9: Double     //Ma60Diff於9天內最低
    @NSManaged public var tMa60DiffZ125: Double     //Ma60Diff於0.5年標準差分
    @NSManaged public var tMa60DiffZ250: Double     //Ma60Diff於1.0年標準差分
    @NSManaged public var tMa60DiffZ375: Double     //Ma60Diff於1.5年標準差分 //＊＊停用＊＊
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
        
    var days:Double {
        if self.rollRounds <= 1 {
            return self.rollDays
        } else {
            let prevRounds = (self.rollRounds - (self.simQtyInventory > 0 ? 1 : 0))
            let prevDays = (self.rollDays - (self.simQtyInventory > 0 ? self.simDays : 0)) / prevRounds
            return (self.simDays > prevDays ? self.rollDays / self.rollRounds : prevDays)
        }
    }
    
    enum Grade:Int, Comparable {
        static func < (lhs: Trade.Grade, rhs: Trade.Grade) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
        case wow  = 3
        case high = 2
        case fine = 1
        case none = 0
        case weak = -1
        case low  = -2
        case damn = -3
    }
    var grade:Grade {
        if self.rollRounds > 2 || self.days > 360 {
            let roi = self.rollAmtRoi / self.stock.years
            if self.days < 80 && roi > 20 {
                return .wow
            } else if self.days < 80 && roi > 10 {
                return .high
            } else if self.days < 80 && roi > 5 {
                return .fine
            } else if self.days > 180 || roi < -20 {
                    return .damn
            } else if self.days > 120 || roi < -10 {
                return .low //雖然還沒有使用到low，但改變low的集合就會影響到weak的集合
            } else if self.days > 60 || roi < -1 {
                return .weak
            }
        }
        return .none
    
    }
    
    var gradeIcon:some View {
        switch self.grade {
        case .wow:
            return Image(systemName: "star.square.fill")
                .foregroundColor(.red)
        case .damn:
            return Image(systemName: "3.square")
                .foregroundColor(.green)
        case .high, .low:
            return Image(systemName: "2.square")
                .foregroundColor(self.grade == .high ? .red : .green)
        case .fine, .weak:
            return Image(systemName: "1.square")
                .foregroundColor(self.grade == .fine ? .red : .green)
        default:
            return Image(systemName: "0.square")
                .foregroundColor(.gray)
        }
    }
    
    var invested:Double {
        return self.simInvestByUser + self.simInvestAdded
    }

    
    var simQty:(action:String,qty:Double,roi:Double) {
        if self.simQtySell > 0 {
            return ("賣", simQtySell, simAmtRoi)
        } else if self.simQtyBuy > 0 {
            return ("買", simQtyBuy, simAmtRoi)
        } else if self.simQtyInventory > 0 {
            return ("餘", simQtyInventory, simAmtRoi)
        } else {
            return ("", 0, 0)
        }
    }
        
    enum colorScheme {
        case price
        case time
        case ruleR  //圓框
        case ruleB  //背景
        case ruleF  //文字
        case rule
        case qty
    }
    
    func color (_ scheme: colorScheme, gray:Bool=false, price:Double?=nil) -> Color {
        if gray {
            if scheme == .ruleB || (scheme == .ruleR && self.simRule != "L" && self.simRule != "H") {
                return .clear
            } else {
                return .gray
            }
        }
        let thePrice:Double = price ?? self.priceClose
        let stock:Stock? = self.stock   //刪除trades時，UI參考的舊trade.stock會是nil
        let p10 = stock?.p10 ?? P10()
        switch scheme {
        case .price:
            if p10.action == "" {
                if self.tLowDiff == 10 && self.priceLow == thePrice {
                    return .green
                } else  if self.tHighDiff == 10 && self.priceHigh == thePrice {
                    return .red
                }
            }
            return self.color(price == nil ? .ruleF : .time)
            
        case .time:
            if twDateTime.inMarketingTime(self.dateTime) {
                return Color(UIColor.purple)
            } else if self.simRule == "_" {
                return .gray
            } else {
                return .primary
            }
        case .rule:
            switch (p10.rule ?? self.simRule) {
            case "L":
                return .green
            case "H":
                return .red
            default:
                if self.simRuleInvest == "A" {
                    return .green
                }
                return .primary
            }
        case .ruleF:
            if p10.action != "" && p10.date == self.date {
                return .white
            } else {
                return self.color(.time)
            }
        case .ruleB:
            if p10.action != "" && p10.date == self.date {
                if self.stock.p10.action == "賣" {
                    return .blue
                } else {
                    return self.color(.rule)
                }
            } else {
                return .clear
            }
        case .ruleR:
            if self.simRule == "L" || self.simRule == "H" {
                return self.color(.rule)
            } else {
                return .clear
            }
        case .qty:
            switch self.simQty.action {
            case "賣":
                return .blue
            case "買":
                return self.color(.rule)
            default:
                return .primary
            }
        }
    }
    
    func resetSimValues() {
        self.simAmtCost = 0
        self.simAmtProfit = 0
        self.simAmtRoi = 0
        self.simDays = 0
        self.simQtyBuy = 0         //買入張數
        self.simQtyInventory = 0   //庫存張數
        self.simQtySell = 0        //賣出張數
        self.simUnitCost = 0       //成本單價
        self.simUnitRoi = 0
        self.simRule = ""
        self.simRuleBuy = ""
        self.simRuleInvest = ""
        self.simInvestAdded = 0
        //模擬中不能清除反轉或加碼，只由.tUpdateAll或.simResetAll負責清除
    }
    
    func setDefaultValues() {
        self.rollAmtCost = 0
        self.rollAmtProfit = 0
        self.rollAmtRoi = 0
        self.rollDays = 0
        self.rollRounds = 0
        
        self.resetSimValues()
        self.simInvestByUser = 0
//        self.simInvestAdded = 0
        self.simInvestTimes = 0
        self.simAmtBalance = 0
        self.simReversed = ""
    }
}
