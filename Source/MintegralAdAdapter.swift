//
//  MintegralAdAdapter.swift
//  ChartboostHeliumAdapterMintegral
//

import Foundation
import HeliumSdk
import MTGSDK
import UIKit

class MintegralAdAdapter: NSObject, PartnerAdAdapter {
    /// The current adapter instance
    let adapter: PartnerAdapter

    /// The current PartnerAdLoadRequest containing data relevant to the curent ad request
    let request: PartnerAdLoadRequest

    /// A PartnerAd object with a placeholder (nil) ad object.
    lazy var partnerAd = PartnerAd(ad: nil, details: [:], request: request)

    /// The partner ad delegate to send ad life-cycle events to.
    weak var partnerAdDelegate: PartnerAdDelegate?

    /// The completion handler to notify Helium of ad show completion result.
    var loadCompletion: ((Result<PartnerAd, Error>) -> Void)?

    /// The completion handler to notify Helium of ad load completion result.
    var showCompletion: ((Result<PartnerAd, Error>) -> Void)?

    /// Create a new instance of the adapter.
    /// - Parameters:
    ///   - adapter: The current adapter instance
    ///   - request: The current AdLoadRequest containing data relevant to the curent ad request
    ///   - partnerAdDelegate: The partner ad delegate to notify Helium of ad lifecycle events.
    init(adapter: PartnerAdapter, request: PartnerAdLoadRequest, partnerAdDelegate: PartnerAdDelegate) {
        self.adapter = adapter
        self.request = request
        self.partnerAdDelegate = partnerAdDelegate

        super.init()
    }

    /// Attempt to load an ad.
    /// - Parameters:
    ///   - viewController: The ViewController for ad presentation purposes.
    ///   - completion: The completion handler to notify Helium of ad load completion result.
    func load(with viewController: UIViewController?, completion: @escaping (Result<PartnerAd, Error>) -> Void) {
        fatalError()
    }

    /// Attempt to show the currently loaded ad.
    /// - Parameters:
    ///   - viewController: The ViewController for ad presentation purposes.
    ///   - completion: The completion handler to notify Helium of ad show completion result.
    func show(with viewController: UIViewController, completion: @escaping (Result<PartnerAd, Error>) -> Void) {
        fatalError()
    }
}

private extension String {
    /// Mintegral keys
    static let unitIDKey = "unit_id"
    static let mintegralUnitIDKey = "mintegral_unit_id"
}

extension MintegralAdAdapter {
    /// Unit id for loading
    var unitID: String? {
        if request.adm != nil {
            return request.partnerSettings[.unitIDKey]
        }
        else {
            return request.partnerSettings[.mintegralUnitIDKey]
        }
    }

    /// Extract bid ID from bid payload
    func bidID(from bidPayload: String) -> String? {
        typealias JSON = [String: Any]

        guard let bidPayloadData = bidPayload.data(using: .utf8) else {
            return nil
        }
        guard let json = try? JSONSerialization.jsonObject(with: bidPayloadData, options: .allowFragments) as? JSON else {
            return nil
        }
        guard let seatBid = json["seatbid"] as? [JSON] else {
            return nil
        }
        guard let firstSeatBid = seatBid.first else {
            return nil
        }
        guard let bid = firstSeatBid["bid"] as? [JSON] else {
            return nil
        }
        guard let firstBid = bid.first else {
            return nil
        }
        return firstBid["id"] as? String
    }
}
