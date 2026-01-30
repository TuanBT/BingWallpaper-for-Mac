//
// UpdateScheduleManager.swift
// BingWallpaper
//
// Created by Laurenz Lazarus on 06.11.22.
//

import Foundation

public class UpdateScheduleManager {
   
   // Cache the settings instance to avoid creating new instance every time
   private static let settings = Settings()
   
   private static var fetchInterval: Double {
       return settings.updateIntervalHours * 3600
   }
   
   private init() { }
   
   public static func isUpdateNecessary() -> Bool {
       return nextFetchTimeInterval() == 0
   }
   
   public static func nextFetchTimeInterval() -> TimeInterval {
       if settings.useScheduledUpdate {
           return nextScheduledFetchTimeInterval()
       } else {
           return nextIntervalFetchTimeInterval()
       }
   }
   
   private static func nextIntervalFetchTimeInterval() -> TimeInterval {
       let lastUpdate = settings.lastUpdate
       return max(0, fetchInterval - abs(lastUpdate.timeIntervalSinceNow))
   }
   
   private static func nextScheduledFetchTimeInterval() -> TimeInterval {
       let now = Date()
       let calendar = Calendar.current
       let lastUpdate = settings.lastUpdate
       
       var components = calendar.dateComponents([.year, .month, .day], from: now)
       components.hour = settings.scheduledUpdateHour
       components.minute = settings.scheduledUpdateMinute
       components.second = 0
       
       guard let scheduledTimeToday = calendar.date(from: components) else {
           return nextIntervalFetchTimeInterval() // Fallback to interval mode
       }
       
       let scheduledHour = settings.scheduledUpdateHour
       let scheduledMinute = settings.scheduledUpdateMinute
       let scheduledTimeInMinutes = scheduledHour * 60 + scheduledMinute
       
       // Check if we already updated today after the scheduled time
       let alreadyUpdatedTodayAfterSchedule: Bool = {
           guard calendar.isDate(lastUpdate, inSameDayAs: now) else {
               return false // Last update was not today
           }
           
           let lastUpdateComponents = calendar.dateComponents([.hour, .minute], from: lastUpdate)
           guard let lastHour = lastUpdateComponents.hour, let lastMinute = lastUpdateComponents.minute else {
               return false
           }
           
           let lastTimeInMinutes = lastHour * 60 + lastMinute
           return lastTimeInMinutes >= scheduledTimeInMinutes
       }()
       
       // If scheduled time is in the future today, wait for it
       if scheduledTimeToday > now {
           return scheduledTimeToday.timeIntervalSince(now)
       }
       
       // Scheduled time has passed today
       if alreadyUpdatedTodayAfterSchedule {
           // Already updated today after scheduled time, schedule for tomorrow
           let scheduledTimeTomorrow = calendar.date(byAdding: .day, value: 1, to: scheduledTimeToday) ?? scheduledTimeToday
           let interval = scheduledTimeTomorrow.timeIntervalSince(now)
           return interval
       } else {
           // Scheduled time passed but we haven't updated yet today - UPDATE NOW!
           return 0
       }
   }
       
}
