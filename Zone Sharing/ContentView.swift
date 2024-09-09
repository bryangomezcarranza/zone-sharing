//
//  ContentView.swift
//  Zone Sharing
//
//  Created by Bryan Gomez on 9/6/24.
//

import SwiftUI
import CloudKit

struct ContentView: View {
    @EnvironmentObject private var vm: ViewModelTwo
    @State private var isAddingPost = false
    @State private var isSharing = false
    @State private var isProcessingShare = false
    
    @State private var activeShare = false
    @State private var activeContainer: CKContainer?
    
    var body: some View {
        NavigationView {
            contentView
                .navigationTitle("Posts")
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button { Task { try await vm.refresh() } } label: { Image(systemName: "arrow.clockwise") }
                    }
                    ToolbarItem(placement: .navigationBarLeading) {
                        //
                    }
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button { Task { isAddingPost = true } } label: { Image(systemName: "plus") }
                    }
                }
        }
        .navigationViewStyle(.stack)
        .onAppear {
            Task {
                try await vm.refresh()
            }
        }
        .sheet(isPresented: $isAddingPost, content: {
            // Contact View
        })
        .sheet(isPresented: $isSharing, content: {
            //shareview
        })
    }
    
    private var contentView: some View {
        Group {
            switch vm.state {
            case let .loaded(privateContacts, sharedContacts):
                List {
                    Section(header: Text("Private")) {
                        ForEach(privateContacts) { postRowView(for: $0) }
                    }
                    Section(header: Text("Shared")) {
                        ForEach(sharedContacts) { postRowView(for: $0, shareable: false) }
                    }
                }.listStyle(GroupedListStyle())

            case .error(let error):
                VStack {
                    Text("An error occurred: \(error.localizedDescription)").padding()
                    Spacer()
                }

            case .loading:
                VStack { EmptyView() }
            }
        }
    }
    
    /// Builds a Contact row view for display contact information in a List.
     private func postRowView(for contact: Post, shareable: Bool = true) -> some View {
         HStack {
             VStack(alignment: .leading) {
                 Text(contact.message)
             }
             if shareable {
                 Spacer()
                 Button(action: { Task { try? await shareContact(contact) } }, label: { Image(systemName: "square.and.arrow.up") }).buttonStyle(BorderlessButtonStyle())
                     .sheet(isPresented: $isSharing, content: { shareView() })
             }
         }
     }
    
    // MARK: - Actions

      private func addContact(name: String, phoneNumber: String) async throws {
          try await vm.addContact(name: name, phoneNumber: phoneNumber)
          try await vm.refresh()
          isAddingContact = false
      }

      private func shareContact(_ contact: Contact) async throws {
          isProcessingShare = true

          do {
              let (share, container) = try await vm.fetchOrCreateShare(contact: contact)
              isProcessingShare = false
              activeShare = share
              activeContainer = container
              isSharing = true
          } catch {
              debugPrint("Error sharing contact record: \(error)")
          }
      }
}

struct ContentView_Preview: PreviewProvider {
    private static let previewPost: [Post] = [
        Post(id: UUID().uuidString, message: "Hello there", associatedRecord: CKRecord(recordType: "SharePost"))
    ]
    
    static var previews: some View {
        ContentView()
    }
}
