// Copyright 2022-2024 Chartboost, Inc.
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file.

import ChartboostMediationSDK
import Foundation
import MTGSDK
import MTGSDKBidding
import UIKit

/// Chartboost Mediation Mintegral adapter.
final class MintegralAdapter: PartnerAdapter {
    /// The adapter configuration type that contains adapter and partner info.
    /// It may also be used to expose custom partner SDK options to the publisher.
    var configuration: PartnerAdapterConfiguration.Type { MintegralAdapterConfiguration.self }

    /// Ad storage managed by Chartboost Mediation SDK.
    let storage: PartnerAdapterStorage
    
    /// The designated initializer for the adapter.
    /// Chartboost Mediation SDK will use this constructor to create instances of conforming types.
    /// - parameter storage: An object that exposes storage managed by the Chartboost Mediation SDK to the adapter.
    /// It includes a list of created `PartnerAd` instances. You may ignore this parameter if you don't need it.
    init(storage: PartnerAdapterStorage) {
        self.storage = storage
    }
    
    /// Does any setup needed before beginning to load ads.
    /// - parameter configuration: Configuration data for the adapter to set up.
    /// - parameter completion: Closure to be performed by the adapter when it's done setting up. It should include an error indicating the cause for failure or `nil` if the operation finished successfully.
    func setUp(with configuration: PartnerConfiguration, completion: @escaping (Result<PartnerDetails, Error>) -> Void) {
        log(.setUpStarted)
        
        // Get credentials, fail early if they are unavailable
        guard let appID = configuration.appID, !appID.isEmpty else {
            let error = error(.initializationFailureInvalidCredentials, description: "Missing \(String.appIDKey)")
            log(.setUpFailed(error))
            return completion(.failure(error))
        }
        guard let apiKey = configuration.apiKey, !apiKey.isEmpty else {
            let error = error(.initializationFailureInvalidCredentials, description: "Missing \(String.apiKey)")
            log(.setUpFailed(error))
            return completion(.failure(error))
        }

        // Apply initial consents
        setConsents(configuration.consents, modifiedKeys: Set(configuration.consents.keys))
        setIsUserUnderage(configuration.isUserUnderage)

        // Set up Mintegral SDK
        // It's necessary to call `setAppID` on the main thread because it uses `UIApplication.canOpenURL(_:)` directly on the current thread.
        DispatchQueue.main.async { [self] in
            MTGSDK.sharedInstance().setAppID(appID, apiKey: apiKey)
            
            // Succeed always
            log(.setUpSucceded)
            completion(.success([:]))
        }
    }
    
    /// Fetches bidding tokens needed for the partner to participate in an auction.
    /// - parameter request: Information about the ad load request.
    /// - parameter completion: Closure to be performed with the fetched info.
    func fetchBidderInformation(request: PartnerAdPreBidRequest, completion: @escaping (Result<[String : String], Error>) -> Void) {
        log(.fetchBidderInfoStarted(request))
        let info = MTGBiddingSDK.buyerUID()
        log(.fetchBidderInfoSucceeded(request))
        completion(.success(info.map { ["buyeruid": $0] } ?? [:]))
    }
    
    /// Indicates that the user consent has changed.
    /// - parameter consents: The new consents value, including both modified and unmodified consents.
    /// - parameter modifiedKeys: A set containing all the keys that changed.
    func setConsents(_ consents: [ConsentKey: ConsentValue], modifiedKeys: Set<ConsentKey>) {
        // See http://cdn-adn.rayjump.com/cdn-adn/v2/markdown_v2/index.html?file=sdk-m_sdk-ios&lang=en#settingsforuserpersonaldataprotection
        // GDPR
        if modifiedKeys.contains(configuration.partnerID) || modifiedKeys.contains(ConsentKeys.gdprConsentGiven) {
            let consent = consents[configuration.partnerID] ?? consents[ConsentKeys.gdprConsentGiven]
            switch consent {
            case ConsentValues.granted:
                MTGSDK.sharedInstance().consentStatus = true
                log(.privacyUpdated(setting: "consentStatus", value: true))
            case ConsentValues.denied:
                MTGSDK.sharedInstance().consentStatus = false
                log(.privacyUpdated(setting: "consentStatus", value: false))
            default:
                break   // do nothing
            }
        }

        // CCPA
        if modifiedKeys.contains(ConsentKeys.ccpaOptIn) {
            // we don't set doNotTrackStatus to false to avoid overwritting a value possibly set by setIsUserUnderage()
            if consents[ConsentKeys.ccpaOptIn] == ConsentValues.denied {
                MTGSDK.sharedInstance().doNotTrackStatus = true
                log(.privacyUpdated(setting: "doNotTrackStatus", value: true))
            }
        }
    }

