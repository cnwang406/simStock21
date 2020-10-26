//
//  simStock.swift
//  simStock21
//
//  Created by peiyu on 2020/6/24.
//  Copyright © 2020 peiyu. All rights reserved.
//

import Foundation


struct simStock {
    
    let simTesting:Bool = false
    let simTestStart:Date? = twDateTime.dateFromString("2005/09/09")
    let request = simDataRequest()

    private(set) var stocks:[Stock] = []

    init() {
        if UserDefaults.standard.double(forKey: "simMoneyBase") == 0 {
            let dateStart = twDateTime.calendar.date(byAdding: .year, value: -3, to: twDateTime.startOfDay()) ?? Date.distantFuture
            setDefaults(start: dateStart, money: 70.0, invest: true)
        }
        self.stocks = Stock.fetch(coreData.shared.context)
        if self.stocks.count == 0 {
            let group1:[(sId:String,sName:String)] = [
                (sId:"3653", sName:"健策"),
                (sId:"1515", sName:"力山"),
                (sId:"2330", sName:"台積電"),
                (sId:"3037", sName:"欣興")]
            self.newStock(stocks: group1, group: "股群_1")
            
            let group2:[(sId:String,sName:String)] = [
                (sId:"2324", sName:"仁寶"),
                (sId:"1301", sName:"台塑"),
                (sId:"2201", sName:"裕隆"),
                (sId:"2317", sName:"鴻海")]
            self.newStock(stocks: group2, group: "股群_2")
        }
    }
        
    mutating func fetchStocks(_ searchText:[String]?=nil) {
        self.stocks = Stock.fetch(coreData.shared.context, sId: searchText, sName: searchText)
    }
        
    mutating private func newStock(stocks:[(sId:String,sName:String)], group:String?=nil) {
        let context = coreData.shared.context
        for stock in stocks {
            let s = Stock.new(context, sId:stock.sId, sName:stock.sName, group: group)
            let simDefaults = self.simDefaults
            s.dateFirst = simDefaults.first
            s.dateStart = simDefaults.start
            s.simMoneyBase = simDefaults.money
        }
        try? context.save()
        self.fetchStocks()
        NSLog("new stocks added: \(stocks)")
    }
    
    mutating func moveStocksToGroup(_ stocks:[Stock], group:String) {
        if let context = stocks.first?.context {
            var newStocks:[Stock] = []
            let simDefaults = self.simDefaults
            for stock in stocks {
                if stock.group == "" && group != "" {
                    if simDefaults.first < stock.dateFirst {
                        stock.dateFirst = simDefaults.first
                        stock.dateStart = simDefaults.start
                    }
                    stock.simMoneyBase = simDefaults.money
                    newStocks.append(stock)
                }
                stock.group = group
                if group == "" {
                    self.stocks = self.stocks.filter{$0 != stock}
                }   //搜尋而加入新股不用append到self.stocks因為searchText在給值或清除時都會fetchStocks
            }
            try? context.save()
            if newStocks.count > 0 {
                request.downloadTrades(newStocks, requestAction: .newTrades, allStocks: self.stocks)
            }
        }
    }
    
    func addInvest(_ trade: Trade) {
        if let context = trade.managedObjectContext {
            if trade.simInvestByUser == 0 {
                if trade.simInvestAdded > 0 {
                    trade.simInvestByUser = -1
                } else if trade.simInvestAdded == 0 {
                    trade.simInvestByUser = 1
                }
            } else {
                trade.simInvestByUser = 0
            }
            try? context.save()
            request.downloadTrades([trade.stock], requestAction: .simUpdateAll, allStocks: self.stocks)
        }
    }
    
    func setReversed(_ trade: Trade) {
        if let context = trade.managedObjectContext {
            let trades = Trade.fetch(context, stock: trade.stock, simReversed:true)
            let simQty = trade.simQty
            if trade.simReversed == "" {
                switch simQty.action {
                case "買":
                    trade.simReversed = "B-"
                case "賣":
                    trade.simReversed = "S-"
                case "餘":
                    trade.simReversed = "S+"
                default:
                    trade.simReversed = "B+"
                }
                for tr in trades {
                    if tr.date > trade.date {
                        tr.simReversed = ""
                    }
                }
            } else {
                for tr in trades {
                    tr.simReversed = ""
                }
            }
            try? context.save()
            request.downloadTrades([trade.stock], requestAction: .simUpdateAll, allStocks: self.stocks)
        }
    }
    
