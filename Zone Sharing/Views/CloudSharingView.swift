//
//  CloudSharingView.swift
//  Zone Sharing
//
//  Created by Bryan Gomez on 9/9/24.
//

import Foundation
import SwiftUI
import CloudKit
import UIKit

struct CloudSharingView: UIViewControllerRepresentable {
    
    //MARK: - Properties
    @Environment(\.presentationMode) var presentationMode
    let container: CKContainer
    let share: CKShare
    
    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {}
    
    func makeUIViewController(context: Context) -> some UIViewController {
        let sharingController = UICloudSharingController(share: share, container: container)
        sharingController.availablePermissions = [.allowReadWrite, .allowPrivate]
        sharingController.delegate = context.coordinator
        sharingController.modalPresentationStyle = .formSheet
        
        return sharingController
    }
    
    func makeCoordinator() -> CloudSharingView.Coordinator {
        Coordinator()
    }
    
    final class Coordinator: NSObject, UICloudSharingControllerDelegate {
        func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
            debugPrint("Error saving share: \(error)")
        }
        
        func itemTitle(for csc: UICloudSharingController) -> String? {
            "Zone Sharing Example"
        }
    }
}
