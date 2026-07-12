//
//  PGLSupplementNavController.swift
//  RiftEffects
//
//  Created by Will on 5/16/22.
//  Copyright © 2022 Will Loew-Blosser. All rights reserved.
//

import UIKit
import os

class PGLSupplementNavController: UINavigationController {

    override func viewDidLoad() {
        super.viewDidLoad()
//        setRoot()
        // Do any additional setup after loading the view.
        Logger(subsystem: LogSubsystem, category: LogNavigation).info("\( String(describing: self) + "-" + #function)")



    }

    func navigationController(_ navigationController: UINavigationController,
                              willShow viewController: UIViewController,
                              animated: Bool) {
        Logger(subsystem: LogSubsystem, category: LogNavigation).info("\( String(describing: self) + "-" + #function)")
        Logger(subsystem: LogSubsystem, category: LogNavigation).info("    willShow \(viewController) " )

    }
    
    override func popViewController(animated: Bool) -> UIViewController? {
        Logger(subsystem: LogSubsystem, category: LogNavigation).info( "\("#popViewController " + String(describing: self)) + \(self.viewControllers)")

        let myPoppedController =  super.popViewController(animated: animated)
        Logger(subsystem: LogSubsystem, category: LogNavigation).info( "\("#removed " + String(describing: self)) + \(myPoppedController)")
        return myPoppedController
    }
    override func viewDidDisappear(_ animated: Bool) {
        super .viewDidDisappear(animated)
//        NSLog("PGLSelectFilterController #viewDidDisappear removing notification observor")

//        NotificationCenter.default.removeObserver(self, name: PGLShowStackImageContainer, object: self)
    }

        /// push StackImageController in the iPhone compact mode
    func pushStackImageContainer() -> Bool {
        // now moved back to the PGLStackController viewDidLoad...
        // remove this implementation?
        
        let iPhoneCompact =   (traitCollection.userInterfaceIdiom) == .phone
                                && (traitCollection.horizontalSizeClass == .compact)

        if iPhoneCompact {
            // either loaded by the supplementary nav controller OR
            // loaded as a content area in the two content container for stack & image controller
//            let isInsideContainer = parent is PGLStackImageContainerController
            let hasLoadedStackController = topViewController is PGLStackController

            if hasLoadedStackController {
                Logger(subsystem: LogSubsystem, category: LogNavigation).info("\( String(describing: self) + "-" + #function)")

                if let  stackImageController = storyboard?.instantiateViewController(withIdentifier: "PGLStackImageContainerController") as? PGLStackImageContainerController {

                    navigationController?.pushViewController(stackImageController, animated: true)
                    return true
                }
            else {
                return false
                }
            }
        }
        return false
    }

}
