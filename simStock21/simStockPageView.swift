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
                stockContentsView(list: self.list, stock: self.$stock)
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
            let maxCount = (sizeClass == .regular ? 19 : 9)
            let index = pickerIndexRange(index: prefixIndex, count: prefixs.count, max: maxCount)
        return Array(prefixs[index.from...index.to])
        }

        var body: some View {
            HStack {
                if self.prefixs.first == list.prefixs.first {
                    Divider().fixedSize()
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
                    Divider().fixedSize()
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
        let maxCount = (sizeClass == .regular ? 9 : 5)
        let index = pickerIndexRange(index: stockIndex, count: stocks.count, max: maxCount)
        return Array(stocks[index.from...index.to])
    }

    var body: some View {
        VStack (alignment: .center) {
            if self.prefixStocks.count > 1 {
                HStack {
                    if self.prefixStocks.first == list.prefixStocks(prefix: self.prefix).first {
                        Divider().fixedSize().fixedSize()
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
                        Divider().fixedSize()
                    } else {
                            Text("-").foregroundColor(.gray).fixedSize()
                    }
                }
            }
		}
    }
    
}

struct stockContentsView: View {
    @ObservedObject var list: simStockList
    
    @Binding var stock : Stock

    var body: some View {
        HStack {
            Text(stock.sId)
            Text(stock.sName)
        }
            .font(.title)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
    }
}
