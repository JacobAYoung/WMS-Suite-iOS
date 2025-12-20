//
//  CalendarView.swift
//  WMS Suite
//
//  Calendar view showing scheduled jobs
//

import SwiftUI
import CoreData

struct CalendarView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.calendar) var calendar
    
    @State private var selectedDate = Date()
    @State private var displayedMonth = Date()
    
    var body: some View {
        VStack(spacing: 0) {
            // Month navigation
            monthNavigationBar
            
            // Calendar grid
            calendarGrid
            
            // Jobs for selected date
            Divider()
            jobsList
        }
        .navigationTitle("Calendar")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
    
    // MARK: - Month Navigation
    
    private var monthNavigationBar: some View {
        HStack {
            Button(action: previousMonth) {
                Image(systemName: "chevron.left")
                    .font(.title3)
            }
            
            Spacer()
            
            Text(displayedMonth, format: .dateTime.month(.wide).year())
                .font(.headline)
            
            Spacer()
            
            Button(action: nextMonth) {
                Image(systemName: "chevron.right")
                    .font(.title3)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
    }
    
    // MARK: - Calendar Grid
    
    private var calendarGrid: some View {
        VStack(spacing: 0) {
            // Day headers
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 0) {
                ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
            }
            
            Divider()
            
            // Calendar days
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 0) {
                ForEach(Array(daysInMonth().enumerated()), id: \.offset) { index, date in
                    if let date = date {
                        CalendarDayCell(
                            date: date,
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                            isToday: calendar.isDateInToday(date),
                            hasJobs: jobCount(for: date) > 0,
                            jobCount: jobCount(for: date)
                        )
                        .onTapGesture {
                            selectedDate = date
                        }
                    } else {
                        Color.clear
                            .frame(height: 50)
                    }
                }
            }
        }
    }
    
    // MARK: - Jobs List
    
    private var jobsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(selectedDate, format: .dateTime.month(.wide).day())
                    .font(.headline)
                
                Spacer()
                
                Text("\(jobsForSelectedDate.count) jobs")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.top, 12)
            
            ScrollView {
                if jobsForSelectedDate.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        Text("No jobs scheduled")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(jobsForSelectedDate, id: \.id) { job in
                            NavigationLink(destination: JobDetailView(job: job)) {
                                CalendarJobRow(job: job)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private var jobsForSelectedDate: [Job] {
        Job.fetchJobs(for: selectedDate, context: viewContext)
    }
    
    private func jobCount(for date: Date) -> Int {
        Job.fetchJobs(for: date, context: viewContext).count
    }
    
    private func daysInMonth() -> [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth),
              let monthFirstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start) else {
            return []
        }
        
        let monthLastWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.end - 1)
        
        guard let lastWeek = monthLastWeek else { return [] }
        
        var days: [Date?] = []
        var currentDate = monthFirstWeek.start
        
        while currentDate < lastWeek.end {
            if calendar.isDate(currentDate, equalTo: displayedMonth, toGranularity: .month) {
                days.append(currentDate)
            } else {
                days.append(nil)
            }
            
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else {
                break
            }
            currentDate = nextDate
        }
        
        return days
    }
    
    private func previousMonth() {
        guard let newMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) else {
            return
        }
        displayedMonth = newMonth
    }
    
    private func nextMonth() {
        guard let newMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) else {
            return
        }
        displayedMonth = newMonth
    }
}

// MARK: - Calendar Day Cell

struct CalendarDayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let hasJobs: Bool
    let jobCount: Int
    
    var body: some View {
        VStack(spacing: 4) {
            Text(date, format: .dateTime.day())
                .font(.body)
                .fontWeight(isToday ? .bold : .regular)
                .foregroundColor(isSelected ? .white : (isToday ? .blue : .primary))
            
            if hasJobs {
                Circle()
                    .fill(isSelected ? Color.white : Color.blue)
                    .frame(width: 6, height: 6)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.blue : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isToday && !isSelected ? Color.blue : Color.clear, lineWidth: 1)
        )
    }
}

// MARK: - Calendar Job Row

struct CalendarJobRow: View {
    let job: Job
    
    var body: some View {
        HStack {
            if let type = job.jobTypeEnum {
                Image(systemName: type.icon)
                    .foregroundColor(Color(type.color))
                    .frame(width: 24)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(job.displayTitle)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if let customer = job.customer {
                    Text(customer.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let time = job.scheduledDate {
                    Text(time.formatted(date: .omitted, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Text(job.statusText)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(job.statusColor).opacity(0.2))
                .foregroundColor(Color(job.statusColor))
                .cornerRadius(8)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
    }
}
