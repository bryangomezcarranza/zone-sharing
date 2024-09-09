//
//  AddPostView.swift
//  Zone Sharing
//
//  Created by Bryan Gomez on 9/9/24.
//

import SwiftUI
import Foundation

struct AddPostView: View {
    @State private var messageInput: String = ""
    
    let onAdd: ((String) async throws -> Void)?
    let onCancel: (() -> Void)?
    
    var body: some View {
        NavigationView {
            VStack {
                TextField("Write a message", text: $messageInput)
                Spacer()
            }
            .padding()
            .navigationTitle("Create Post")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: { onCancel?() })
                }
                ToolbarItem(placement: .confirmationAction) {
                    
                    Button("Save", action: { Task { try? await onAdd?(messageInput) } })
                        .disabled(messageInput.isEmpty)
                }
            }
        }
    }
}