    func settingStocks(_ stocks:[Stock],dateStart:Date,moneyBase:Double,addInvest:Bool) {
        if let context = stocks[0].managedObjectContext {
            var dateChanged:Bool = false
            for stock in stocks {
                if dateStart != stock.dateStart {
                    stock.dateStart = dateStart
                    let dtFirst = twDateTime.calendar.date(byAdding: .year, value: -1, to: dateStart) ?? stock.dateStart
                    if dtFirst < stock.dateFirst {
                        stock.dateFirst = dtFirst
                    }
                    dateChanged = true
                }
                stock.simMoneyBase = moneyBase
                stock.simAddInvest = addInvest
            }
            if !simTesting {
                DispatchQueue.main.async {
                    try? context.save()
                }
                request.downloadTrades(stocks, requestAction: (dateChanged ? .allTrades : .simResetAll), allStocks: self.stocks)
            }
        }
    }
    
    var simDefaults:(first:Date,start:Date,money:Double,invest:Bool) {
        let start = UserDefaults.standard.object(forKey: "simDateStart") as? Date ?? Date.distantFuture
        let money = UserDefaults.standard.double(forKey: "simMoneyBase")
        let invest = UserDefaults.standard.bool(forKey: "simAddInvest")
        let first = twDateTime.calendar.date(byAdding: .year, value: -1, to: start) ?? start
        return (first,start,money,invest)
    }
    
    func setDefaults(start:Date,money:Double,invest:Bool) {
        UserDefaults.standard.set(start, forKey: "simDateStart")
        UserDefaults.standard.set(money, forKey: "simMoneyBase")
        UserDefaults.standard.set(invest,forKey: "simAddInvest")
    }
    
    var t00:Stock? {
        let t00 = stocks.filter{$0.sId == "t00"}
        if t00.count > 0 {
            return t00[0]
        }
        return nil
    }
    
        
    var groupStocks:[[Stock]] {
        Dictionary(grouping: stocks) { (stock:Stock)  in
            stock.group
        }.values
            .map{$0.map{$0}.sorted{$0.sName < $1.sName}}
            .sorted {$0[0].group < $1[0].group}
    }
    
    func stocksSummary(_ stocks:[Stock]) -> (count:Double, roi:Double, days:Double) {
        if stocks.count == 0 {
            return (0,0,0)
        }
        var sumRoi:Double = 0
        var sumDays:Double = 0
        let s = stocks.filter{$0.sId != "t00"}
        for stock in s {
            if let trade = stock.lastTrade(stock.context) {
                sumRoi += (trade.rollAmtRoi / stock.years)
                sumDays += trade.days
            }
        }
        let count = Double(s.count)
        let roi = sumRoi / count
        let days = sumDays / count
        return (count, roi, days)
    }
    
    func runTest(start:Date) {
        UserDefaults.standard.set(true, forKey: "simResetAll")
        NSLog("")
        NSLog("== simTesting \(twDateTime.stringFromDate(start)) ==")
        var groupRoi:String = ""
        var groupDays:String = ""
        for g in 0...(groupStocks.count - 1) {
            let stocks = groupStocks[g].filter{$0.sId != "t00"}
            let group  = stocks[0].group
            let result = testStocks(stocks, group: group, start: start)
            groupRoi = groupRoi + (groupRoi.count > 0 ? ",, " : "") + result.roi
            groupDays = groupDays + (groupDays.count > 0 ? ",, " : "") + result.days
        }
        print("\n")
        print(groupRoi)
        print(groupDays)
        print("\n")
        NSLog("== simTesting finished. ==")
        NSLog("")
    }
    
    private func testStocks(_ stocks:[Stock], group:String, start:Date) -> (roi:String, days:String) {
        var roi:String = ""
        var days:String = ""
        let years:Int = Int(round(Date().timeIntervalSince(start) / 86400 / 365))
        print("\n\n\(group)： 自\(twDateTime.stringFromDate(start,format:"yyyy"))第\(years)年起 ... ", terminator:"")
        var nextYear:Date = start
        while nextYear <= (twDateTime.calendar.date(byAdding: .year, value: -1, to: twDateTime.startOfDay()) ?? Date.distantPast) {
            let _ = settingStocks(stocks, dateStart: nextYear, moneyBase: 100, addInvest: true)
            request.downloadTrades(stocks, requestAction: .simTesting)
            let summary = stocksSummary(stocks)
            roi = String(format:"%.1f", summary.roi) + (roi.count > 0 ? ", " : "") + roi
            days = String(format:"%.f", summary.days) + (days.count > 0 ? ", " : "") + days
            print("\(twDateTime.stringFromDate(nextYear, format: "yyyy"))" + String(format:"(%.1f/%.f) ",summary.roi,summary.days), terminator:"")
            nextYear = (twDateTime.calendar.date(byAdding: .year, value: 1, to: nextYear) ?? Date.distantPast)
        }
        return (roi,days)
    }
    
//    var stocksJSON: Data? { try? JSONEncoder().encode(stocks) }
//    init?(stocksJSON: Data?) {
//        if let json = stocksJSON, let s = try? JSONDecoder().decode(Array<Stock>.self, from: json) {
//            stocks = s
//        } else {
//            stocks = []
//        }
//    }
    

    
}

