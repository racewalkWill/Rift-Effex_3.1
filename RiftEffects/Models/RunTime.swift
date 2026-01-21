//
//  RunTime.swift
//  RiftEffects
//
//  Created by Will on 1/21/26.
//  Copyright © 2026 Will Loew-Blosser. All rights reserved.
//

extension PGLFilterAttribute {


    func estimateParmRunSeconds(userEnteredSeconds: Float  ) -> Double {
        var parmRunTime : Double = 0.0
        if !hasAnimation() { return parmRunTime }

            // add estimate for parmList and running vary
            // attributeValueDelta is a Float?; convert safely to Double and ensure correct precedence
        let estimatedVaryTime: Double = Double(varyTotalFrames) * Double(attributeValueDelta ?? 0.0)

        var estimatedListTime: Double = 0.0
        if hasInputCollection(), let list = inputCollection {
            let sizeCount = Double(list.maxAssetsOrImagesCount())
            estimatedListTime = Double(userEnteredSeconds) * sizeCount
        }

            // and stack estimated time (not currently used)
        var childStackEstimateSeconds: Double = 0.0
        if hasFilterStackInput() {
            childStackEstimateSeconds = inputStack?.estimateStackRunSeconds() ?? 0.0
        }
        parmRunTime = estimatedVaryTime + estimatedListTime + childStackEstimateSeconds
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
