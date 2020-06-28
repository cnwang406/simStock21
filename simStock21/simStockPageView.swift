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
    @State var stocks: [Stock] = []

    var body: some View {
        VStack {
            Picker("", selection: $stock) {
                ForEach(Array(list.nameGroup.keys), id:\.self) { key in
                    Text(key).tag(self.list.nameGroup[key]!.first!)
                }
            }
                .pickerStyle(SegmentedPickerStyle())
                .labelsHidden()
            
            Picker("", selection: $stock) {
                ForEach(list.nameGroup[String(stock.sName.first!)]!, id:\.sId) { s in
                    Text(s.sName).tag(s)
                }
            }
                .pickerStyle(SegmentedPickerStyle())
                .labelsHidden()

            
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
