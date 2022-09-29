//
//  MintegralAdAdapter+Banners.swift
//  ChartboostHeliumAdapterMintegral
//

import Foundation
import HeliumSdk
import MTGSDK
import MTGSDKBanner

final class MintegralBannerAdAdapter: MintegralAdAdapter {

    /// Flag to indicate if the banner has loaded, to help report show success/failure.
    private var isLoaded: Bool = false

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

        let size = request.size ?? IABStandardAdSize

        if let adm = request.adm {
            guard let token = bidID(from: adm) else {
                loadCompletion = nil
                let error = error(.loadFailure(request), description: "No bid ID")
                return completion(.failure(error))
            }
            let ad = makeBannerAdView(size: size, placementID: request.partnerPlacement, unitID: unitID)
            partnerAd = PartnerAd(ad: ad, details: [:], request: request)
            ad.loadBannerAd(withBidToken: token)
        }
        else {
            let ad = makeBannerAdView(size: size, placementID: request.partnerPlacement, unitID: unitID)
            partnerAd = PartnerAd(ad: ad, details: [:], request: request)
            ad.loadBannerAd()
        }
    }

    func makeBannerAdView(size: CGSize, placementID: String, unitID: String) -> MTGBannerAdView {
        let ad = MTGBannerAdView(bannerAdViewWithAdSize: size, placementId: placementID, unitId: unitID, rootViewController: nil)
        ad.autoRefreshTime = 0 // disables auto-refresh
        ad.showCloseButton = MTGBool.no
        ad.delegate = self
        return ad
    }

    /// Attempt to show the currently loaded ad.
    /// - Parameters:
    ///   - viewController: The ViewController for ad presentation purposes.
    ///   - completion: The completion handler to notify Helium of ad show completion result.
    override func show(with viewController: UIViewController, completion: @escaping (Result<PartnerAd, Error>) -> Void) {
        if isLoaded {
            completion(.success(partnerAd))
        }
        else {
            let error = error(.showFailure(partnerAd), description: "Not loaded.")
            completion(.failure(error))
        }
    }
}

extension MintegralBannerAdAdapter: MTGBannerAdViewDelegate {
    func adViewLoadSuccess(_ adView: MTGBannerAdView!) {
        isLoaded = true
        loadCompletion?(.success(partnerAd)) ?? log(.loadResultIgnored)
        loadCompletion = nil
    }

    func adViewLoadFailedWithError(_ error: Error!, adView: MTGBannerAdView!) {
        let error = self.error(.loadFailure(request), error: error)
        loadCompletion?(.failure(error)) ?? log(.loadResultIgnored)
        loadCompletion = nil
    }

    func adViewWillLogImpression(_ adView: MTGBannerAdView!) {
        log(.didTrackImpression(partnerAd))
        partnerAdDelegate?.didTrackImpression(partnerAd) ?? log(.delegateUnavailable)
    }

    func adViewDidClicked(_ adView: MTGBannerAdView!) {
        log(.didClick(partnerAd, error: nil))
        partnerAdDelegate?.didClick(partnerAd) ?? log(.delegateUnavailable)
    }

    func adViewWillLeaveApplication(_ adView: MTGBannerAdView!) {
        // NO-OP
    }

    func adViewWillOpenFullScreen(_ adView: MTGBannerAdView!) {
        // NO-OP
    }

    func adViewCloseFullScreen(_ adView: MTGBannerAdView!) {
        // NO-OP
    }

    func adViewClosed(_ adView: MTGBannerAdView!) {
        // NO-OP
    }
}
