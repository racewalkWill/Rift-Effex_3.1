//
//  PGLNavSecondaryController.swift
//  RiftEffects
//
//  Created by Will on 5/23/22.
//  Copyright © 2022 Will Loew-Blosser. All rights reserved.
//

import UIKit
import os

class PGLNavSecondaryController: UINavigationController {

    override func viewDidLoad() {
        super.viewDidLoad()
        Logger(subsystem: LogSubsystem, category: LogNavigation).info("\( String(describing: self) + "-" + #function)")
        
        // Do any additional setup after loading the view.
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


    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
