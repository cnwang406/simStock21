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
        return VStack {
            Picker("", selection: $prefix) {
                ForEach(list.prefixs, id:\.self) {prefix in
                    Text(prefix).tag(prefix)
                }
            }
                .pickerStyle(SegmentedPickerStyle())
                .labelsHidden()
            .onReceive([self.prefix].publisher.first()) { value in
                self.stock = self.list.prefixStocks(prefix: value)[0]
            }
            
            Picker("", selection: $stock) {
                ForEach(list.prefixStocks(prefix: prefix), id:\.self) { stock in
                    Text(stock.sName).tag(stock)
                }
            }
                .pickerStyle(SegmentedPickerStyle())
                .labelsHidden()
            .frame(width: 500.0, alignment: .leading)

            
            Form{
                HStack {
                    Text(stock.sId)
                    Text(stock.sName)
                }
                .font(.title)
            }
        }
        .padding()
    }
}
