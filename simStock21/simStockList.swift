//
//  simStockList.swift
//  simStock21
//
//  Created by peiyu on 2020/6/24.
//  Copyright © 2020 peiyu. All rights reserved.
//

import Foundation
import SwiftUI

class simStockList:ObservableObject {
    @Published private var sim:simStock = simStock()
    @Published var orientation: Orientation
    @Published var tradesUpdated:Date = Date.distantPast
    
    enum Orientation {
        case portrait
        case landscape
    }
    
    private var _observer: NSObjectProtocol?
    
    init() {
        // fairly arbitrary starting value for 'flat' orientations
        if UIDevice.current.orientation.isLandscape {
            self.orientation = .landscape
        }
        else {
            self.orientation = .portrait
        }
        
        // unowned self because we unregister before self becomes invalid
        _observer = NotificationCenter.default.addObserver(forName: UIDevice.orientationDidChangeNotification, object: nil, queue: nil) { [unowned self] note in
            guard let device = note.object as? UIDevice else {
                return
            }
            if device.orientation.isPortrait {
                self.orientation = .portrait
            }
            else if device.orientation.isLandscape {
                self.orientation = .landscape
            }
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.appNotification),
            name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.appNotification),
            name: UIApplication.willResignActiveNotification, object: nil)
    }
    
    deinit {
        if let observer = _observer {
            NotificationCenter.default.removeObserver(observer)
        }
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
        groupStocks.map{$0[0].group}
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

    @objc func appNotification(_ notification: Notification) {
        switch notification.name {
        case UIApplication.didBecomeActiveNotification:
            NSLog ("=== appDidBecomeActive ===")
            sim.downloadStocks()
            sim.downloadTrades()
        case UIApplication.willResignActiveNotification:
            NSLog ("=== appWillResignActive ===\n")
        default:
            break
        }

    }

    
}
