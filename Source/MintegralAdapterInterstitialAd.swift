// Copyright 2022-2024 Chartboost, Inc.
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file.

import ChartboostMediationSDK
import Foundation
import MTGSDK
import MTGSDKNewInterstitial

/// The Chartboost Mediation Mintegral adapter interstitial ad.
final class MintegralAdapterInterstitialAd: MintegralAdapterAd, PartnerFullscreenAd {

    /// The Mintegral SDK ad manager to load and show ads.
    private var adManager: MTGNewInterstitialAdManager?
    
    /// Loads an ad.
    /// - parameter viewController: The view controller on which the ad will be presented on. Needed on load for some banners.
    /// - parameter completion: Closure to be performed once the ad has been loaded.
    func load(with viewController: UIViewController?, completion: @escaping (Result<PartnerDetails, Error>) -> Void) {
        log(.loadStarted)
        
        loadCompletion = completion
        
        let adManager = MTGNewInterstitialAdManager(placementId: request.partnerPlacement, unitId: unitID, delegate: self)
        adManager.playVideoMute = MintegralAdapterConfiguration.isMuted
        self.adManager = adManager
        adManager.loadAd()
    }
    
    /// Shows a loaded ad.
    /// Chartboost Mediation SDK will always call this method from the main thread.
    /// - parameter viewController: The view controller on which the ad will be presented on.
    /// - parameter completion: Closure to be performed once the ad has been shown.
    func show(with viewController: UIViewController, completion: @escaping (Result<PartnerDetails, Error>) -> Void) {
        log(.showStarted)
        
        // Fail early if no bid manager available which means ad was not loaded
        guard let adManager = adManager else {
            let error = error(.showFailureAdNotReady)
            log(.showFailed(error))
            completion(.failure(error))
            return
        }

        showCompletion = completion
        
        adManager.show(from: viewController)
    }
}

extension MintegralAdapterInterstitialAd: MTGNewInterstitialAdDelegate {
    
    func newInterstitialAdResourceLoadSuccess(_ adManager: MTGNewInterstitialAdManager) {
        log(.loadSucceeded)
        loadCompletion?(.success([:])) ?? log(.loadResultIgnored)
        loadCompletion = nil
    }

    func newInterstitialAdLoadFail(_ error: Error, adManager: MTGNewInterstitialAdManager) {
        log(.loadFailed(error))
        loadCompletion?(.failure(error)) ?? log(.loadResultIgnored)
        loadCompletion = nil
    }

    func newInterstitialAdShowSuccess(_ adManager: MTGNewInterstitialAdManager) {
        log(.showSucceeded)
        showCompletion?(.success([:])) ?? log(.showResultIgnored)
        showCompletion = nil
    }

    func newInterstitialAdShowFail(_ error: Error, adManager: MTGNewInterstitialAdManager) {
        log(.showFailed(error))
        showCompletion?(.failure(error)) ?? log(.showResultIgnored)
        showCompletion = nil
    }

    func newInterstitialAdClicked(_ adManager: MTGNewInterstitialAdManager) {
        log(.didClick(error: nil))
        delegate?.didClick(self, details: [:]) ?? log(.delegateUnavailable)
    }

    func newInterstitialAdDidClosed(_ adManager: MTGNewInterstitialAdManager) {
        log(.didDismiss(error: nil))
        delegate?.didDismiss(self, details: [:], error: nil) ?? log(.delegateUnavailable)
    }
}
