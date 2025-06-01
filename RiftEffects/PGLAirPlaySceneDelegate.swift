//
//  PGLAirPlaySceneDelegate.swift
//  RiftEffects
//
//  Created by Loew-Blosser on 6/1/25.
//  Copyright © 2025 Will Loew-Blosser. All rights reserved.
//

import UIKit

class PGLAirPlaySceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {

        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)

        let startViewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "MetalController")

        window.rootViewController =  startViewController
        self.window = window

        //        guard let myAppDelegate =  UIApplication.shared.delegate as? AppDelegate
        //          else { return }
        //          myAppDelegate.windowSceneDelegate = self  // connect the windowSceneDelegate to the appDelegate
        NSLog("PGLAirPlaySceneDelegate: scene connected")
        window.makeKeyAndVisible()
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        NSLog( #function + " PGLAirPlaySceneDelegate")
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        NSLog( #function + " PGLAirPlaySceneDelegate")

    }

  

}
