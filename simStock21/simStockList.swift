//
//  simStockList.swift
//  simStock21
//
//  Created by peiyu on 2020/6/24.
//  Copyright © 2020 peiyu. All rights reserved.
//

import Foundation
import SwiftUI
import MobileCoreServices

class simStockList:ObservableObject {
    @Environment(\.horizontalSizeClass) var sizeClass
    @Published private var sim:simStock = simStock()
    @Published var dataUpdatedTime:Date = Date.distantPast
    @Published var widthClass:WidthClass
    
    let buildNo:String = Bundle.main.infoDictionary!["CFBundleVersion"] as! String
    let versionNo:String = Bundle.main.infoDictionary!["CFBundleShortVersionString"] as! String
    var versionNow:String = ""

    
    enum WidthClass {
        case compact
        case widePhone
        case regular
        case widePad
    }
    
    private var isPad  = UIDevice.current.userInterfaceIdiom == .pad
    private var hClass = UITraitCollection.current.horizontalSizeClass
    private var vClass = UITraitCollection.current.verticalSizeClass
    
    init() {
        if UIDevice.current.orientation.isLandscape {
            self.widthClass = (self.vClass == .regular ? .widePad : .widePhone)
        }
        else {
            self.widthClass = (self.hClass == .regular ? .regular : .compact)
        }
        
        // unowned self because we unregister before self becomes invalid
        NotificationCenter.default.addObserver(forName: UIDevice.orientationDidChangeNotification, object: nil, queue: nil) { [unowned self] note in
            guard let device = note.object as? UIDevice else {
                return
            }
            if device.orientation.isLandscape {
                self.widthClass = (self.vClass == .regular ? .widePad : .widePhone)
            } else if device.orientation.isPortrait {
                self.widthClass = (self.hClass == .regular ? .regular : .compact)
            }
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.appNotification),
            name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.appNotification),
            name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.setDataUpdatedTime), name: NSNotification.Name("dataUpdated") , object: nil)
    }
        
    var searchText:[String]? = nil {    //搜尋String以空格逗號分離為關鍵字Array
        didSet {
            sim.fetchStocks(searchText)
        }
    }
    
//    var stock:Stock? = nil {
//        didSet {
//            if let stock = stock {
//                sim.fetchTrades(stock)
//            }
//        }
//    }
//    
//    var trades:[Trade] {
//        sim.trades
//    }
    
    
    private var prefixedStocks:[[Stock]] {
        Dictionary(grouping: sim.stocks) { (stock:Stock)  in
            stock.prefix
        }.values
            .map{$0.map{$0}.sorted{$0.sName < $1.sName}}
            .sorted {$0[0].prefix < $1[0].prefix}
    }
    
    var prefixs:[String] {
        prefixedStocks.map{$0[0].prefix}
    }
    
    func prefixStocks(prefix:String) -> [Stock] {
        return prefixedStocks.filter{ $0[0].prefix == prefix}[0]
    }
        
    var groupStocks:[[Stock]] {
        Dictionary(grouping: sim.stocks) { (stock:Stock)  in
            stock.group
        }.values
            .map{$0.map{$0}.sorted{$0.sName < $1.sName}}
            .sorted {$0[0].group < $1[0].group}
    }
    
    var groups:[String] {
        groupStocks.map{$0[0].group}.filter{$0 != ""}
    }
        
    var searchGotResults:Bool {
        if let firstGroup = groupStocks.first?[0].group, firstGroup == "" {
            return true
        }
        return false
    }

    func moveStocks(_ stocks:[Stock], toGroup:String = "") {
        sim.moveStocksToGroup(stocks, group:toGroup)
    }
    
    func addInvest(_ trade: Trade) {
        sim.addInvest(trade)
    }

    var simDefaults:String {
        let defaults = sim.simDefaults
        let start = twDateTime.stringFromDate(defaults.start,format: "起始日yyyy/MM/dd")
        let money = String(format:"起始本金%.f萬元",defaults.money)
        let invest = (defaults.invest ? "自動2次加碼" : "")
        return "預設：\(start) \(money) \(invest)"
    }
    
    func stocksSummary(_ stocks:[Stock]) -> String {
        return sim.stocksSummary(stocks)
    }
    
    func reloadNow(stock: Stock) {
        if let context = stock.managedObjectContext, stock.simAddInvest == false {
            stock.simAddInvest = true
            try? context.save()
        }
        self.sim.request.runRequest(stocks: [stock], action: .tUpdateAll)
        /*
        let d = DispatchGroup()
        d.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            let context = coreData.shared.context
            let trades = Trade.fetch(context, stock: stock)
            for trade in trades {
                context.delete(trade)
            }
            try? context.save()
            d.leave()
        }
        d.notify(queue: .main) {
            self.sim.request.runRequest(stocks: [stock], all:true)
        }
        */
        
    }
    
    func applySetting (_ stock:Stock, dateStart:Date,moneyBase:Double,addInvest:Bool, applyToGroup:Bool, applyToAll:Bool, saveToDefaults:Bool) {
        var stocks:[Stock] = []
        if applyToAll {
            stocks = sim.stocks
        } else if applyToGroup {
            for g in groupStocks {
                if g[0].group == stock.group {
                    for s in g {
                        stocks.append(s)
                    }
                }
            }
        } else {
            stocks.append(stock)
        }
        sim.settingStocks(stocks, dateStart: dateStart, moneyBase: moneyBase, addInvest: addInvest)
        if saveToDefaults {
            sim.setDefaults(start: dateStart, money: moneyBase, invest: addInvest)
        }
    }
    
    @objc func setDataUpdatedTime(_ notification: Notification) {
        if let userInfo = notification.userInfo, let time = userInfo["dataUpdatedTime"] as? Date {
            self.dataUpdatedTime = time
        }
    }

    @objc func appNotification(_ notification: Notification) {
        switch notification.name {
        case UIApplication.didBecomeActiveNotification:
            NSLog ("=== appDidBecomeActive ===")
            if sim.simTesting {
                let start = sim.simTestStart ?? (twDateTime.calendar.date(byAdding: .year, value: -15, to: twDateTime.startOfDay()) ?? Date.distantPast)
                NSLog("\n\n== simTesting \(twDateTime.stringFromDate(start)) ==")
                sim.runTest(start: start)
            } else {
                versionNow = versionNo + (buildNo <= "1" ? "" : "(\(buildNo))")
                let versionLast = sim.defaults.string(forKey: "simStockVersion") ?? ""
                sim.defaults.set(versionNow, forKey: "simStockVersion")
                sim.downloadStocks()
                let updateAll:Bool = sim.defaults.bool(forKey: "updateAll") || sim.tUpdateAll || (versionLast != versionNow)
                sim.downloadTrades(updateAll: updateAll)
                sim.defaults.removeObject(forKey: "updateAll")
            }
        case UIApplication.willResignActiveNotification:
            NSLog ("=== appWillResignActive ===\n")
        default:
            break
        }

    }

    
}
