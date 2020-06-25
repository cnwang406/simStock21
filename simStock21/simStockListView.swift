//
//  simStockListView.swift
//  simStock21
//
//  Created by peiyu on 2020/6/24.
//  Copyright © 2020 peiyu. All rights reserved.
//

import SwiftUI
struct simStockListView: View {
    
    @ObservedObject var list: simStockList
    @Environment(\.managedObjectContext) var context
        
    func title(_ stocks:[Stock]) -> String {
        return (stocks[0].group == "" ? "<搜尋結果>" : "[\(stocks[0].group)]")
    }
    
    

    var body: some View {
        NavigationView {
            VStack {
                SearchBar(text: "", searchText: $list.searchText)
                List{
                    ForEach(list.groups, id: \.self) {(stocks:[Stock]) in
                        Section(header: Text(self.title(stocks)),footer: Text("\(stocks.count)支股")) {
                            ForEach(stocks, id: \.sId) {stock in
                                stockCell(stock: stock)
                            }
                            .onDelete { indexSet in
                                if let index = indexSet.first {
                                    self.list.removeStock(sId: stocks[index].sId)
                                }
                            }
                        }
                    }
                }
                .listStyle(GroupedListStyle())
            }
        }
        .navigationBarHidden(true)

    }

    func delete(at:IndexSet,stocks:[Stock]) {
        print(at.startIndex)
    }
}

struct stockCell : View {
    var stock : Stock
    var body: some View {
        Group {
            if stock.group == "" {
                HStack {
                    Text(stock.sId)
                        .frame(width : 50.0, alignment: .leading)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text(stock.sName)
                        .frame(width : 80.0, alignment: .leading)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
            } else {
                NavigationLink(destination: stockPage(stock: stock)) {
                    HStack {
                        Text(stock.sId)
                            .frame(width : 50.0, alignment: .leading)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        Text(stock.sName)
                            .frame(width : 80.0, alignment: .leading)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                }
                .navigationBarTitle("")
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
    @State var text: String
    @State private var isEditing = false
    @Binding var searchText:String
 
    var body: some View {
        HStack {
            TextField("Search ...", text: $text, onEditingChanged: {
                self.isEditing = $0
            }, onCommit: {
                self.searchText = self.text
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
                                self.searchText = ""
                           }) {
                               Image(systemName: "multiply.circle.fill")
                                   .foregroundColor(.gray)
                                   .padding(.trailing, 8)
                           }
                       }
                   }
                )
                .padding(.horizontal, 10)
//                .onTapGesture {
//                    self.isEditing = true
//                }
 
            if isEditing {
                Button(action: {
                    self.isEditing = false
                    self.text = ""
                    self.searchText = ""
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)  // Dismiss the keyboard
                }) {
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
