//
//  simStockListView.swift
//  simStock21
//
//  Created by peiyu on 2020/6/24.
//  Copyright © 2020 peiyu. All rights reserved.
//

import SwiftUI
import CoreData

struct simStockListView: View {
    
    @ObservedObject var list: simStockList
        
    var body: some View {
        NavigationView {
            VStack(alignment: .leading) {
                SearchBar(text: "", searchText: $list.searchText)
                Text(searchMessage)
                    .font(.footnote)
                    .padding(.horizontal, 20)
                List{
                    ForEach(list.groups, id: \.self) {(stocks:[Stock]) in
                        stockSection(stocks: stocks, isChoosing: self.$isChoosing, checkedStocks: self.$checkedStocks)
                    }
                }
                    .listStyle(GroupedListStyle())
            }
            .navigationBarItems(leading: choose, trailing: endChoosing)
        }
        .navigationViewStyle(StackNavigationViewStyle())
 
    }
    
    @State private var isChoosing = false
    @State var checkedStocks: [Stock] = []

    
    var choose: some View {
        HStack {
            if isChoosing {
                Text("請勾選")
                 if checkedStocks.count > 0 {
                    Text(">")
                    Button("移除") {
                        self.list.removeStock(self.checkedStocks)
                        self.checkedStocks = []
                        self.isChoosing = false
                    }
                }
            } else {
                Button("選取") {
                    self.isChoosing = true
                }
            }
        }
            .frame(width:500.0, alignment: .leading)
            .lineLimit(1)
            .minimumScaleFactor(0.5)

    }
    
    var endChoosing: some View {
        Group {
            if isChoosing {
                Button("離開選取模式") {
                    self.isChoosing = false
                }
            }
        }
    }

    
    var searchMessage:String {
        (list.searchText != nil && list.groups[0][0].group != "" ? "查無符合，或已在股群清單？" : "")
    }
}



struct stockSection : View {
    @State var stocks : [Stock]
    @Binding var isChoosing:Bool
    @Binding var checkedStocks: [Stock]

    var header:String {
        (stocks[0].group == "" ? "<搜尋結果>" : "[\(stocks[0].group)]")
    }
    var footer:String {
        "\(stocks.count)支股"
    }

    var body: some View {
        Section(header: Text(header),footer: Text(footer)) {
            ForEach(stocks, id: \.sId) {stock in
                stockCell(stock: stock, isChoosing: self.$isChoosing, checkedStocks: self.$checkedStocks)
            }
        }
    }
    
}


struct stockCell : View {
    var stock : Stock
    @Binding var isChoosing:Bool
    @Binding var checkedStocks:[Stock]
        
    var body: some View {
        HStack {
            if isChoosing {
                checkStock(stock: self.stock, isChecked: false, checkedStocks: self.$checkedStocks)
            }
            Text(stock.sId)
                .frame(width : 50.0, alignment: .leading)
            Text(stock.sName)
                .frame(width : 80.0, alignment: .leading)
            if stock.group != "" && !isChoosing {
                NavigationLink(destination: stockPage(stock: stock)) {
                    Text("")
                }
                    .navigationBarTitle("")
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.5)
    }
}

struct checkStock: View {
    var stock : Stock
    @State var isChecked:Bool
    @Binding var checkedStocks:[Stock]
    
    
    func check() {
        self.isChecked = !self.isChecked
        if self.isChecked {
            self.checkedStocks.append(stock)
        } else {
            self.checkedStocks.removeAll(where: {$0 == stock})
        }
    }

    var body: some View {
        Group {
            Button(action: check) {
                Image(systemName: isChecked ? "checkmark.square" : "square")
            }
        }
    }
}

struct stockPage: View {
    var stock : Stock
    
    var body: some View {
        VStack {
            HStack {
                Text(stock.sId)
                Text(stock.sName)
            }
        }
        .padding()
    }
}

struct SearchBar: View {
    @State   private var isEditing = false
    @State   var text: String
    @Binding var searchText:[String]?

    var body: some View {
        HStack {
            TextField("Search ...", text: $text, onEditingChanged: {    //began or end (bool)
                self.isEditing = $0
            }, onCommit: {
                self.searchText = self.text.replacingOccurrences(of: ",", with: " ").replacingOccurrences(of: "  ", with: " ").replacingOccurrences(of: "  ", with: " ").components(separatedBy: " ")
            })
                .padding(7)
                .padding(.horizontal, 25)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .overlay(
                   HStack {
                       Image(systemName: "magnifyingglass")
                           .foregroundColor(.gray)
                           .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                           .padding(.leading, 8)
                
                       if isEditing {
                            Button(action: {
                                self.text = ""
                                self.searchText = nil
                           })
                           {
                                Image(systemName: "multiply.circle.fill")
                                   .foregroundColor(.gray)
                                   .padding(.trailing, 8)
                           }
                       }
                   }
                )
                .padding(.horizontal, 10)
            if isEditing {
                Button(action: {
                    self.isEditing = false
                    self.text = ""
                    self.searchText = nil
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)  // Dismiss the keyboard
                })
                {
                    Text("Cancel")
                }
                .padding(.trailing, 10)
                .transition(.move(edge: .trailing))
                .animation(.default)
            }
        }
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        simStockListView(list: simStockList())
    }
}
