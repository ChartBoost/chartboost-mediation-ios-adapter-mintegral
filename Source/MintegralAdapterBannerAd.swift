// Copyright 2022-2024 Chartboost, Inc.
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
    
    /// The loaded partner ad banner size.
    /// Should be `nil` for full-screen ads.
    var bannerSize: PartnerBannerSize?

    /// Loads an ad.
    /// - parameter viewController: The view controller on which the ad will be presented on. Needed on load for some banners.
    /// - parameter completion: Closure to be performed once the ad has been loaded.
    func load(with viewController: UIViewController?, completion: @escaping (Result<PartnerDetails, Error>) -> Void) {
        log(.loadStarted)

        // Fail if we cannot fit a fixed size banner in the requested size.
        guard let size = fixedBannerSize(for: request.size ?? IABStandardAdSize) else {
            let error = error(.loadFailureInvalidBannerSize)
            log(.loadFailed(error))
            return completion(.failure(error))
        }

        bannerSize = PartnerBannerSize(size: size, type: .fixed)
        loadCompletion = completion
        
        let banner = makeMintegralBanner(size: size)
        inlineView = banner
        
        if let adm = request.adm {
            banner.loadBannerAd(withBidToken: adm)
        } else {
            banner.loadBannerAd()
        }
    }
    
    private func makeMintegralBanner(size: CGSize) -> MTGBannerAdView {
        let banner = MTGBannerAdView(
            bannerAdViewWithAdSize: size,
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
    func show(with viewController: UIViewController, completion: @escaping (Result<PartnerDetails, Error>) -> Void) {
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

// MARK: - Helpers
extension MintegralAdapterBannerAd {
    private func fixedBannerSize(for requestedSize: CGSize) -> CGSize? {
        let sizes = [IABLeaderboardAdSize, IABMediumAdSize, IABStandardAdSize]
        // Find the largest size that can fit in the requested size.
        for size in sizes {
            // If height is 0, the pub has requested an ad of any height, so only the width matters.
            if requestedSize.width >= size.width &&
                (size.height == 0 || requestedSize.height >= size.height) {
                return size
            }
        }
        // The requested size cannot fit any fixed size banners.
        return nil
    }
}
