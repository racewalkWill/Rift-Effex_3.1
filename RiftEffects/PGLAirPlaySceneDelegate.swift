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

        let startViewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "MetalDeviceController")


        self.window = window

        guard let myAppDelegate =  UIApplication.shared.delegate as? AppDelegate
          else { return }
          myAppDelegate.airPlaySceneDelegate = self
            // connect the airPlaySceneDelegate to the appDelegate
        myAppDelegate.airPlayDeviceController =  startViewController as? PGLMetalDeviceController
        NSLog("PGLAirPlaySceneDelegate: scene connected")
        window.makeKeyAndVisible()
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // clean up time
        NSLog("PGLAirPlaySceneDelegate: scene disconnected")
        guard let myAppDelegate =  UIApplication.shared.delegate as? AppDelegate
          else { return }
        if let mainRender = myAppDelegate.mainMetalController?.metalRender {
            mainRender.childDeviceRenderer = nil
        }
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        NSLog( #function + " PGLAirPlaySceneDelegate")
        // connect the Renderer to the PGLMetalDeviceController. pglRenderAirPlayDevice
        guard let myAppDelegate =  UIApplication.shared.delegate as? AppDelegate
          else { return }
        if let mainRender = myAppDelegate.mainMetalController?.metalRender {
            if let childDeviceRenderer =
                myAppDelegate.airPlayDeviceController?.metalRender {
                mainRender.childDeviceRenderer = childDeviceRenderer as? PGLRenderAirPlayDevice
            }

        }

    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        NSLog( #function + " PGLAirPlaySceneDelegate")

    }

  

}
