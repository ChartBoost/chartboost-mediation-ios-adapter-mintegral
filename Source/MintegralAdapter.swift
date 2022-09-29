//
//  MintegralAdapter.swift
//  ChartboostHeliumAdapterMintegral
//

import Foundation
import HeliumSdk
import MTGSDK
import MTGSDKBidding
import UIKit

final class MintegralAdapter: ModularPartnerAdapter {
    /// Get the version of the partner SDK.
    let partnerSDKVersion: String = MTGSDK.sdkVersion()
    
    /// Get the version of the mediation adapter.
    let adapterVersion = "4.7.1.9.0"
    
    /// Get the internal name of the partner.
    let partnerIdentifier = "mintegral"
    
    /// Get the external/official name of the partner.
    let partnerDisplayName = "Mintegral"
    
    /// Storage of adapter instances.  Keyed by the request identifier.
    var adAdapters: [String: PartnerAdAdapter] = [:]

    /// The Mintegral SDK instance
    var mintegral: MTGSDK { MTGSDK.sharedInstance() }

    /// The last value set on `setGDPRApplies(_:)`.
    private var gdprApplies = false

    /// The last value set on `setGDPRConsentStatus(_:)`.
    private var gdprStatus: GDPRConsentStatus = .unknown

    /// Provides a new ad adapter in charge of communicating with a single partner ad instance.
    func makeAdAdapter(request: PartnerAdLoadRequest, partnerAdDelegate: PartnerAdDelegate) throws -> PartnerAdAdapter {
        switch request.format {
        case .interstitial:
            return MintegralInterstitialAdAdapter(adapter: self, request: request, partnerAdDelegate: partnerAdDelegate)
        case .rewarded:
            return MintegralRewardedAdAdapter(adapter: self, request: request, partnerAdDelegate: partnerAdDelegate)
        case .banner:
            return MintegralBannerAdAdapter(adapter: self, request: request, partnerAdDelegate: partnerAdDelegate)
        }
    }

    /// Onitialize the partner SDK so that it's ready to request and display ads.
    /// - Parameters:
    ///   - configuration: The necessary initialization data provided by Helium.
    ///   - completion: Handler to notify Helium of task completion.
    func setUp(with configuration: PartnerConfiguration, completion: @escaping (Error?) -> Void) {
        log(.setUpStarted)

        guard let appID = configuration.appID, !appID.isEmpty else {
            let error = error(.missingSetUpParameter(key: .appIDKey))
            log(.setUpFailed(error))
            return completion(error)
        }

        guard let apiKey = configuration.apiKey, !appID.isEmpty else {
            let error = error(.missingSetUpParameter(key: .apiKeyKey))
            log(.setUpFailed(error))
            return completion(error)
        }

        mintegral.setAppID(appID, apiKey: apiKey)
        log(.setUpSucceded)
        completion(nil)
    }
    
    /// Compute and return a bid token for the bid request.
    /// - Parameters:
    ///   - request: The necessary data associated with the current bid request.
    ///   - completion: Handler to notify Helium of task completion.
    func fetchBidderInformation(request: PreBidRequest, completion: @escaping ([String : String]) -> Void) {
        log(.fetchBidderInfoStarted(request))

        let bidderTokenKey = "buyeruid"

        var info: [String : String] = [:]
        if let token = MTGBiddingSDK.buyerUID() {
            info[bidderTokenKey] = token
        }

        log(.fetchBidderInfoSucceeded(request))
        completion(info)
    }
    
    /// Notify the partner SDK of GDPR applicability as determined by the Helium SDK.
    /// - Parameter applies: true if GDPR applies, false otherwise.
    func setGDPRApplies(_ applies: Bool) {
        gdprApplies = applies
        updateGDPRConsent()
    }
    
    /// Notify the partner SDK of the GDPR consent status as determined by the Helium SDK.
    /// - Parameter status: The user's current GDPR consent status.
    func setGDPRConsentStatus(_ status: GDPRConsentStatus) {
        gdprStatus = status
        updateGDPRConsent()
    }

    private func updateGDPRConsent() {
        guard gdprApplies else {
            return
        }

        let constentStatus = gdprStatus == .granted
        log(.privacyUpdated(setting: "'ConstentStatus Bool'", value: constentStatus))
        mintegral.consentStatus = constentStatus
    }

    /// Notify the partner SDK of the COPPA subjectivity as determined by the Helium SDK.
    /// - Parameter isSubject: True if the user is subject to COPPA, false otherwise.
    func setUserSubjectToCOPPA(_ isSubject: Bool) {
        guard isSubject else {
            return
        }

        // Comment copied from original adapter:
        // We decided to use this method, same as CCPA, per Mintegral's instructions
        log(.privacyUpdated(setting: "'DoNotTrackStatus Bool'", value: true))
        mintegral.doNotTrackStatus = true
    }
    
    /// Notify the partner SDK of the CCPA privacy String as supplied by the Helium SDK.
    /// - Parameters:
    ///   - hasGivenConsent: True if the user has given CCPA consent, false otherwise.
    ///   - privacyString: The CCPA privacy String.
    func setCCPAConsent(hasGivenConsent: Bool, privacyString: String?) {
        guard !hasGivenConsent else {
            return
        }
        // http://cdn-adn.rayjump.com/cdn-adn/v2/markdown_v2/index.html?file=sdk-m_sdk-ios&lang=en#settingsforuserpersonaldataprotection
        log(.privacyUpdated(setting: "'DoNotTrackStatus Bool'", value: true))
        mintegral.doNotTrackStatus = true
    }
}

/// Convenience extension to access Mintegral credentials from the configuration.
private extension PartnerConfiguration {
    var appID: String? { credentials[.appIDKey] as? String }
    var apiKey: String? { credentials[.apiKeyKey] as? String }
}

private extension String {
    /// Mintegral keys
    static let appIDKey = "mintegral_app_id"
    static let apiKeyKey = "app_key"
}
