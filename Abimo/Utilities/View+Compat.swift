//
//  View+Compat.swift
//  Abimo
//
//  Back-deployment shims for APIs newer than the deployment target.
//

import SwiftUI

extension View {
    /// `navigationSubtitle` is iOS 26+. Below that the subtitle is simply omitted;
    /// the same progress text is visible in the journey header.
    @ViewBuilder
    func navigationSubtitleIfAvailable(_ subtitle: String) -> some View {
        if #available(iOS 26.0, *) {
            self.navigationSubtitle(subtitle)
        } else {
            self
        }
    }
}
