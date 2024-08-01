// Copyright 2022-2024 Chartboost, Inc.
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file.

import ChartboostMediationSDK
import Foundation
import MTGSDK
import MTGSDKNewInterstitial

/// The Chartboost Mediation Mintegral adapter interstitial bid ad.
final class MintegralAdapterInterstitialBidAd: MintegralAdapterAd, PartnerFullscreenAd {
    /// The Mintegral SDK bid manager to load and show ads.
    private var bidManager: MTGNewInterstitialBidAdManager?

    /// Loads an ad.
    /// - parameter viewController: The view controller on which the ad will be presented on. Needed on load for some banners.
    /// - parameter completion: Closure to be performed once the ad has been loaded.
    func load(with viewController: UIViewController?, completion: @escaping (Error?) -> Void) {
        log(.loadStarted)

        // Fail early if the bid token is unavailable
        guard let adm = request.adm else {
            let error = error(.loadFailureInvalidAdMarkup)
            log(.loadFailed(error))
            completion(error)
            return
        }

        loadCompletion = completion

        let bidManager = MTGNewInterstitialBidAdManager(placementId: request.partnerPlacement, unitId: unitID, delegate: self)
        bidManager.playVideoMute = MintegralAdapterConfiguration.isMuted
        self.bidManager = bidManager
        bidManager.loadAd(withBidToken: adm)
    }

    /// Shows a loaded ad.
    /// Chartboost Mediation SDK will always call this method from the main thread.
    /// - parameter viewController: The view controller on which the ad will be presented on.
    /// - parameter completion: Closure to be performed once the ad has been shown.
    func show(with viewController: UIViewController, completion: @escaping (Error?) -> Void) {
        log(.showStarted)

        // Fail early if no bid manager available which means ad was not loaded
        guard let bidManager else {
            let error = error(.showFailureAdNotReady)
            log(.showFailed(error))
            completion(error)
            return
        }

        showCompletion = completion

        bidManager.show(from: viewController)
    }
}

extension MintegralAdapterInterstitialBidAd: MTGNewInterstitialBidAdDelegate {
    func newInterstitialBidAdResourceLoadSuccess(_ adManager: MTGNewInterstitialBidAdManager) {
        log(.loadSucceeded)
        loadCompletion?(nil) ?? log(.loadResultIgnored)
        loadCompletion = nil
    }

    func newInterstitialBidAdLoadFail(_ error: Error, adManager: MTGNewInterstitialBidAdManager) {
        log(.loadFailed(error))
        loadCompletion?(error) ?? log(.loadResultIgnored)
        loadCompletion = nil
    }

    func newInterstitialBidAdShowSuccess(_ adManager: MTGNewInterstitialBidAdManager) {
        log(.showSucceeded)
        showCompletion?(nil) ?? log(.showResultIgnored)
        showCompletion = nil
    }

    func newInterstitialBidAdShowFail(_ error: Error, adManager: MTGNewInterstitialBidAdManager) {
        log(.showFailed(error))
        showCompletion?(error) ?? log(.showResultIgnored)
        showCompletion = nil
    }

    func newInterstitialBidAdClicked(_ adManager: MTGNewInterstitialBidAdManager) {
        log(.didClick(error: nil))
        delegate?.didClick(self) ?? log(.delegateUnavailable)
    }

    func newInterstitialBidAdDidClosed(_ adManager: MTGNewInterstitialBidAdManager) {
        log(.didDismiss(error: nil))
        delegate?.didDismiss(self, error: nil) ?? log(.delegateUnavailable)
    }
}
