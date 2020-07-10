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
    
    @State var stock : Stock
    @State var prefix: String

    var body: some View {
        Form {
            VStack (alignment: .leading) {
                HStack {
                    Spacer()
                    Picker("", selection: $prefix) {
                        ForEach(list.prefixs, id:\.self) {prefix in
                          Text(prefix).tag(prefix)
                        }
                    }
                        .pickerStyle(SegmentedPickerStyle())
                        .frame(width: CGFloat(list.prefixs.count * 40))
                        .labelsHidden()
                        .onReceive([self.prefix].publisher.first()) { value in
                            if self.stock.prefix != self.prefix {
                                self.stock = self.list.prefixStocks(prefix: value)[0]
                            }
                        }
                }
                stockPicker(list: self.list, prefix: self.$prefix, stock: self.$stock)
            }
        }
    }
}


struct stockPicker: View {
    @ObservedObject var list: simStockList
    @Binding var prefix:String
    @Binding var stock :Stock

    var body: some View {
		Group {
            HStack (alignment: .center) {
                Group {
                    Text(stock.sId)
                    Text(stock.sName)
                }
                .font(.title)
                Spacer()
                if self.list.prefixStocks(prefix: prefix).count > 1 {
                    Picker("", selection: $stock) {
                        ForEach(self.list.prefixStocks(prefix: prefix), id:\.self.sId) { stock in
                             Text(stock.sName).tag(stock)
                        }
                    }
                        .pickerStyle(SegmentedPickerStyle())
                        .labelsHidden()
                        .padding(.horizontal, 2)
                        .frame(width: self.list.prefixStocksWidth(prefix: self.prefix))
                }
	        }
            stockContentsView(list: self.list, stock: self.$stock)
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
    }
}
