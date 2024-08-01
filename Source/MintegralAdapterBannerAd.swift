// Copyright 2022-2024 Chartboost, Inc.
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file.

import ChartboostMediationSDK
import Foundation
import MTGSDK
import MTGSDKBanner

/// The Chartboost Mediation Mintegral adapter banner ad.
final class MintegralAdapterBannerAd: MintegralAdapterAd, PartnerBannerAd {
    /// The partner banner ad view to display.
    var view: UIView?

    /// The loaded partner ad banner size.
    var size: PartnerBannerSize?

    /// Loads an ad.
    /// - parameter viewController: The view controller on which the ad will be presented on. Needed on load for some banners.
    /// - parameter completion: Closure to be performed once the ad has been loaded.
    func load(with viewController: UIViewController?, completion: @escaping (Error?) -> Void) {
        log(.loadStarted)

        // Fail if we cannot fit a fixed size banner in the requested size.
        guard let requestedSize = request.bannerSize,
              let loadedSize = BannerSize.largestStandardFixedSizeThatFits(in: requestedSize)?.size else {
            let error = error(.loadFailureInvalidBannerSize)
            log(.loadFailed(error))
            completion(error)
            return
        }

        size = PartnerBannerSize(size: loadedSize, type: .fixed)
        loadCompletion = completion

        let banner = makeMintegralBanner(size: loadedSize)
        view = banner

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
}

extension MintegralAdapterBannerAd: MTGBannerAdViewDelegate {
    func adViewLoadSuccess(_ adView: MTGBannerAdView?) {
        log(.loadSucceeded)
        loadCompletion?(nil) ?? log(.loadResultIgnored)
        loadCompletion = nil
    }

    func adViewLoadFailedWithError(_ partnerError: Error?, adView: MTGBannerAdView?) {
        let error = partnerError ?? self.error(.loadFailureUnknown)
        log(.loadFailed(error))
        loadCompletion?(error) ?? log(.loadResultIgnored)
        loadCompletion = nil
    }

    func adViewWillLogImpression(_ adView: MTGBannerAdView?) {
        log(.didTrackImpression)
        delegate?.didTrackImpression(self) ?? log(.delegateUnavailable)
    }

    func adViewDidClicked(_ adView: MTGBannerAdView?) {
        log(.didClick(error: nil))
        delegate?.didClick(self) ?? log(.delegateUnavailable)
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
