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
    
    var searchText:String = "" {
        didSet {
            sim.searchText = searchText.replacingOccurrences(of: ",", with: " ").replacingOccurrences(of: "  ", with: " ").replacingOccurrences(of: "  ", with: " ").components(separatedBy: " ")
        }
    }
    
    var groups:[[Stock]] {
        return Dictionary(grouping: sim.stocks) { (stock:Stock)  in
            stock.group
        }.values.map{$0}.sorted {$0[0].group < $1[0].group}
    }
    
    
    init() {
        if sim.stocks.count == 0 {
            let group1:[(sId:String,sName:String)] = [
            (sId:"1590", sName:"亞客-KY"),
            (sId:"3406", sName:"玉晶光"),
            (sId:"2327", sName:"國巨")]
            sim.newStock(stocks: group1, group: "股群1")
            
            let group2:[(sId:String,sName:String)] = [
            (sId:"2330", sName:"台積電"),
            (sId:"2474", sName:"可成")]
            sim.newStock(stocks: group2, group: "股群2")
            
            let group3:[(sId:String,sName:String)] = [
            (sId:"9914", sName:"美利達"),
            (sId:"2377", sName:"微星"),
            (sId:"1476", sName:"儒鴻"),
            (sId:"2912", sName:"統一超"),
            (sId:"9910", sName:"豐泰")]
            sim.newStock(stocks: group3, group: "股群3")
        }
        
    }
    
    

    func removeStock(sId:String) {
        sim.removeStockFromGroup(sId:sId)
    }

}