    /// Indicates that the user is underage signal has changed.
    /// - parameter isUserUnderage: `true` if the user is underage as determined by the publisher, `false` otherwise.
    func setIsUserUnderage(_ isUserUnderage: Bool) {
        // See http://cdn-adn.rayjump.com/cdn-adn/v2/markdown_v2/index.html?file=sdk-m_sdk-ios&lang=en#settingsforuserpersonaldataprotection
        guard isUserUnderage else {
            return  // we don't set doNotTrackStatus to false to avoid overwritting a value possibly set by setConsents()
        }
        // Using this method, same as CCPA, per Mintegral's instructions
        MTGSDK.sharedInstance().doNotTrackStatus = true
        log(.privacyUpdated(setting: "doNotTrackStatus", value: true))
    }

    /// Creates a new banner ad object in charge of communicating with a single partner SDK ad instance.
    /// Chartboost Mediation SDK calls this method to create a new ad for each new load request. Ad instances are never reused.
    /// Chartboost Mediation SDK takes care of storing and disposing of ad instances so you don't need to.
    /// ``PartnerAd/invalidate()`` is called on ads before disposing of them in case partners need to perform any custom logic before the
    /// object gets destroyed.
    /// If, for some reason, a new ad cannot be provided, an error should be thrown.
    /// Chartboost Mediation SDK will always call this method from the main thread.
    /// - parameter request: Information about the ad load request.
    /// - parameter delegate: The delegate that will receive ad life-cycle notifications.
    func makeBannerAd(request: PartnerAdLoadRequest, delegate: PartnerAdDelegate) throws -> PartnerBannerAd {
        // Multiple banner loads are allowed so a banner prefetch can happen during auto-refresh.
        // ChartboostMediationSDK 5.x does not support loading more than 2 banners with the same placement, and the partner may or may not support it.
        try MintegralAdapterBannerAd(adapter: self, request: request, delegate: delegate)
    }

    /// Creates a new ad object in charge of communicating with a single partner SDK ad instance.
    /// Chartboost Mediation SDK calls this method to create a new ad for each new load request. Ad instances are never reused.
    /// Chartboost Mediation SDK takes care of storing and disposing of ad instances so you don't need to.
    /// ``PartnerAd/invalidate()`` is called on ads before disposing of them in case partners need to perform any custom logic before the
    /// object gets destroyed.
    /// If, for some reason, a new ad cannot be provided, an error should be thrown.
    /// - parameter request: Information about the ad load request.
    /// - parameter delegate: The delegate that will receive ad life-cycle notifications.
    func makeFullscreenAd(request: PartnerAdLoadRequest, delegate: PartnerAdDelegate) throws -> PartnerFullscreenAd {
        // Prevent multiple loads for the same partner placement, since the partner SDK cannot handle them.
        guard !storage.ads.contains(where: { $0.request.partnerPlacement == request.partnerPlacement }) else {
            log(.skippedLoadForAlreadyLoadingPlacement(request))
            throw error(.loadFailureLoadInProgress)
        }
        
        switch request.format {
        case PartnerAdFormats.interstitial:
            if request.adm == nil {
                return try MintegralAdapterInterstitialAd(adapter: self, request: request, delegate: delegate)
            } else {
                return try MintegralAdapterInterstitialBidAd(adapter: self, request: request, delegate: delegate)
            }
        case PartnerAdFormats.rewarded:
            return try MintegralAdapterRewardedAd(adapter: self, request: request, delegate: delegate)
        default:
            throw error(.loadFailureUnsupportedAdFormat)
        }
    }
    
    /// Maps a partner load error to a Chartboost Mediation error code.
    /// Chartboost Mediation SDK calls this method when a load completion is called with a partner error.
    ///
    /// A default implementation is provided that returns `nil`.
    /// Only implement if the partner SDK provides its own list of error codes that can be mapped to Chartboost Mediation's.
    /// If some case cannot be mapped return `nil` to let Chartboost Mediation choose a default error code.
    func mapLoadError(_ error: Error) -> ChartboostMediationError.Code? {
        guard (error as NSError).domain == kMTGErrorDomain,
              let code = MTGErrorCode(rawValue: (error as NSError).code) else {
            return nil
        }
        switch code {
        case .KMTGErrorCodeEmptyUnitId:
            return .loadFailureInvalidPartnerPlacement
        case .KMTGErrorCodeEmptyBidToken:
            return .loadFailureInvalidAdMarkup
        case .kMTGErrorCodeNoAds:
            return .loadFailureNoFill
        case .kMTGErrorCodeConnectionLost:
            return .loadFailureNoConnectivity
        case .kMTGErrorCodeNoAdsAvailableToPlay:
            return .loadFailureNoFill
        case .kMTGErrorCodeDailyLimit:
            return .loadFailureRateLimited
        case .kMTGErrorCodeLoadAdsTimeOut:
            return .loadFailureTimeout
        case .kMTGErrorCodeUnknownError,
                .kMTGErrorCodeFailedToLoad,
                .kMTGErrorCodeRewardVideoFailedToLoadVideoData,
                .kMTGErrorCodeRewardVideoFailedToLoadPlayable,
                .kMTGErrorCodeRewardVideoFailedToLoadTemplateImage,
                .kMTGErrorCodeRewardVideoFailedToLoadPlayableURLFailed,
                .kMTGErrorCodeRewardVideoFailedToLoadPlayableURLReadyTimeOut,
                .kMTGErrorCodeRewardVideoFailedToLoadPlayableURLReadyNO,
                .kMTGErrorCodeRewardVideoFailedToLoadPlayableURLInvalid,
                .kMTGErrorCodeURLisEmpty,
                .kMTGErrorCodeFailedToPlay,
                .kMTGErrorCodeFailedToShow,
                .kMTGErrorCodeRewardVideoFailedToLoadMd5Invalid,
                .kMTGErrorCodeRewardVideoFailedToSettingInvalid,
                .kMTGErrorCodeFailedToShowCbp,
                .kMTGErrorCodeMaterialLoadFailed,
                .kMTGErrorCodeOfferExpired,
                .kMTGErrorCodeImageURLisEmpty,
                .kMTGErrorCodeNoSupportPopupWindow,
                .kMTGErrorCodeFailedDiskIO,
                .kMTGErrorCodeSocketIO,
                .kMTGErrorCodeAdsCountInvalid,
                .kMTGErrorCodeSocketInvalidStatus,
                .kMTGErrorCodeSocketInvalidContent:
            return .loadFailureUnknown
        @unknown default:
            return nil
        }
    }
    
