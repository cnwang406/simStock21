//
//  checkInternet.swift
//  simStock
//
//  Created by peiyu on 2016/6/23.
//  Copyright © 2016年 unLock.com.tw. All rights reserved.
//

import Foundation
import SystemConfiguration

public class NetConnection {  // 偵測網路連線是否有效
    class func isConnectedToNetwork() -> Bool {
        var zeroAddress = sockaddr_in()
        zeroAddress.sin_len = UInt8(MemoryLayout.size(ofValue: zeroAddress))
        zeroAddress.sin_family = sa_family_t(AF_INET)

        let defaultRouteReachability = withUnsafePointer(to: &zeroAddress) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {zeroSockAddress in
                SCNetworkReachabilityCreateWithAddress(nil, zeroSockAddress)
            }
        }
        var flags = SCNetworkReachabilityFlags()
        if !SCNetworkReachabilityGetFlags(defaultRouteReachability!, &flags) {
            return false
        }
        let isReachable = (flags.rawValue & UInt32(kSCNetworkFlagsReachable)) != 0
        let needsConnection = (flags.rawValue & UInt32(kSCNetworkFlagsConnectionRequired)) != 0
        return (isReachable && !needsConnection)
    }
}


public class twDateTime { //用於台灣當地日期時間的一些計算函數，避免不同時區的時差問題

    static let calendar:Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.locale = Locale(identifier: "zh-TW")
        c.timeZone = TimeZone(identifier: "Asia/Taipei")!
        return c
    } ()

    class func formatter(_ format:String="yyyy/MM/dd") -> DateFormatter  {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh-TW")
        formatter.timeZone = TimeZone(identifier: "Asia/Taipei")!
        formatter.dateFormat = format
        return formatter
    }

    class func timeAtDate(_ date:Date=Date(), hour:Int, minute:Int, second:Int=0) -> Date {
        var dtComponents = calendar.dateComponents(in: TimeZone(identifier: "Asia/Taipei")!, from: date)
        dtComponents.hour = hour
        dtComponents.minute = minute
        dtComponents.second = second
        dtComponents.nanosecond = 0
        if let theTime = calendar.date(from: dtComponents) {
            return theTime
        } else {
            return self.startOfDay(date)
        }
    }


    class func time0900(_ date:Date=Date(), delayMinutes:Int=0) -> Date {
        if delayMinutes < 0 || delayMinutes > 60 {
            if let dt = self.calendar.date(byAdding: .minute, value: delayMinutes, to: self.timeAtDate(date, hour: 9, minute: 0)) {
                return dt
            }
        }
        return self.timeAtDate(date, hour: 09, minute: delayMinutes)
    }

    class func time1330(_ date:Date=Date(), delayMinutes:Int=0) -> Date {
        if delayMinutes < -30 || delayMinutes > 30 {
            if let dt = self.calendar.date(byAdding: .minute, value: delayMinutes, to: self.timeAtDate(date, hour: 13, minute: 30)) {
                return dt
            }
        }
        return self.timeAtDate(date, hour: 13, minute: 30+delayMinutes)
    }

    class func startOfDay(_ date:Date=Date()) -> Date {
        let dt = self.timeAtDate(date, hour: 0, minute: 0, second: 0)
        return dt
    }


    class func endOfDay(_ date:Date=Date()) -> Date {
        let dt = self.timeAtDate(date, hour: 23, minute: 59, second: 59)
        return dt
    }

    class func isDateInToday(_ date:Date) -> Bool {
        if date.compare(self.startOfDay()) != .orderedAscending && date.compare(self.endOfDay()) != .orderedDescending {
            return true
        } else {
            return false
        }
    }

    class func startOfMonth(_ date:Date=Date()) -> Date {
        let yyyyMM:DateComponents = self.calendar.dateComponents([.year, .month], from: date)

        if let dt = self.calendar.date(from: yyyyMM) {
            return self.startOfDay(dt)
        } else {
            return date
        }
    }

    class func endOfMonth(_ date:Date=Date()) -> Date {
        if let dt = self.calendar.date(byAdding: DateComponents(month: 1, day: -1), to: self.startOfMonth(date)) {
            return dt
        } else {
            return date
        }
    }

    class func yesterday(_ date:Date=Date()) -> Date {
        if let dt = self.calendar.date(byAdding: .day, value: -1, to: date) {
            return self.startOfDay(dt)
        } else {
            return self.startOfDay(date)
        }
    }

    class func back10Days(_ date:Date) -> Date {
        if let dt = self.calendar.date(byAdding: .day, value: -10, to: date) {
            return self.startOfDay(dt)
        } else {
            return self.startOfDay(date)
        }
    }

    class func dateFromString(_ date:String, format:String="yyyy/MM/dd") -> Date? {
        if let dt = self.formatter(format).date(from: date) {
            return dt
        } else {
            return nil
        }
    }

    class func stringFromDate(_ date:Date=Date(), format:String="yyyy/MM/dd") -> String {
        let dt = self.formatter(format).string(from: date)
        return dt
    }

    class func marketingTime(_ time:Date=Date(), delay:Int = 0) -> Bool {
        let time1330 = self.time1330(time, delayMinutes:delay)
        let time0900 = self.time0900(time, delayMinutes:0 - delay)
        if (time.compare(time1330) == .orderedAscending && time.compare(time0900) != .orderedAscending) {
            return true
        } else {
            return false    //盤外時間
        }

    }
    
}
