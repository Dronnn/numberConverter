//
//  HelpIndexView.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import MessageUI
import OSLog
import SwiftUI

// MARK: - HelpIndexView

/// root screen of the info/help tab: a list of the nine help topics plus a
/// button to contact the developers via the mail composer.
struct HelpIndexView: View {
    @State private var isShowingMail = false
    @State private var isShowingMailUnavailableAlert = false

    var body: some View {
        List {
            Section {
                ForEach(HelpContent.topics) { topic in
                    NavigationLink {
                        HelpPageView(topic: topic)
                    } label: {
                        Text(topic.indexRowTitle)
                    }
                }
            } header: {
                Text("help.index.sectionHeader")
            }

            Section {
                ContactDevelopersButton(action: contactDevelopers)
            }
        }
        .navigationTitle(Text(AppTab.info.navigationTitleKey))
        .onAppear { AppLogger.help.screen("helpIndex") }
        .sheet(isPresented: $isShowingMail) {
            MailComposeView()
                .ignoresSafeArea()
        }
        .alert("help.mail.unavailable", isPresented: $isShowingMailUnavailableAlert) {
            Button("common.ok", role: .cancel) {}
        }
    }

    private func contactDevelopers() {
        if MFMailComposeViewController.canSendMail() {
            isShowingMail = true
            AppLogger.help.info("mail composer opened")
        } else {
            isShowingMailUnavailableAlert = true
            AppLogger.help.info("mail composer unavailable")
        }
    }
}

// MARK: - ContactDevelopersButton

/// the accent-colored "write to the developers" row at the bottom of the index.
private struct ContactDevelopersButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("help.index.contactDevelopers")
        }
    }
}

#Preview {
    NavigationStack {
        HelpIndexView()
    }
    .environment(\.locale, Locale(identifier: "ru"))
}
