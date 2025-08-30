//
//  PGLAppStackOptimize.swift
//  RiftEffects
//
//  Created by Will on 8/24/25.
//  Copyright © 2025 Will Loew-Blosser. All rights reserved.
//

import Foundation

import Combine
    /// `PGLAppStack` is responsible for managing and optimizing a stack of image processing layers or filters
    /// in the RiftEffects application. It coordinates notifications, publisher management with Combine,
    /// and provides an interface for releasing resources and optimizing the application's processing stack.
    ///
    /// Typical responsibilities may include:
    /// - Managing the list or stack of filters applied to an image or processing pipeline.
    /// - Handling Combine publishers for observing changes to the stack or its individual elements.
    /// - Providing functions to release resources and clean up Combine publishers when needed, such as when
    ///   a layer is removed or the entire stack is reset.
    /// - Offering optimization routines (such as `optimizeStack()`) to improve performance, memory usage,
    ///   or the effect-rendering pipeline based on current app state.
    ///
    /// This class or struct acts as the central coordinator for stack-based editing or compositing workflows
    /// within the app, ensuring consistent notification, resource, and processing management.
import UIKit

extension PGLAppStack {

 func releaseNotifications() {
        for aCancel in publishers {
            aCancel.cancel()
        }
        publishers = [any Cancellable]()
    }
///step through all filters in the stacks and remove filters that do not produce any changes in the output,
///optimize individual filters to produce changes by updating values
///compares rendered image output of a filter with the prior filters rendered output
func optimizeStack() {
    var passingFilters: [PGLFilterIndent] = []
    var failingFilters: [PGLFilterIndent] = []
    var currentOutput: UIImage?
    var previousOutput: UIImage?
    showFilterImage = true
    self.postFilterChangeRedraw()
    let startingAttribute = viewerStack.currentFilter().getInputImageAttribute()
    var startingImage = startingAttribute?.inputCollection?.imageAssets.first?.uiImage() ?? UIImage()
    previousOutput = startingImage

    for aFilter in flattenFilters() {
        _ = moveTo(filterIndent: aFilter)
        do {
            currentOutput = try appRenderer.captureImage()
        } catch {
            print("Error capturing image during stack optimization: \(error)")
        }
        if currentOutput != nil && currentOutput!.isEqual(previousOutput) {
            //image1 != nil && image1!.isEqual(image2)
            failingFilters.append(aFilter)
        } else {
            passingFilters.append(aFilter)

        }
        previousOutput = currentOutput ?? UIImage() // advance for next pass


    }
    NSLog(#function + " passingFilters = \(passingFilters)")
    if !failingFilters.isEmpty {
        NSLog(#function + " failingFilters = \(failingFilters)")
    }

}

}