    /// Maps a partner show error to a Chartboost Mediation error code.
    /// Chartboost Mediation SDK calls this method when a show completion is called with a partner error.
    ///
    /// A default implementation is provided that returns `nil`.
    /// Only implement if the partner SDK provides its own list of error codes that can be mapped to Chartboost Mediation's.
    /// If some case cannot be mapped return `nil` to let Chartboost Mediation choose a default error code.
    func mapShowError(_ error: Error) -> ChartboostMediationError.Code? {
        guard (error as NSError).domain == kMTGErrorDomain,
              let code = MTGErrorCode(rawValue: (error as NSError).code) else {
            return nil
        }
        switch code {
        case .KMTGErrorCodeEmptyUnitId:
            return .showFailureInvalidPartnerPlacement
        case .kMTGErrorCodeNoAds:
            return .showFailureNoFill
        case .kMTGErrorCodeConnectionLost:
            return .showFailureNoConnectivity
        case .kMTGErrorCodeNoAdsAvailableToPlay:
            return .showFailureAdNotReady
        case .kMTGErrorCodeLoadAdsTimeOut:
            return .showFailureTimeout
        case .kMTGErrorCodeFailedToPlay:
            return .showFailureVideoPlayerError
        case .kMTGErrorCodeRewardVideoFailedToLoadVideoData:
            return .showFailureMediaBroken
        case .kMTGErrorCodeUnknownError,
                .kMTGErrorCodeDailyLimit,
                .kMTGErrorCodeFailedToShow,
                .kMTGErrorCodeRewardVideoFailedToLoadPlayable,
                .kMTGErrorCodeRewardVideoFailedToLoadTemplateImage,
                .kMTGErrorCodeRewardVideoFailedToLoadPlayableURLFailed,
                .kMTGErrorCodeRewardVideoFailedToLoadPlayableURLReadyTimeOut,
                .kMTGErrorCodeRewardVideoFailedToLoadPlayableURLReadyNO,
                .kMTGErrorCodeRewardVideoFailedToLoadPlayableURLInvalid,
                .kMTGErrorCodeFailedToLoad,
                .KMTGErrorCodeEmptyBidToken,
                .kMTGErrorCodeURLisEmpty,
                .kMTGErrorCodeRewardVideoFailedToLoadMd5Invalid,
                .kMTGErrorCodeRewardVideoFailedToSettingInvalid,
                .kMTGErrorCodeFailedToShowCbp,
                .kMTGErrorCodeMaterialLoadFailed,
                .kMTGErrorCodeOfferExpired,
                .kMTGErrorCodeImageURLisEmpty,
                .kMTGErrorCodeNoSupportPopupWindow,
                .kMTGErrorCodeFailedDiskIO,
                .kMTGErrorCodeSocketIO,
                .kMTGErrorCodeAdsCountInvalid,
                .kMTGErrorCodeSocketInvalidStatus,
                .kMTGErrorCodeSocketInvalidContent:
            return .showFailureUnknown
        @unknown default:
            return nil
        }
    }
}

/// Convenience extension to access Mintegral credentials from the configuration.
private extension PartnerConfiguration {
    var appID: String? { credentials[.appIDKey] as? String }
    var apiKey: String? { credentials[.apiKey] as? String }
}

private extension String {
    /// Mintegral app ID credentials key
    static let appIDKey = "mintegral_app_id"
    /// Mintegral api key credentials key
    static let apiKey = "app_key"
}
