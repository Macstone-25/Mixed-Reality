import SwiftUI

@MainActor
@Observable
class AppModel {
    let immersiveSpaceId = "ImmersiveSpace"
    let windowGroupId = "DefaultWindowGroup"
    var hasConsent = false
    var isSessionActive = false
}
