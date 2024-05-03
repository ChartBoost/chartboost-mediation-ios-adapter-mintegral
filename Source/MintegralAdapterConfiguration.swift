// Copyright 2022-2024 Chartboost, Inc.
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file.

import ChartboostMediationSDK
import Foundation
import MTGSDK

/// A list of externally configurable properties pertaining to the partner SDK that can be retrieved and set by publishers.
@objc public class MintegralAdapterConfiguration: NSObject, PartnerAdapterConfiguration {
    
    /// The version of the partner SDK.
    @objc public static var partnerSDKVersion: String {
        MTGSDK.sdkVersion()
    }

    /// The version of the adapter.
    /// It should have either 5 or 6 digits separated by periods, where the first digit is Chartboost Mediation SDK's major version, the last digit is the adapter's build version, and intermediate digits are the partner SDK's version.
    /// Format: `<Chartboost Mediation major version>.<Partner major version>.<Partner minor version>.<Partner patch version>.<Partner build version>.<Adapter build version>` where `.<Partner build version>` is optional.
    @objc public static let adapterVersion = "4.7.5.0.0"

    /// The partner's unique identifier.
    @objc public static let partnerID = "mintegral"

    /// The human-friendly partner name.
    @objc public static let partnerDisplayName = "Mintegral"

    /// Flag that can optionally be set to disable audio for the Mintegral SDK.
    /// Defaults to `false`.
    @objc public static var isMuted: Bool = false {
        didSet {
            log("Mute audio set to \(isMuted)")
        }
    }
}
