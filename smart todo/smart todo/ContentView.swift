//
//  ContentView.swift
//  smart todo
//
//  Created by Sourabh Mazumder on 4/1/2026.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \TodoTask.isCompleted, ascending: true),
            NSSortDescriptor(keyPath: \TodoTask.createdAt, ascending: false)
        ],
        animation: .default)
    private var tasks: FetchedResults<TodoTask>
    
    @State private var showingAddTask = false
    @State private var selectedTask: TodoTask?

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if tasks.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "checklist")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("No tasks yet")
                            .font(.title2)
                            .foregroundColor(.gray)
                        Text("Tap the + button to add your first task")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(tasks) { task in
                            TaskRow(task: task) {
                                toggleTaskCompletion(task)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedTask = task
                                showingAddTask = true
                            }
                        }
                        .onDelete(perform: deleteTasks)
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("My Tasks")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        selectedTask = nil
                        showingAddTask = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddTask) {
                AddEditTaskView(task: selectedTask)
            }
        }
    }
    
    private func toggleTaskCompletion(_ task: TodoTask) {
        withAnimation {
            task.isCompleted.toggle()
            
            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    private func deleteTasks(offsets: IndexSet) {
        withAnimation {
            offsets.map { tasks[$0] }.forEach(viewContext.delete)
            
            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

#Preview {
    ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
