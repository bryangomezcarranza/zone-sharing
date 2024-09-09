//
//  SceneDelegate.swift
//  Zone Sharing
//
//  Created by Bryan Gomez on 9/9/24.
//

import UIKit
import SwiftUI
import CloudKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    
    var window: UIWindow?
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        let contenView = ContentView().environmentObject(ViewModel())
        
        if let windowScene = scene as? UIWindowScene {
            let window = UIWindow(windowScene: windowScene)
            window.rootViewController = UIHostingController(rootView: contenView)
            self.window = window
            window.makeKeyAndVisible()
        }
    }
    
    func windowScene(_ windowScene: UIWindowScene, userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata) {
        guard cloudKitShareMetadata.containerIdentifier == Config.containerIndetifier else {
            print("Shared container identifier \(cloudKitShareMetadata.containerIdentifier) did not match known identifier")
            return
        }
        
        let container = CKContainer(identifier: Config.containerIndetifier)
        let operation = CKAcceptSharesOperation(shareMetadatas: [cloudKitShareMetadata])
        
        debugPrint("Accepting CloudKit Share with metadata: \(cloudKitShareMetadata)")
        
        operation.perShareResultBlock = { metadata, result in
            let shareRecordType = metadata.share.recordType
            
            switch result {
                
            case .success:
                debugPrint("Accepted CloudKit share with type: \(shareRecordType)")
            case .failure(let error):
                debugPrint("Error accepting share: \(error)")
            }
            
            operation.acceptSharesResultBlock = { result in
                if case .failure(let error) = result {
                    debugPrint("Error accepting CloudKit share: \(error)")
                }
            }
            
            operation.qualityOfService = .utility
            container.add(operation)
        }
    }
}

