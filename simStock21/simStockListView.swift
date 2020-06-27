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
                SearchBar(text: self.$searchText, searchText: $list.searchText, searchCommitted: self.$searchCommitted)
                    .disabled(self.isChoosing)
                HStack{
                    if list.searchText != nil && list.groups[0][0].group != "" {
                    Text("未加入股群的股票中查無符合者，試以部分的代號或簡稱來查詢？")
                        .foregroundColor(.orange)
                    Button("[知道了]") {
                        self.searchText = ""
                        self.searchCommitted = false
                        self.list.searchText = nil
                    }
                    }
                }
                    .font(.footnote)
                    .padding(.horizontal, 20)
                Spacer()
                List{
                    ForEach(list.groups, id: \.self) {(stocks:[Stock]) in
                        stockSection(stocks: stocks, isChoosing: self.$isChoosing, searchCommitted: self.$searchCommitted, checkedStocks: self.$checkedStocks)
                    }
                }
                    .listStyle(GroupedListStyle())
            }
            .navigationBarItems(leading: choose, trailing: endChoosing)
        }
        .navigationViewStyle(StackNavigationViewStyle())
 
    }
    
    @State private var isChoosing = false   //進入了選取模式
    @State var checkedStocks: [Stock] = []  //已選取的股票們
    @State var searchText:String = ""       //剛才輸入的搜尋文字
    @State var searchCommitted:Bool = false //搜尋剛被執行了

    
    var choose: some View {
        HStack {
            if isChoosing {
                Text("請勾選")
                    .foregroundColor(Color(.darkGray))
                 if checkedStocks.count > 0 {
//                    Text(">")
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                    Button("自股群移除") {
                        self.list.removeStock(self.checkedStocks)
                        self.checkedStocks = []
                        self.isChoosing = false
                    }
                    Divider()
                    Button("加入股群") {
                        self.checkedStocks = []
                        self.isChoosing = false
                    }
                }
            } else if self.searchCommitted {
                if list.searchText != nil && list.groups[0][0].group == "" {
                    Text("請勾選")
                     if checkedStocks.count > 0 {
                        Text(">")
                        Button("加入股群") {
                            self.checkedStocks = []
                            self.searchCommitted = false
                        }
                    }
                }
            } else {
                Button("選取") {
                    self.isChoosing = true
                }
            }
        }
            .frame(width:300.0, alignment: .leading)
            .lineLimit(1)
            .minimumScaleFactor(0.5)


    }
    
    var endChoosing: some View {
        HStack {
            if isChoosing {
                Button("離開選取模式") {
                    self.isChoosing = false
                }
            } else if self.searchCommitted && self.list.groups[0][0].group == "" {
                Button("放棄搜尋結果") {
                    self.searchText = ""
                    self.list.searchText = nil
                    self.searchCommitted = false
                }
            }
        }
        .frame(width:300.0, alignment: .trailing)
        .lineLimit(1)
        .minimumScaleFactor(0.5)
    }

    
}



struct stockSection : View {
    @State var stocks : [Stock]
    @Binding var isChoosing:Bool
    @Binding var searchCommitted:Bool
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
                stockCell(stock: stock, isChoosing: self.$isChoosing, searchCommitted: self.$searchCommitted, checkedStocks: self.$checkedStocks)
            }
        }
    }
    
}


struct stockCell : View {
    var stock : Stock
    @Binding var isChoosing:Bool
    @Binding var searchCommitted:Bool
    @Binding var checkedStocks:[Stock]
        
    var body: some View {
        HStack {
            if isChoosing || (searchCommitted && stock.group == "") {
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
    @Binding var text: String
    @Binding var searchText:[String]?
    @Binding var searchCommitted:Bool

    var body: some View {
        HStack {
            TextField("以代號或簡稱來搜尋未加入股群的上市股票", text: $text, onEditingChanged: {    //began or end (bool)
                self.isEditing = $0
            }, onCommit: {
                self.searchText = self.text.replacingOccurrences(of: ",", with: " ").replacingOccurrences(of: "  ", with: " ").replacingOccurrences(of: "  ", with: " ").components(separatedBy: " ")
                self.searchCommitted = true
                self.isEditing = false
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
                                self.searchCommitted = false
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
                    self.searchCommitted = false
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
