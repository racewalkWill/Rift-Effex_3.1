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
    var airPlayViewController: PGLAirPlayMetalController?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {

        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        self.window = window


            // The 'window' property will automatically be loaded with the storyboard's initial view controller.
        // should use a second storyboard??
        airPlayViewController = UIStoryboard(name: "AirPlay", bundle: nil).instantiateViewController(withIdentifier: "MetalDeviceController") as? PGLAirPlayMetalController


        guard let myAppDelegate =  UIApplication.shared.delegate as? AppDelegate
          else { return }
          myAppDelegate.airPlaySceneDelegate = self
            // connect the airPlaySceneDelegate to the appDelegate

       //            else { return  }
        myAppDelegate.airPlayDeviceController =  airPlayViewController


        window.rootViewController = airPlayViewController
        window.isHidden = false
        window.rootViewController?.view.isHidden = false
        window.makeKeyAndVisible()
        NSLog("PGLAirPlaySceneDelegate: scene connected")

        connectChildRenderer()
            // makeKeyAndVisible has run viewWillAppear #setUpMetalRender, so the
            // PGLRenderOnAirPlay exists now. Connect here as well as in
            // #sceneWillEnterForeground - a scene connected from an iOS 27 scene
            // accessory is already foreground and may not send that event.

    }

    /// Point the main Renderer at the AirPlay Renderer so the main render loop
    /// drives the external display. Safe to call more than once.
    func connectChildRenderer() {
        guard let myAppDelegate =  UIApplication.shared.delegate as? AppDelegate
          else { return }

        if let mainRender = myAppDelegate.mainMetalController?.metalRender {
            if let childDeviceRenderer =
                myAppDelegate.airPlayDeviceController?.metalRender {
                mainRender.childDeviceRenderer = childDeviceRenderer as? PGLRenderOnAirPlay
            }
        }
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
//        let startViewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "MetalDeviceController")
//        guard let navigationController = window?.rootViewController as? UINavigationController else { return  }
//        navigationController.pushViewController(startViewController, animated: true)
//
//        guard let myAppDelegate =  UIApplication.shared.delegate as? AppDelegate
//          else { return }
//          myAppDelegate.airPlaySceneDelegate = self
//            // connect the airPlaySceneDelegate to the appDelegate
//        myAppDelegate.airPlayDeviceController =  startViewController as? PGLMetalDeviceController


        airPlayViewController?.setUpMetalRender()
        connectChildRenderer()

    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        NSLog( #function + " PGLAirPlaySceneDelegate")

    }

  

}
