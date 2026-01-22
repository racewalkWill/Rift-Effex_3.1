//
//  EstimatedRunTime.swift
//  RiftEffects
//
//  Created by Will on 1/21/26.
//  Copyright © 2026 Will Loew-Blosser. All rights reserved.
//
import UIKit
extension PGLFilterAttribute {


    func estimateParmRunSeconds(userEnteredSeconds: Float  ) -> Double {
        var parmRunTime : Double = 0.0
//        if !hasAnimation() { return parmRunTime }

            // add estimate for parmList and running vary
            // attributeValueDelta is a Float?; convert safely to Double and ensure correct precedence
        let estimatedVaryTime: Double = Double(varyTotalFrames) * Double(attributeValueDelta ?? 0.0)
//        let checkVary = abs(estimatedVaryTime)
//        if checkVary > 400 {
//            NSLog(#function + ": estimatedVaryTime: \(estimatedVaryTime)")
//        }
        var estimatedListTime: Double = 0.0
        if hasInputCollection(), let list = inputCollection {
            let sizeCount = Double(list.maxAssetsOrImagesCount())
            // transition filters use dt to increment filter time in steps up in range of 0..1
            // smaller dt is longer cycle
            // total frames is 60 * lengthseconds
            // dt is 1/totalFrames
            // lengthSeconds = (1/dt)/60
            let filterDt = aSourceFilter.dt
//            NSLog(#function + ": filterDt: \(filterDt)")
            let durationSeconds = (1.0/filterDt)/60.0
            estimatedListTime = Double(durationSeconds) * sizeCount
//            NSLog(#function + ": estimatedListTime: \(estimatedListTime)")
        }

            // and stack estimated time (not currently used)
        var childStackEstimateSeconds: Double = 0.0
        if hasFilterStackInput() {
            childStackEstimateSeconds = inputStack?.estimateStackRunSeconds() ?? 0.0
        }
//        NSLog(#function + ": estimatedVaryTime: \(estimatedVaryTime), estimatedListTime: \(estimatedListTime), childStackEstimateSeconds: \(childStackEstimateSeconds)")
        parmRunTime = abs(estimatedVaryTime) + abs(estimatedListTime) + abs(childStackEstimateSeconds)
        return parmRunTime


    }
}

extension PGLFilterStack {
    func estimateStackRunSeconds() -> Double {
        var totalSeconds: Double = 0.0
        for aFilter in activeFilters {
            let thisFilterTime: Double = aFilter.estimateStackRunSeconds()
            totalSeconds += thisFilterTime
        }
        return totalSeconds
    }
}

extension PGLImageList {
    
    func estimateRunSeconds(secondsPerFrame: Double? = 0.0) -> Double {
        if self.isEmpty() { return 0.0 }
        let myCount  = Double(maxAssetsOrImagesCount())
        let runSeconds = myCount * (secondsPerFrame ?? 0.0)
        if runSeconds.isInfinite || runSeconds.isNaN {
            return 0.0
        }
        return runSeconds
    }

}

extension PGLSourceFilter {
    func  estimateStackRunSeconds() -> Double {
        var filterRunTime: Double = 0.0
        for aParm in attributes {
            filterRunTime += aParm.estimateParmRunSeconds(userEnteredSeconds: userLengthSeconds)
        }
        return filterRunTime
    }
}
