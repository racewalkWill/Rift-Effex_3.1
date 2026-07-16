//
//  PGLNavStackImageController.swift
//  RiftEffects
//
//  Created by Will on 5/23/22.
//  Copyright © 2022 Will Loew-Blosser. All rights reserved.
//

import UIKit
import os
class PGLNavStackImageController: UINavigationController, UINavigationControllerDelegate {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        Logger(subsystem: LogSubsystem, category: LogNavigation).info("\( String(describing: self) + "-" + #function)")
        // Do any additional setup after loading the view.
        setNavigationBarHidden(false, animated: false)
        delegate = self
        
    }
   func navigationController(_ navigationController: UINavigationController,
                             willShow viewController: UIViewController,
                             animated: Bool) {
       Logger(subsystem: LogSubsystem, category: LogNavigation).info("\( String(describing: self) + "-" + #function)")
       Logger(subsystem: LogSubsystem, category: LogNavigation).info("    willShow \(viewController) " )

   }

    func navigationController(_ navigationController: UINavigationController,
                              didShow viewController: UIViewController,
                              animated: Bool) {
        pruneEditContainers(below: viewController)
    }

    /// Cap the edit-flow depth. Each add-filter/adjust-parms cycle pushes new
    /// PGLFilterImageContainerController / PGLParmImageController instances, so
    /// the stack grows two controllers per cycle — each holding its own
    /// PGLCompactImageController with a Metal view. Once a new container is
    /// fully shown, the older filter/parm containers beneath it are history the
    /// back arrow should skip anyway: remove and release them.
    /// PGLStackImageContainerController is the base of the edit flow and kept.
    /// Runs from didShow (never willShow) so the stack is not mutated while a
    /// transition is in flight.
    private func pruneEditContainers(below topController: UIViewController) {
        guard topController is PGLTwoColumnSplitController else { return }

        let staleContainers = viewControllers.filter {
            $0 !== topController
                && $0 is PGLTwoColumnSplitController
                && !($0 is PGLStackImageContainerController)
        }
        if staleContainers.isEmpty { return }

        Logger(subsystem: LogSubsystem, category: LogNavigation).info( "\("#pruneEditContainers " + String(describing: self)) removing \(staleContainers)")

        viewControllers.removeAll { candidate in
            staleContainers.contains { $0 === candidate } }
        for aContainer in staleContainers {
            (aContainer as? PGLTwoColumnSplitController)?.viewControllerRelease()
        }
    }

    override func popViewController(animated: Bool) -> UIViewController? {
        Logger(subsystem: LogSubsystem, category: LogNavigation).info( "\("#popViewController " + String(describing: self)) + \(self.viewControllers)")

        let myPoppedController =  super.popViewController(animated: animated)
        Logger(subsystem: LogSubsystem, category: LogNavigation).info( "\("#removed " + String(describing: self)) + \(myPoppedController)")
        if let pglController = myPoppedController as? PGLTwoColumnSplitController {
            pglController.viewControllerRelease()
        }
        return myPoppedController
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
