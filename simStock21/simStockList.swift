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
    @Published private var sim:simStock = simStock()
    @Published var dataUpdatedTime:Date = Date.distantPast
    @Published var widthClass:WidthClass = .compact
    
    var versionNow:String

    private let buildNo:String = Bundle.main.infoDictionary!["CFBundleVersion"] as! String
    private let versionNo:String = Bundle.main.infoDictionary!["CFBundleShortVersionString"] as! String

    enum WidthClass {
        case compact
        case widePhone
        case regular
        case widePad
    }
    
    private var hClass = UITraitCollection.current.horizontalSizeClass
    private var vClass = UITraitCollection.current.verticalSizeClass
    private var isPad  = UIDevice.current.userInterfaceIdiom == .pad

    var deviceWidthClass: WidthClass {
        if UIDevice.current.orientation.isLandscape {
            return (self.vClass == .regular ? .widePad : .widePhone)
        }
        else {
            return (self.hClass == .regular ? .regular : .compact)
        }
    }
    
    init() {
        versionNow = versionNo + (buildNo == "0" ? "" : "(\(buildNo))")
        widthClass = deviceWidthClass
        NotificationCenter.default.addObserver(self, selector: #selector(self.setWidthClass), name: UIDevice.orientationDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.appNotification), name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.appNotification), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.setDataUpdatedTime), name: NSNotification.Name("dataUpdated") , object: nil)
    }
        
    var searchText:[String]? = nil {    //搜尋String以空格逗號分離為關鍵字Array
        didSet {
            sim.fetchStocks(searchText)
        }
    }
    
    var searchTextInGroup:Bool {
        if let search = searchText, search.count == 1 {
            if sim.stocks.map({$0.sId}).contains(search[0]) || sim.stocks.map({$0.sName}).contains(search[0]) {
                return true
            }
        }
        return false
    }
    
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
    
    func csvStocksIdName(_ stocks:[Stock]) -> String {
        var csv:String = ""
        for stock in stocks {
            if csv.count > 0 {
                csv += ", "
            }
            csv += stock.sId + " " + stock.sName
        }
        return csv
    }
        
    var searchGotResults:Bool {
        if let firstGroup = groupStocks.first?[0].group, firstGroup == "" {
            return true
        }
        return false
    }
    
    var requestRunning:Bool {
        sim.request.running
    }
    
    func deleteTrades(_ stocks:[Stock], oneMonth:Bool=false) {
        for stock in stocks {
            stock.deleteTrades(oneMonth: oneMonth)
        }
    }

    func moveStocks(_ stocks:[Stock], toGroup:String = "") {
        sim.moveStocksToGroup(stocks, group:toGroup)
    }
    
    func addInvest(_ trade: Trade) {
        sim.addInvest(trade)
    }
    
    func setReversed(_ trade: Trade) {
        sim.setReversed(trade)
    }

    var simDefaults:String {
        let defaults = sim.simDefaults
        let start = twDateTime.stringFromDate(defaults.start,format: "起始日yyyy/MM/dd")
        let money = String(format:"起始本金%.f萬元",defaults.money)
        let invest = (defaults.invest ? "自動2次加碼" : "")
        return "預設：\(start) \(money) \(invest)"
    }
    
    func stocksSummary(_ stocks:[Stock]) -> String {
        let summary = sim.stocksSummary(stocks)
        let count = String(format:"%.f支股 ",summary.count)
        let roi = String(format:"平均年報酬:%.1f%% ",summary.roi)
        let days = String(format:"平均週期:%.f天",summary.days)
        return "\(count) \(roi) \(days)"
    }
    
    func reloadNow(_ stocks: [Stock], action:simDataRequest.simTechnicalAction) {
        if let context = stocks.first?.context {
            for stock in stocks {
                if stock.simAddInvest == false {
                    stock.simAddInvest = true
                }
            }
            try? context.save()
        }
        sim.request.downloadTrades((sim.request.realtime ? sim.stocks : stocks), requestAction: action)        
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
    
    @objc func setWidthClass(_ notification: Notification) {
        widthClass = deviceWidthClass
    }
    
    @objc func setDataUpdatedTime(_ notification: Notification) {
        if let userInfo = notification.userInfo, let time = userInfo["dataUpdatedTime"] as? Date {
            dataUpdatedTime = time
        }
    }

    @objc func appNotification(_ notification: Notification) {
        switch notification.name {
        case UIApplication.didBecomeActiveNotification:
            NSLog ("=== appDidBecomeActive v\(versionNow) ===")
            if sim.simTesting {
                let start = sim.simTestStart ?? (twDateTime.calendar.date(byAdding: .year, value: -15, to: twDateTime.startOfDay()) ?? Date.distantPast)
                sim.runTest(start: start)
            } else {
                let versionLast = UserDefaults.standard.string(forKey: "simStockVersion") ?? ""
                UserDefaults.standard.set(versionNow, forKey: "simStockVersion")
                sim.request.downloadStocks()
                var action:simDataRequest.simTechnicalAction? {
                    if UserDefaults.standard.bool(forKey: "simResetAll") {
                        UserDefaults.standard.removeObject(forKey: "simResetAll")
                        return .simResetAll
                    } else if versionLast != versionNow {
                        if buildNo == "0" || versionLast == "" {
                            return .tUpdateAll
                        } else {
                            return .simResetAll
                        }
                    }
                    return nil
                }
                sim.request.downloadTrades(sim.stocks, requestAction: action)
            }
        case UIApplication.willResignActiveNotification:
            NSLog ("=== appWillResignActive ===\n")
        default:
            break
        }

    }

    
}
