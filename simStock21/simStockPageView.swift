//
//  simStockPageView.swift
//  simStock21
//
//  Created by peiyu on 2020/6/28.
//  Copyright © 2020 peiyu. All rights reserved.
//

import SwiftUI

struct stockPageView: View {
    @ObservedObject var list: simStockList
    @Environment(\.horizontalSizeClass) var sizeClass
    
    @State var stock : Stock
    @State var prefix: String
    
    var body: some View {
        VStack (alignment: .center) {
            tradeListView(list: self.list, stock: self.$stock)
            Spacer()
            stockPicker(list: self.list, prefix: self.$prefix, stock: self.$stock)
        }
            .navigationBarItems(trailing:
                HStack {
                    prefixPicker(list: self.list, prefix: self.$prefix, stock: self.$stock)
                }
            )
    }
}

func pickerIndexRange(index:Int, count:Int, max: Int) -> (from:Int, to:Int) {
    var from:Int = 0
    var to:Int = count - 1
    let center:Int = (max - 1) / 2
    
    if count > max {
        if index <= center {
            from = 0
            to = max - 1
        } else if index >= (count - center) {
            from = count - max
            to = count - 1
        } else {
            from = index - center
            to = index + center
        }
    }
    
    return(from,to)
}

struct prefixPicker: View {
    @ObservedObject var list: simStockList
    @Environment(\.horizontalSizeClass) var sizeClass
    
    @Binding var prefix: String
    @Binding var stock : Stock

    var prefixs:[String] {
            let prefixs = list.prefixs
            let prefixIndex = prefixs.firstIndex(of: prefix) ?? 0
            let maxCount = (sizeClass == .regular ? 19 : 9) + (sizeClass == .compact && list.orientation == .landscape ? 8 : 0)
            let index = pickerIndexRange(index: prefixIndex, count: prefixs.count, max: maxCount)
            return Array(prefixs[index.from...index.to])
    }

    var body: some View {
        HStack {
            if self.prefixs.first == list.prefixs.first {
                Text("|").foregroundColor(.gray).fixedSize()
            } else {
                Text("-").foregroundColor(.gray).fixedSize()
            }
            Picker("", selection: $prefix) {
                ForEach(self.prefixs, id:\.self) {prefix in
                  Text(prefix).tag(prefix)
                }
            }
                .pickerStyle(SegmentedPickerStyle())

                .labelsHidden()
                .fixedSize()
                .onReceive([self.prefix].publisher.first()) { value in
                    if self.stock.prefix != self.prefix {
                        self.stock = self.list.prefixStocks(prefix: value)[0]
                    }
                }
            if self.prefixs.last == list.prefixs.last {
                Text("|").foregroundColor(.gray).fixedSize()
            } else {
                Text("-").foregroundColor(.gray).fixedSize()
            }
        }
    }
}

struct stockPicker: View {
    @ObservedObject var list: simStockList
    @Environment(\.horizontalSizeClass) var sizeClass

    @Binding var prefix:String
    @Binding var stock :Stock
    
    var prefixStocks:[Stock] {
        let stocks = list.prefixStocks(prefix: self.prefix)
        let stockIndex = stocks.firstIndex(of: self.stock) ?? 0
        let maxCount = (sizeClass == .regular ? 9 : 3) + (sizeClass == .compact && list.orientation == .landscape ? 4 : 0)
        let index = pickerIndexRange(index: stockIndex, count: stocks.count, max: maxCount)
        return Array(stocks[index.from...index.to])
    }

    var body: some View {
        VStack (alignment: .center) {
            if self.prefixStocks.count > 1 {
                HStack {
                    if self.prefixStocks.first == list.prefixStocks(prefix: self.prefix).first {
                        Text("|").foregroundColor(.gray).fixedSize()
                    } else {
                        Text("-").foregroundColor(.gray)
                    }
                    Picker("", selection: $stock) {
                        ForEach(self.prefixStocks, id:\.self.sId) { stock in
                             Text(stock.sName).tag(stock)
                        }
                    }
                        .pickerStyle(SegmentedPickerStyle())
                        .labelsHidden()
                        .fixedSize()
                    if self.prefixStocks.last == list.prefixStocks(prefix: self.prefix).last {
                        Text("|").foregroundColor(.gray).fixedSize()
                    } else {
                        Text("-").foregroundColor(.gray).fixedSize()
                    }
                }
            }
		}
    }
    
}

struct tradeListView: View {
    @ObservedObject var list: simStockList
    @Binding var stock : Stock
    @State var selected: Date?
//    @State var tradeSelected: Trade?

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(stock.sId)
                Text(stock.sName)
            }
            .font(.title)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .padding()
            VStack(alignment: .leading) {
                Text("首：\(twDateTime.stringFromDate(stock.dateFirst))")
                Text("起：\(twDateTime.stringFromDate(stock.dateStart))")
            }
            .font(.footnote)
            .padding()


//            List (selection: $tradeSelected) {
            List {
                ForEach(stock.trades, id:\.self.dateTime) { trade in
                    tradeCell(trade: trade, selected: self.$selected) // tradeSelected: self.$tradeSelected)
                    .onTapGesture {
                        if self.selected == trade.date {
                            self.selected = nil
                        } else {
                            self.selected = trade.date
                        }
                    }
                }
            }
            .id(UUID())
            .listStyle(GroupedListStyle())
            Spacer()
            
        }
        
    }
}

struct tradeCell: View {
    @ObservedObject var trade:Trade
    @Binding var selected: Date?
//    @Binding var tradeSelected: Trade?
    
     var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(twDateTime.stringFromDate(trade.dateTime))
                Text(String(trade.priceClose))
//                if trade == tradeSelected {
//                    Text("*")
//                }
            }
            if self.selected == trade.date {
                HStack {
                    Text(twDateTime.stringFromDate(trade.dateTime, format: "HH:mm:ss"))
                    Text(trade.tSource)
                }
                    .font(.custom("Courier", size: 16))
                Spacer()
                HStack {
                    Spacer()
                    VStack(alignment: .trailing,spacing: 2) {
                        Text("開盤")
                        Text("最高")
                        Text("最低")
                    }
                    VStack(alignment: .trailing,spacing: 2) {
                        Text(String(format:"%.2f",trade.priceOpen))
                        Text(String(format:"%.2f",trade.priceHigh))
                        Text(String(format:"%.2f",trade.priceLow))
                    }
                    Spacer()
                    VStack(alignment: .trailing,spacing: 2) {
                        Text("MA20")
                        Text("MA60")
                        Text("OSC")
                    }
                    VStack(alignment: .trailing,spacing: 2) {
                        Text(String(format:"%.2f",trade.tMa20))
                        Text(String(format:"%.2f",trade.tMa60))
                        Text(String(format:"%.2f",trade.tOsc))
                    }
                    Spacer()
                    VStack(alignment: .trailing,spacing: 2) {
                        Text("K")
                        Text("D")
                        Text("J")
                    }
                    VStack(alignment: .trailing,spacing: 2) {
                        Text(String(format:"%.2f",trade.tKdK))
                        Text(String(format:"%.2f",trade.tKdD))
                        Text(String(format:"%.2f",trade.tKdJ))
                    }
                    Spacer()

                }
                .font(.custom("Courier", size: 16))
            }
        }
    }

}
