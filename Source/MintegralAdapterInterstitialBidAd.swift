// Copyright 2022-2024 Chartboost, Inc.
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file.

import ChartboostMediationSDK
import Foundation
import MTGSDK
import MTGSDKNewInterstitial

/// The Chartboost Mediation Mintegral adapter interstitial bid ad.
final class MintegralAdapterInterstitialBidAd: MintegralAdapterAd, PartnerAd {
    
    /// The partner ad view to display inline. E.g. a banner view.
    /// Should be nil for full-screen ads.
    var inlineView: UIView? { nil }

    /// The loaded partner ad banner size.
    /// Should be `nil` for full-screen ads.
    var bannerSize: PartnerBannerSize? { nil }

    /// The Mintegral SDK bid manager to load and show ads.
    private var bidManager: MTGNewInterstitialBidAdManager?
    
    /// Loads an ad.
    /// - parameter viewController: The view controller on which the ad will be presented on. Needed on load for some banners.
    /// - parameter completion: Closure to be performed once the ad has been loaded.
    func load(with viewController: UIViewController?, completion: @escaping (Result<PartnerDetails, Error>) -> Void) {
        log(.loadStarted)
        
        /// Fail early if the bid token is unavailable
        guard let adm = request.adm else {
            let error = error(.loadFailureInvalidAdMarkup)
            log(.loadFailed(error))
            return completion(.failure(error))
        }
        
        loadCompletion = completion
        
        let bidManager = MTGNewInterstitialBidAdManager(placementId: request.partnerPlacement, unitId: unitID, delegate: self)
        self.bidManager = bidManager
        bidManager.loadAd(withBidToken: adm)
    }
    
    /// Shows a loaded ad.
    /// Chartboost Mediation SDK will always call this method from the main thread.
    /// - parameter viewController: The view controller on which the ad will be presented on.
    /// - parameter completion: Closure to be performed once the ad has been shown.
    func show(with viewController: UIViewController, completion: @escaping (Result<PartnerDetails, Error>) -> Void) {
        log(.showStarted)
        
        // Fail early if no bid manager available which means ad was not loaded
        guard let bidManager = bidManager else {
            let error = error(.showFailureAdNotReady)
            log(.showFailed(error))
            completion(.failure(error))
            return
        }
        
        showCompletion = completion
        
        bidManager.show(from: viewController)
    }
}

extension MintegralAdapterInterstitialBidAd: MTGNewInterstitialBidAdDelegate {
    
    func newInterstitialBidAdResourceLoadSuccess(_ adManager: MTGNewInterstitialBidAdManager) {
        log(.loadSucceeded)
        loadCompletion?(.success([:])) ?? log(.loadResultIgnored)
        loadCompletion = nil
    }

    func newInterstitialBidAdLoadFail(_ error: Error, adManager: MTGNewInterstitialBidAdManager) {
        log(.loadFailed(error))
        loadCompletion?(.failure(error)) ?? log(.loadResultIgnored)
        loadCompletion = nil
    }

    func newInterstitialBidAdShowSuccess(_ adManager: MTGNewInterstitialBidAdManager) {
        log(.showSucceeded)
        showCompletion?(.success([:])) ?? log(.showResultIgnored)
        showCompletion = nil
    }

    func newInterstitialBidAdShowFail(_ error: Error, adManager: MTGNewInterstitialBidAdManager) {
        log(.showFailed(error))
        showCompletion?(.failure(error)) ?? log(.showResultIgnored)
        showCompletion = nil
    }

    func newInterstitialBidAdClicked(_ adManager: MTGNewInterstitialBidAdManager) {
        log(.didClick(error: nil))
        delegate?.didClick(self, details: [:]) ?? log(.delegateUnavailable)
    }

    func newInterstitialBidAdDidClosed(_ adManager: MTGNewInterstitialBidAdManager) {
        log(.didDismiss(error: nil))
        delegate?.didDismiss(self, details: [:], error: nil) ?? log(.delegateUnavailable)
    }
}
