//
//  MintegralAdAdapter+Rewarded.swift
//  ChartboostHeliumAdapterMintegral
//

import Foundation
import HeliumSdk
import MTGSDK
import MTGSDKReward

final class MintegralRewardedAdAdapter: MintegralAdAdapter {
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
            MTGBidRewardAdManager.sharedInstance().loadVideo(withBidToken: token, placementId: request.partnerPlacement, unitId: unitID, delegate: self)
            partnerAd = PartnerAd(ad: MTGBidRewardAdManager.self, details: [:], request: request)
        }
        else {
            MTGRewardAdManager.sharedInstance().loadVideo(withPlacementId: request.partnerPlacement, unitId: unitID, delegate: self)
            partnerAd = PartnerAd(ad: MTGRewardAdManager.self, details: [:], request: request)
        }
    }

    /// Attempt to show the currently loaded ad.
    /// - Parameters:
    ///   - viewController: The ViewController for ad presentation purposes.
    ///   - completion: The completion handler to notify Helium of ad show completion result.
    override func show(with viewController: UIViewController, completion: @escaping (Result<PartnerAd, Error>) -> Void) {
        guard let unitID = self.unitID else {
            let error = error(.showFailure(partnerAd), description: "No unit ID")
            return completion(.failure(error))
        }

        guard let adType = partnerAd.ad as? Any.Type else {
            let error = error(.showFailure(partnerAd), description: "Ad instance is invalid.")
            return completion(.failure(error))
        }

        showCompletion = completion

        if adType == MTGBidRewardAdManager.self {
            MTGBidRewardAdManager.sharedInstance().showVideo(withPlacementId: request.partnerPlacement, unitId: unitID, userId: nil, delegate: self, viewController: viewController)
        }
        else if adType == MTGRewardAdManager.self {
            MTGRewardAdManager.sharedInstance().showVideo(withPlacementId: request.partnerPlacement, unitId: unitID, userId: nil, delegate: self, viewController: viewController)
        }
        else {
            showCompletion = nil
            let error = error(.showFailure(partnerAd), description: "Ad instance is invalid.")
            return completion(.failure(error))
        }
    }
}

extension MintegralRewardedAdAdapter: MTGRewardAdLoadDelegate {
    func onVideoAdLoadSuccess(_ placementId: String?, unitId: String?) {
        loadCompletion?(.success(partnerAd)) ?? log(.loadResultIgnored)
        loadCompletion = nil
    }

    func onVideoAdLoadFailed(_ placementId: String?, unitId: String?, error: Error) {
        let error = self.error(.loadFailure(request), error: error)
        loadCompletion?(.failure(error)) ?? log(.loadResultIgnored)
        loadCompletion = nil
    }
}

extension MintegralRewardedAdAdapter: MTGRewardAdShowDelegate {
    func onVideoAdShowSuccess(_ placementId: String?, unitId: String?) {
        showCompletion?(.success(partnerAd)) ?? log(.showResultIgnored)
        showCompletion = nil
    }

    func onVideoAdShowFailed(_ placementId: String?, unitId: String?, withError error: Error) {
        let error = self.error(.showFailure(partnerAd), error: error)
        showCompletion?(.failure(error)) ?? log(.loadResultIgnored)
        showCompletion = nil
    }

    func onVideoAdClicked(_ placementId: String?, unitId: String?) {
        log(.didClick(partnerAd, error: nil))
        partnerAdDelegate?.didClick(partnerAd) ?? log(.delegateUnavailable)
    }

    func onVideoAdDidClosed(_ placementId: String?, unitId: String?) {
        log(.didDismiss(partnerAd, error: nil))
        partnerAdDelegate?.didDismiss(partnerAd, error: nil) ?? log(.delegateUnavailable)
    }

    func onVideoAdDismissed(_ placementId: String?, unitId: String?, withConverted converted: Bool, withRewardInfo rewardInfo: MTGRewardAdInfo?) {
        let reward = Reward(amount: 1, label: nil)
        log(.didReward(partnerAd, reward: reward))
        partnerAdDelegate?.didReward(partnerAd, reward: reward) ?? log(.delegateUnavailable)
    }
}
