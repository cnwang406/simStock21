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
    
    var searchText:[String]? = nil {    //搜尋String以空格逗號分離為關鍵字Array
        didSet {
            sim.fetchStock(searchText)
        }
    }
    
    
    var prefixedStocks:[[Stock]] {
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

//    var groups:[(group:String,stocks:[Stock])] {
//        let groupedStocks = Dictionary(grouping: sim.stocks) { (stock:Stock)  in
//            stock.group
//        }
//        let tupleGroups = groupedStocks.values
//            .map{($0[0].group,$0.map{$0}.sorted{$0.sName < $1.sName})} as [(group:String,stocks:[Stock])]
//        let sortedGroups = tupleGroups.sorted {$0.group < $1.group}
//        NSLog("\(sortedGroups[0].stocks.map{$0.sName})")
//        return sortedGroups
//    }

    
        
    var searchGotResults:Bool {
        if let firstGroup = groupStocks.first?[0].group, firstGroup == "" {
            return true
        }
        return false
    }
    
    init() {
        if sim.stocks.count == 0 {
            let group1:[(sId:String,sName:String)] = [
            (sId:"1590", sName:"亞客-KY"),
            (sId:"3406", sName:"玉晶光"),
            (sId:"2327", sName:"國巨"),
            (sId:"2330", sName:"台積電"),
            (sId:"2474", sName:"可成")]
            sim.newStock(stocks: group1, group: "股群1")
            
            let group2:[(sId:String,sName:String)] = [
            (sId:"9914", sName:"美利達"),
            (sId:"2377", sName:"微星"),
            (sId:"1476", sName:"儒鴻"),
            (sId:"2912", sName:"統一超"),
            (sId:"9910", sName:"豐泰")]
            sim.newStock(stocks: group2, group: "股群2")
        }
        
    }
        
    var isLandscape: Bool {
        if UIDevice.current.orientation.isLandscape {
            return true
        } else {
            return false
        }
    }
    
    var isPad:Bool {
        if (UIDevice.current.userInterfaceIdiom == .pad) {
            return true
        } else {
            return false
        }
    }
    
    func moveStocks(_ stocks:[Stock], toGroup:String = "") {
        sim.moveStocksToGroup(stocks, group:toGroup)
    }

}
