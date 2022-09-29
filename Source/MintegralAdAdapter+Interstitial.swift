//
//  MintegralAdAdapter+Interstitial.swift
//  ChartboostHeliumAdapterMintegral
//

import Foundation
import HeliumSdk
import MTGSDK
import MTGSDKNewInterstitial

final class MintegralInterstitialAdAdapter: MintegralAdAdapter {

    /// Attempt to load an ad.
    /// - Parameters:
    ///   - viewController: The ViewController for ad presentation purposes.
    ///   - completion: The completion handler to notify Helium of ad load completion result.
    override func load(with viewController: UIViewController?, completion: @escaping (Result<PartnerAd, Error>) -> Void) {
        guard let unitID = self.unitID else {
            let error = error(.loadFailure(request), description: "No unit ID")
            return completion(.failure(error))
        }

        loadCompletion = completion

        if let adm = request.adm {
            guard let token = bidID(from: adm) else {
                loadCompletion = nil
                let error = error(.loadFailure(request), description: "No bid ID")
                return completion(.failure(error))
            }
            let bidManager = MTGNewInterstitialBidAdManager(placementId: request.partnerPlacement, unitId: unitID, delegate: self)
            partnerAd = PartnerAd(ad: bidManager, details: [:], request: request)
            bidManager.loadAd(withBidToken: token)
        }
        else {
            let adManager = MTGNewInterstitialAdManager(placementId: request.partnerPlacement, unitId: unitID, delegate: self)
            partnerAd = PartnerAd(ad: adManager, details: [:], request: request)
            adManager.loadAd()
        }
    }

    /// Attempt to show the currently loaded ad.
    /// - Parameters:
    ///   - viewController: The ViewController for ad presentation purposes.
    ///   - completion: The completion handler to notify Helium of ad show completion result.
    override func show(with viewController: UIViewController, completion: @escaping (Result<PartnerAd, Error>) -> Void) {
        showCompletion = completion

        if let bidManager = partnerAd.ad as? MTGNewInterstitialBidAdManager {
            bidManager.show(from: viewController)
        }
        else if let adManager = partnerAd.ad as? MTGNewInterstitialAdManager {
            adManager.show(from: viewController)
        }
        else {
            showCompletion = nil
            let error = error(.showFailure(partnerAd), description: "Ad instance is nil/not a MTGNewInterstitialBidAdManager or MTGNewInterstitialAdManager.")
            return completion(.failure(error))
        }
    }
}

extension MintegralInterstitialAdAdapter: MTGNewInterstitialAdDelegate {
    func newInterstitialAdResourceLoadSuccess(_ adManager: MTGNewInterstitialAdManager) {
        loadCompletion?(.success(partnerAd)) ?? log(.loadResultIgnored)
        loadCompletion = nil
    }

    func newInterstitialAdLoadFail(_ error: Error, adManager: MTGNewInterstitialAdManager) {
        let error = self.error(.loadFailure(request), error: error)
        loadCompletion?(.failure(error)) ?? log(.loadResultIgnored)
        loadCompletion = nil
    }

    func newInterstitialAdShowSuccess(_ adManager: MTGNewInterstitialAdManager) {
        showCompletion?(.success(partnerAd)) ?? log(.showResultIgnored)
        showCompletion = nil
    }

    func newInterstitialAdShowFail(_ error: Error, adManager: MTGNewInterstitialAdManager) {
        let error = self.error(.showFailure(partnerAd), error: error)
        showCompletion?(.failure(error)) ?? log(.loadResultIgnored)
        showCompletion = nil
    }

    func newInterstitialAdClicked(_ adManager: MTGNewInterstitialAdManager) {
        log(.didClick(partnerAd, error: nil))
        partnerAdDelegate?.didClick(partnerAd) ?? log(.delegateUnavailable)
    }

    func newInterstitialAdDidClosed(_ adManager: MTGNewInterstitialAdManager) {
        log(.didDismiss(partnerAd, error: nil))
        partnerAdDelegate?.didDismiss(partnerAd, error: nil) ?? log(.delegateUnavailable)
    }
}

extension MintegralInterstitialAdAdapter: MTGNewInterstitialBidAdDelegate {
    func newInterstitialBidAdResourceLoadSuccess(_ adManager: MTGNewInterstitialBidAdManager) {
        loadCompletion?(.success(partnerAd)) ?? log(.loadResultIgnored)
        loadCompletion = nil
    }

    func newInterstitialBidAdLoadFail(_ error: Error, adManager: MTGNewInterstitialBidAdManager) {
        let error = self.error(.loadFailure(request), error: error)
        loadCompletion?(.failure(error)) ?? log(.loadResultIgnored)
        loadCompletion = nil
    }

    func newInterstitialBidAdShowSuccess(_ adManager: MTGNewInterstitialBidAdManager) {
        showCompletion?(.success(partnerAd)) ?? log(.showResultIgnored)
        showCompletion = nil
    }

    func newInterstitialBidAdShowFail(_ error: Error, adManager: MTGNewInterstitialBidAdManager) {
        let error = self.error(.showFailure(partnerAd), error: error)
        showCompletion?(.failure(error)) ?? log(.loadResultIgnored)
        showCompletion = nil
    }

    func newInterstitialBidAdClicked(_ adManager: MTGNewInterstitialBidAdManager) {
        log(.didClick(partnerAd, error: nil))
        partnerAdDelegate?.didClick(partnerAd) ?? log(.delegateUnavailable)
    }

    func newInterstitialBidAdDidClosed(_ adManager: MTGNewInterstitialBidAdManager) {
        log(.didDismiss(partnerAd, error: nil))
        partnerAdDelegate?.didDismiss(partnerAd, error: nil) ?? log(.delegateUnavailable)
    }
}
