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
        if hasInputCollection(), let list = statusImageList, let mySourceFilter = aSourceFilter {
            let sizeCount = Double(list.maxAssetsOrImagesCount())
            // transition filters use dt to increment filter time in steps up in range of 0..1
            // smaller dt is longer cycle
            // total frames is 60 * lengthseconds
            // dt is 1/totalFrames
            // lengthSeconds = (1/dt)/60
            let filterDt = mySourceFilter.dt
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

    /// play length of the video when the only input image is a single video.
    /// Kept separate from estimateParmRunSeconds so the filter can use the longest
    /// of several single video inputs - they play concurrently, not in sequence
    func estimateSingleVideoSeconds() -> Double {
        return statusImageList?.singleVideoSeconds() ?? 0.0
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

    /// play length of the video when the list holds only a single video asset.
    /// nil for a multiple element list or a single still image
    func singleVideoSeconds() -> Double? {
        guard isSingular(),
              let onlyAsset = firstAsset(),
              onlyAsset.isVideo(),
              let phAsset = onlyAsset.asset
        else { return nil }
            // PHAsset.duration is metadata - available before the video player loads
        let seconds = phAsset.duration
        if seconds.isInfinite || seconds.isNaN || seconds <= 0 { return nil }
        return seconds
    }

}

extension PGLSourceFilter {
    func  estimateStackRunSeconds() -> Double {
        var filterRunTime: Double = 0.0
        var longestVideoSeconds: Double = 0.0
        for aParm in attributes {
            filterRunTime += aParm.estimateParmRunSeconds(userEnteredSeconds: userLengthSeconds)
                // single video inputs play concurrently - use the longest, not the sum
            longestVideoSeconds = max(longestVideoSeconds, aParm.estimateSingleVideoSeconds())
        }
        return filterRunTime + longestVideoSeconds
    }
}
