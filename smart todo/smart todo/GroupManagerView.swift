//
//  GroupManagerView.swift
//  smart todo
//
//  Created by Sourabh Mazumder on 4/1/2026.
//

import SwiftUI
import CoreData

struct GroupManagerView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Group.createdAt, ascending: true)],
        animation: .default)
    private var groups: FetchedResults<Group>
    
    @State private var showingAddGroup = false
    @State private var editingGroup: Group?
    
    var body: some View {
        NavigationView {
            List {
                if groups.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "folder")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("No groups yet")
                            .font(.title3)
                            .foregroundColor(.gray)
                        Text("Tap the + button to create your first group")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    ForEach(groups) { group in
                        HStack {
                            Image(systemName: "folder.fill")
                                .foregroundColor(.blue)
                            Text(group.name ?? "Unnamed Group")
                                .font(.body)
                            Spacer()
                            if let taskCount = group.tasks?.count, taskCount > 0 {
                                Text("\(taskCount)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.secondary.opacity(0.2))
                                    .cornerRadius(8)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            editingGroup = group
                            showingAddGroup = true
                        }
                    }
                    .onDelete(perform: deleteGroups)
                }
            }
            .navigationTitle("Groups")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        editingGroup = nil
                        showingAddGroup = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddGroup) {
                AddEditGroupView(group: editingGroup)
            }
        }
    }
    
    private func deleteGroups(offsets: IndexSet) {
        withAnimation {
            offsets.map { groups[$0] }.forEach(viewContext.delete)
            
            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

struct AddEditGroupView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    var group: Group?
    
    @State private var name: String = ""
    
    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespaces)
    }
    
    private var isNameValid: Bool {
        !trimmedName.isEmpty && trimmedName.count <= 5
    }
    
    private var nameBinding: Binding<String> {
        Binding(
            get: { name },
            set: { newValue in
                if newValue.count <= 5 {
                    name = newValue
                } else {
                    name = String(newValue.prefix(5))
                }
            }
        )
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Group Details"), footer: Text(trimmedName.count > 5 ? "Group name must be 5 characters or less" : "").foregroundColor(.red)) {
                    TextField("Group Name (max 5 characters)", text: nameBinding)
                    if trimmedName.count > 0 {
                        Text("\(trimmedName.count)/5 characters")
                            .font(.caption)
                            .foregroundColor(trimmedName.count > 5 ? .red : .secondary)
                    }
                }
            }
            .navigationTitle(group == nil ? "New Group" : "Edit Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveGroup()
                    }
                    .disabled(!isNameValid)
                }
            }
            .onAppear {
                if let group = group {
                    name = group.name ?? ""
                }
            }
        }
    }
    
    private func saveGroup() {
        withAnimation {
            guard isNameValid else { return }
            
            let groupToSave: Group
            if let existingGroup = group {
                groupToSave = existingGroup
            } else {
                groupToSave = Group(context: viewContext)
                groupToSave.id = UUID()
                groupToSave.createdAt = Date()
            }
            
            groupToSave.name = trimmedName
            
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

#Preview {
    GroupManagerView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

