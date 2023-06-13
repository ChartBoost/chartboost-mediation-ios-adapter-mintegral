// Copyright 2022-2023 Chartboost, Inc.
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file.

import ChartboostMediationSDK
import Foundation
import MTGSDK
import UIKit

/// Base class for Chartboost Mediation Mintegral adapter ads.
class MintegralAdapterAd: NSObject {
    
    /// The partner adapter that created this ad.
    let adapter: PartnerAdapter
    
    /// The ad load request associated to the ad.
    /// It should be the one provided on `PartnerAdapter.makeAd(request:delegate:)`.
    let request: PartnerAdLoadRequest
        
    /// The partner ad delegate to send ad life-cycle events to.
    /// It should be the one provided on `PartnerAdapter.makeAd(request:delegate:)`.
    weak var delegate: PartnerAdDelegate?
    
    /// Mintegral's Unit ID needed to load an ad.
    let unitID: String
    
    /// The completion handler to notify Chartboost Mediation of ad load completion result.
    var loadCompletion: ((Result<PartnerEventDetails, Error>) -> Void)?
    
    /// The completion handler to notify Chartboost Mediation of ad load completion result.
    var showCompletion: ((Result<PartnerEventDetails, Error>) -> Void)?
    
    init(adapter: PartnerAdapter, request: PartnerAdLoadRequest, delegate: PartnerAdDelegate) throws {
        self.adapter = adapter
        self.request = request
        self.delegate = delegate
        if let unitID = request.partnerSettings[request.adm == nil ? "mintegral_unit_id" : "unit_id"] as? String {
            self.unitID = unitID
        } else {
            throw adapter.error(.loadFailureAborted, description: "Missing unit ID in request")
        }
    }
}
