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
    
    var stocks:[Stock] {
        sim.stocks
    }
    
    var nameGroup:[String:[Stock]] {
        var n:[String:[Stock]] = [:]
        for stock in stocks {
            let name1 = String(stock.sName.first!)
            if n[name1] != nil {
                n[name1]!.append(stock)
            } else {
                n[name1] = [stock]
            }
        }
        return n
    }

    var groupedStocks:[[Stock]] {
        return Dictionary(grouping: sim.stocks) { (stock:Stock)  in
            stock.group.gName
        }.values.map{$0}.sorted {$0[0].group.gName < $1[0].group.gName}
    }
    
    var groups:[String] {
        return groupedStocks.map{$0[0].group.gName}.sorted {$0 < $1}
    }
        
    var searchGotResults:Bool {
        if groups.count > 0 {
            if groups[0] == "" {
                return true
            }
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
            sim.newStock(stocks: group1, gName: "股群1")
            
            let group2:[(sId:String,sName:String)] = [
            (sId:"9914", sName:"美利達"),
            (sId:"2377", sName:"微星"),
            (sId:"1476", sName:"儒鴻"),
            (sId:"2912", sName:"統一超"),
            (sId:"9910", sName:"豐泰")]
            sim.newStock(stocks: group2, gName: "股群2")
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
    
    func moveStockToGroup(_ stocks:[Stock], group:String? = "") {
        if let to = group {
            sim.moveStockToGroup(stocks, gName:to)
        }
    }

}
