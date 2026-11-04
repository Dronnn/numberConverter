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

/// root screen of the help sheet: a list of the nine help topics plus a
/// button to contact the developers via the mail composer.
struct HelpIndexView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var selectedTopic: Int?
    @State private var lastSelectedTopic: Int?
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var preferredCompactColumn = NavigationSplitViewColumn.sidebar
    @State private var isShowingMail = false
    @State private var isShowingMailUnavailableAlert = false

    var body: some View {
        NavigationSplitView(
            columnVisibility: $columnVisibility,
            preferredCompactColumn: $preferredCompactColumn
        ) {
            topicsList
                .navigationTitle(Text(AppTab.info.navigationTitleKey))
                .helpCloseToolbar(isEnabled: horizontalSizeClass != .regular)
                .navigationBarTitleDisplayMode(dynamicTypeSize.isAccessibilitySize ? .inline : .large)
                .navigationSplitViewColumnWidth(min: 280, ideal: 360)
        } detail: {
            NavigationStack {
                Group {
                    if let topic = HelpContent.topics.first(where: { $0.id == selectedTopic }) {
                        HelpPageView(topic: topic)
                            .id(topic.id)
                    } else {
                        ContentUnavailableView {
                            Label("nav.info", systemImage: "graduationcap")
                        } description: {
                            Text("help.index.sectionHeader")
                                .foregroundStyle(Color.primary)
                                .font(.headline)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .navigationTitle(Text(AppTab.info.navigationTitleKey))
                    }
                }
                .helpCloseToolbar()
            }
        }
        .navigationSplitViewStyle(.balanced)
        .onChange(of: selectedTopic) { _, topic in
            if let topic {
                lastSelectedTopic = topic
            }
        }
        .onChange(of: horizontalSizeClass) { _, sizeClass in
            if sizeClass == .regular, selectedTopic == nil {
                selectedTopic = lastSelectedTopic
            }
        }
        .onAppear { AppLogger.help.screen("helpIndex") }
        .sheet(isPresented: $isShowingMail) {
            MailComposeView()
                .ignoresSafeArea()
        }
        .alert("help.mail.unavailable", isPresented: $isShowingMailUnavailableAlert) {
            Button("common.ok", role: .cancel) {}
        }
    }

    private var topicsList: some View {
        List(selection: $selectedTopic) {
            Section {
                ForEach(HelpContent.topics) { topic in
                    NavigationLink(value: topic.id) {
                        Text(topic.indexRowTitle)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityIdentifier("help.topic.\(topic.id)")
                }
            } header: {
                Text("help.index.sectionHeader")
                    .foregroundStyle(Color.primary)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section {
                NavigationLink {
                    PrivacyView()
                } label: {
                    Text("privacy.helpEntry")
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityIdentifier("help.privacy")

                ContactDevelopersButton(action: contactDevelopers)
            }
        }
        .accessibilityIdentifier("help.sidebar")
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
        .accessibilityIdentifier("help.contact")
    }
}

#Preview {
    HelpIndexView()
        .environment(\.locale, Locale(identifier: "ru"))
}
