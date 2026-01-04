//
//  AddEditTaskView.swift
//  smart todo
//
//  Created by Sourabh Mazumder on 4/1/2026.
//

import SwiftUI
import CoreData

enum DateType: String, CaseIterable {
    case dueDate = "dueDate"
    case toBeDoneIn = "toBeDoneIn"
    
    var displayName: String {
        switch self {
        case .dueDate:
            return "Due Date"
        case .toBeDoneIn:
            return "To be done in"
        }
    }
}

struct AddEditTaskView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    var task: TodoTask?
    
    @State private var title: String = ""
    @State private var selectedDateType: DateType = .dueDate
    @State private var dueDate: Date = Date()
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date().addingTimeInterval(3600) // 1 hour later
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Task Details")) {
                    TextField("Task Title", text: $title)
                }
                
                Section(header: Text("Date Type")) {
                    Picker("Date Type", selection: $selectedDateType) {
                        ForEach(DateType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                if selectedDateType == .dueDate {
                    Section(header: Text("Due Date")) {
                        DatePicker("Due Date", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                    }
                } else {
                    Section(header: Text("Time Range")) {
                        DatePicker("Start Date", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                        DatePicker("End Date", selection: $endDate, displayedComponents: [.date, .hourAndMinute])
                    }
                }
            }
            .navigationTitle(task == nil ? "New Task" : "Edit Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveTask()
                    }
                    .disabled(title.isEmpty)
                }
            }
            .onAppear {
                if let task = task {
                    title = task.title ?? ""
                    if let dateType = task.dateType {
                        selectedDateType = DateType(rawValue: dateType) ?? .dueDate
                    }
                    dueDate = task.dueDate ?? Date()
                    startDate = task.startDate ?? Date()
                    endDate = task.endDate ?? Date().addingTimeInterval(3600)
                }
            }
        }
    }
    
    private func saveTask() {
        withAnimation {
            let taskToSave: TodoTask
            if let existingTask = task {
                taskToSave = existingTask
            } else {
                taskToSave = TodoTask(context: viewContext)
                taskToSave.id = UUID()
                taskToSave.createdAt = Date()
                taskToSave.isCompleted = false
            }
            
            taskToSave.title = title
            taskToSave.dateType = selectedDateType.rawValue
            
            if selectedDateType == .dueDate {
                taskToSave.dueDate = dueDate
                taskToSave.startDate = nil
                taskToSave.endDate = nil
            } else {
                taskToSave.dueDate = nil
                taskToSave.startDate = startDate
                taskToSave.endDate = endDate
            }
            
            do {
                try viewContext.save()
                dismiss()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

