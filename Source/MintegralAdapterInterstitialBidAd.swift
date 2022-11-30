//
//  MintegralAdapterInterstitialBidAd.swift
//  ChartboostHeliumAdapterMintegral
//

import Foundation
import HeliumSdk
import MTGSDK
import MTGSDKNewInterstitial

/// The Helium Mintegral adapter interstitial bid ad.
final class MintegralAdapterInterstitialBidAd: MintegralAdapterAd, PartnerAd {
    
    /// The partner ad view to display inline. E.g. a banner view.
    /// Should be nil for full-screen ads.
    var inlineView: UIView? { nil }
    
    /// The Mintegral SDK bid manager to load and show ads.
    private var bidManager: MTGNewInterstitialBidAdManager?
    
    /// Loads an ad.
    /// - parameter viewController: The view controller on which the ad will be presented on. Needed on load for some banners.
    /// - parameter completion: Closure to be performed once the ad has been loaded.
    func load(with viewController: UIViewController?, completion: @escaping (Result<PartnerEventDetails, Error>) -> Void) {
        log(.loadStarted)
        
        /// Fail early if the bid token is unavailable
        guard let adm = request.adm else {
            let error = error(.noBidPayload)
            log(.loadFailed(error))
            return completion(.failure(error))
        }
        
        loadCompletion = completion
        
        let bidManager = MTGNewInterstitialBidAdManager(placementId: request.partnerPlacement, unitId: unitID, delegate: self)
        self.bidManager = bidManager
        bidManager.loadAd(withBidToken: adm)
    }
    
    /// Shows a loaded ad.
    /// It will never get called for banner ads. You may leave the implementation blank for that ad format.
    /// - parameter viewController: The view controller on which the ad will be presented on.
    /// - parameter completion: Closure to be performed once the ad has been shown.
    func show(with viewController: UIViewController, completion: @escaping (Result<PartnerEventDetails, Error>) -> Void) {
        log(.showStarted)
        
        // Fail early if no bid manager available which means ad was not loaded
        guard let bidManager = bidManager else {
            let error = error(.noAdReadyToShow)
            log(.showFailed(error))
            completion(.failure(error))
            return
        }
        
        showCompletion = completion
        DispatchQueue.main.async {
            bidManager.show(from: viewController)
        }
    }
}

extension MintegralAdapterInterstitialBidAd: MTGNewInterstitialBidAdDelegate {
    
    func newInterstitialBidAdResourceLoadSuccess(_ adManager: MTGNewInterstitialBidAdManager) {
        log(.loadSucceeded)
        loadCompletion?(.success([:])) ?? log(.loadResultIgnored)
        loadCompletion = nil
    }

    func newInterstitialBidAdLoadFail(_ partnerError: Error, adManager: MTGNewInterstitialBidAdManager) {
        let error = error(.loadFailure, error: partnerError)
        log(.loadFailed(error))
        loadCompletion?(.failure(error)) ?? log(.loadResultIgnored)
        loadCompletion = nil
    }

    func newInterstitialBidAdShowSuccess(_ adManager: MTGNewInterstitialBidAdManager) {
        log(.showSucceeded)
        showCompletion?(.success([:])) ?? log(.showResultIgnored)
        showCompletion = nil
    }

    func newInterstitialBidAdShowFail(_ partnerError: Error, adManager: MTGNewInterstitialBidAdManager) {
        let error = error(.showFailure, error: partnerError)
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
