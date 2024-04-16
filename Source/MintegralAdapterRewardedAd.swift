// Copyright 2022-2024 Chartboost, Inc.
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file.

import ChartboostMediationSDK
import Foundation
import MTGSDK
import MTGSDKReward

/// The Chartboost Mediation Mintegral adapter rewarded ad.
final class MintegralAdapterRewardedAd: MintegralAdapterAd, PartnerAd {
    
    /// The partner ad view to display inline. E.g. a banner view.
    /// Should be nil for full-screen ads.
    var inlineView: UIView? { nil }

    /// The loaded partner ad banner size.
    /// Should be `nil` for full-screen ads.
    var bannerSize: PartnerBannerSize? { nil }

    /// Loads an ad.
    /// - parameter viewController: The view controller on which the ad will be presented on. Needed on load for some banners.
    /// - parameter completion: Closure to be performed once the ad has been loaded.
    func load(with viewController: UIViewController?, completion: @escaping (Result<PartnerDetails, Error>) -> Void) {
        log(.loadStarted)
        
        loadCompletion = completion
        
        if let adm = request.adm {
            MTGBidRewardAdManager.sharedInstance().loadVideo(
                withBidToken: adm,
                placementId: request.partnerPlacement,
                unitId: unitID,
                delegate: self
            )
        } else {
            MTGRewardAdManager.sharedInstance().loadVideo(
                withPlacementId: request.partnerPlacement,
                unitId: unitID,
                delegate: self
            )
        }
    }
    
    /// Shows a loaded ad.
    /// It will never get called for banner ads. You may leave the implementation blank for that ad format.
    /// - parameter viewController: The view controller on which the ad will be presented on.
    /// - parameter completion: Closure to be performed once the ad has been shown.
    func show(with viewController: UIViewController, completion: @escaping (Result<PartnerDetails, Error>) -> Void) {
        log(.showStarted)
        
        showCompletion = completion
        
        if request.adm != nil {
            MTGBidRewardAdManager.sharedInstance().showVideo(
                withPlacementId: request.partnerPlacement,
                unitId: unitID,
                userId: nil,
                delegate: self,
                viewController: viewController
            )
        } else {
            MTGRewardAdManager.sharedInstance().showVideo(
                withPlacementId: request.partnerPlacement,
                unitId: unitID,
                userId: nil,
                delegate: self,
                viewController: viewController
            )
        }
    }
}

extension MintegralAdapterRewardedAd: MTGRewardAdLoadDelegate {
    
    func onVideoAdLoadSuccess(_ placementId: String?, unitId: String?) {
        log(.loadSucceeded)
        loadCompletion?(.success([:])) ?? log(.loadResultIgnored)
        loadCompletion = nil
    }

    func onVideoAdLoadFailed(_ placementId: String?, unitId: String?, error: Error) {
        log(.loadFailed(error))
        loadCompletion?(.failure(error)) ?? log(.loadResultIgnored)
        loadCompletion = nil
    }
}

extension MintegralAdapterRewardedAd: MTGRewardAdShowDelegate {
    
    func onVideoAdShowSuccess(_ placementId: String?, unitId: String?) {
        log(.showSucceeded)
        showCompletion?(.success([:])) ?? log(.showResultIgnored)
        showCompletion = nil
    }

    func onVideoAdShowFailed(_ placementId: String?, unitId: String?, withError error: Error) {
        log(.showFailed(error))
        showCompletion?(.failure(error)) ?? log(.showResultIgnored)
        showCompletion = nil
    }

    func onVideoAdClicked(_ placementId: String?, unitId: String?) {
        log(.didClick(error: nil))
        delegate?.didClick(self, details: [:]) ?? log(.delegateUnavailable)
    }

    func onVideoAdDidClosed(_ placementId: String?, unitId: String?) {
        log(.didDismiss(error: nil))
        delegate?.didDismiss(self, details: [:], error: nil) ?? log(.delegateUnavailable)
    }

    func onVideoAdDismissed(_ placementId: String?, unitId: String?, withConverted converted: Bool, withRewardInfo rewardInfo: MTGRewardAdInfo?) {
        log(.didReward)
        delegate?.didReward(self, details: [:]) ?? log(.delegateUnavailable)
    }
}
