// Copyright 2022-2023 Chartboost, Inc.
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
    
    /// The version of the partner SDK.
    let partnerSDKVersion: String = MTGSDK.sdkVersion()
    
    /// The version of the adapter.
    /// It should have either 5 or 6 digits separated by periods, where the first digit is Chartboost Mediation SDK's major version, the last digit is the adapter's build version, and intermediate digits are the partner SDK's version.
    /// Format: `<Chartboost Mediation major version>.<Partner major version>.<Partner minor version>.<Partner patch version>.<Partner build version>.<Adapter build version>` where `.<Partner build version>` is optional.
    let adapterVersion = "4.7.1.9.0"
    
    /// The partner's unique identifier.
    let partnerIdentifier = "mintegral"
    
    /// The human-friendly partner name.
    let partnerDisplayName = "Mintegral"
    
    /// The designated initializer for the adapter.
    /// Chartboost Mediation SDK will use this constructor to create instances of conforming types.
    /// - parameter storage: An object that exposes storage managed by the Chartboost Mediation SDK to the adapter.
    /// It includes a list of created `PartnerAd` instances. You may ignore this parameter if you don't need it.
    init(storage: PartnerAdapterStorage) { }
    
    /// Does any setup needed before beginning to load ads.
    /// - parameter configuration: Configuration data for the adapter to set up.
    /// - parameter completion: Closure to be performed by the adapter when it's done setting up. It should include an error indicating the cause for failure or `nil` if the operation finished successfully.
    func setUp(with configuration: PartnerConfiguration, completion: @escaping (Error?) -> Void) {
        log(.setUpStarted)
        
        // Get credentials, fail early if they are unavailable
        guard let appID = configuration.appID, !appID.isEmpty else {
            let error = error(.initializationFailureInvalidCredentials, description: "Missing \(String.appIDKey)")
            log(.setUpFailed(error))
            return completion(error)
        }
        guard let apiKey = configuration.apiKey, !apiKey.isEmpty else {
            let error = error(.initializationFailureInvalidCredentials, description: "Missing \(String.apiKey)")
            log(.setUpFailed(error))
            return completion(error)
        }
        
        // Set up Mintegral SDK
        // It's necessary to call `setAppID` on the main thread because it uses `UIApplication.canOpenURL(_:)` directly on the current thread.
        DispatchQueue.main.async { [self] in
            MTGSDK.sharedInstance().setAppID(appID, apiKey: apiKey)
            
            // Succeed always
            log(.setUpSucceded)
            completion(nil)
        }
    }
    
    /// Fetches bidding tokens needed for the partner to participate in an auction.
    /// - parameter request: Information about the ad load request.
    /// - parameter completion: Closure to be performed with the fetched info.
    func fetchBidderInformation(request: PreBidRequest, completion: @escaping ([String : String]?) -> Void) {
        log(.fetchBidderInfoStarted(request))
        
        if let info = MTGBiddingSDK.buyerUID() {
            log(.fetchBidderInfoSucceeded(request))
            completion(["buyeruid": info])
        } else {
            let error = error(.prebidFailureUnknown, description: "Got nil buyerUID")
            log(.fetchBidderInfoFailed(request, error: error))
            completion(nil)
        }
    }
    
    /// Indicates if GDPR applies or not and the user's GDPR consent status.
    /// - parameter applies: `true` if GDPR applies, `false` if not, `nil` if the publisher has not provided this information.
    /// - parameter status: One of the `GDPRConsentStatus` values depending on the user's preference.
    func setGDPR(applies: Bool?, status: GDPRConsentStatus) {
        // See http://cdn-adn.rayjump.com/cdn-adn/v2/markdown_v2/index.html?file=sdk-m_sdk-ios&lang=en#settingsforuserpersonaldataprotection
        if applies == true {
            let constentStatus = status == .granted
            MTGSDK.sharedInstance().consentStatus = constentStatus
            log(.privacyUpdated(setting: "consentStatus", value: constentStatus))
        }
    }
    
    /// Indicates the CCPA status both as a boolean and as an IAB US privacy string.
    /// - parameter hasGivenConsent: A boolean indicating if the user has given consent.
    /// - parameter privacyString: An IAB-compliant string indicating the CCPA status.
    func setCCPA(hasGivenConsent: Bool, privacyString: String) {
        // See http://cdn-adn.rayjump.com/cdn-adn/v2/markdown_v2/index.html?file=sdk-m_sdk-ios&lang=en#settingsforuserpersonaldataprotection
        let doNotTrackStatus = !hasGivenConsent
        guard doNotTrackStatus else {
            return  // we don't set doNotTrackStatus to false to avoid overwritting a value possibly set by setCOPPA()
        }
        MTGSDK.sharedInstance().doNotTrackStatus = doNotTrackStatus
        log(.privacyUpdated(setting: "doNotTrackStatus", value: doNotTrackStatus))
    }
    
    /// Indicates if the user is subject to COPPA or not.
    /// - parameter isChildDirected: `true` if the user is subject to COPPA, `false` otherwise.
    func setCOPPA(isChildDirected: Bool) {
        // See http://cdn-adn.rayjump.com/cdn-adn/v2/markdown_v2/index.html?file=sdk-m_sdk-ios&lang=en#settingsforuserpersonaldataprotection
        guard isChildDirected else {
            return  // we don't set doNotTrackStatus to false to avoid overwritting a value possibly set by setCCPA()
        }
        // Using this method, same as CCPA, per Mintegral's instructions
        MTGSDK.sharedInstance().doNotTrackStatus = isChildDirected
        log(.privacyUpdated(setting: "doNotTrackStatus", value: isChildDirected))
    }
    
    /// Creates a new ad object in charge of communicating with a single partner SDK ad instance.
    /// Chartboost Mediation SDK calls this method to create a new ad for each new load request. Ad instances are never reused.
    /// Chartboost Mediation SDK takes care of storing and disposing of ad instances so you don't need to.
    /// `invalidate()` is called on ads before disposing of them in case partners need to perform any custom logic before the object gets destroyed.
    /// If, for some reason, a new ad cannot be provided, an error should be thrown.
    /// - parameter request: Information about the ad load request.
    /// - parameter delegate: The delegate that will receive ad life-cycle notifications.
    func makeAd(request: PartnerAdLoadRequest, delegate: PartnerAdDelegate) throws -> PartnerAd {
        switch request.format {
        case .interstitial:
            if request.adm == nil {
                return try MintegralAdapterInterstitialAd(adapter: self, request: request, delegate: delegate)
            } else {
                return try MintegralAdapterInterstitialBidAd(adapter: self, request: request, delegate: delegate)
            }
        case .rewarded:
            return try MintegralAdapterRewardedAd(adapter: self, request: request, delegate: delegate)
        case .banner:
            return try MintegralAdapterBannerAd(adapter: self, request: request, delegate: delegate)
        @unknown default:
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
                .kMTGErrorCodeSocketIO:
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
                .kMTGErrorCodeSocketIO:
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
