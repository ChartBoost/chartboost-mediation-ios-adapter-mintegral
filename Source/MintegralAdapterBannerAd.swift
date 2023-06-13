// Copyright 2022-2023 Chartboost, Inc.
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file.

import ChartboostMediationSDK
import Foundation
import MTGSDK
import MTGSDKBanner

/// The Chartboost Mediation Mintegral adapter banner ad.
final class MintegralAdapterBannerAd: MintegralAdapterAd, PartnerAd {
    
    /// The partner ad view to display inline. E.g. a banner view.
    /// Should be nil for full-screen ads.
    var inlineView: UIView?
    
    /// Loads an ad.
    /// - parameter viewController: The view controller on which the ad will be presented on. Needed on load for some banners.
    /// - parameter completion: Closure to be performed once the ad has been loaded.
    func load(with viewController: UIViewController?, completion: @escaping (Result<PartnerEventDetails, Error>) -> Void) {
        log(.loadStarted)
        
        loadCompletion = completion
        
        let banner = makeMintegralBanner()
        inlineView = banner
        
        if let adm = request.adm {
            banner.loadBannerAd(withBidToken: adm)
        } else {
            banner.loadBannerAd()
        }
    }
    
    private func makeMintegralBanner() -> MTGBannerAdView {
        let banner = MTGBannerAdView(
            bannerAdViewWithAdSize: request.size ?? IABStandardAdSize,
            placementId: request.partnerPlacement,
            unitId: unitID,
            rootViewController: nil
        )
        banner.autoRefreshTime = 0 // disables auto-refresh
        banner.showCloseButton = .no
        banner.delegate = self
        return banner
    }
    
    /// Shows a loaded ad.
    /// It will never get called for banner ads. You may leave the implementation blank for that ad format.
    /// - parameter viewController: The view controller on which the ad will be presented on.
    /// - parameter completion: Closure to be performed once the ad has been shown.
    func show(with viewController: UIViewController, completion: @escaping (Result<PartnerEventDetails, Error>) -> Void) {
        // no-op
    }
}

extension MintegralAdapterBannerAd: MTGBannerAdViewDelegate {
    
    func adViewLoadSuccess(_ adView: MTGBannerAdView?) {
        log(.loadSucceeded)
        loadCompletion?(.success([:])) ?? log(.loadResultIgnored)
        loadCompletion = nil
    }

    func adViewLoadFailedWithError(_ partnerError: Error?, adView: MTGBannerAdView?) {
        let error = partnerError ?? self.error(.loadFailureUnknown)
        log(.loadFailed(error))
        loadCompletion?(.failure(error)) ?? log(.loadResultIgnored)
        loadCompletion = nil
    }

    func adViewWillLogImpression(_ adView: MTGBannerAdView?) {
        log(.didTrackImpression)
        delegate?.didTrackImpression(self, details: [:]) ?? log(.delegateUnavailable)
    }

    func adViewDidClicked(_ adView: MTGBannerAdView?) {
        log(.didClick(error: nil))
        delegate?.didClick(self, details: [:]) ?? log(.delegateUnavailable)
    }
    
    func adViewWillLeaveApplication(_ adView: MTGBannerAdView?) {
        log(.delegateCallIgnored)
    }

    func adViewWillOpenFullScreen(_ adView: MTGBannerAdView?) {
        log(.delegateCallIgnored)
    }

    func adViewCloseFullScreen(_ adView: MTGBannerAdView?) {
        log(.delegateCallIgnored)
    }

    func adViewClosed(_ adView: MTGBannerAdView?) {
        log(.delegateCallIgnored)
    }
}
