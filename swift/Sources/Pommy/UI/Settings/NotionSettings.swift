import SwiftUI

@MainActor
struct NotionSettings: View {
    @Environment(AppState.self) private var appState

    @State private var token:        String = ""
    @State private var databaseLink: String = ""
    @State private var databaseID:   String = ""

    @State private var editingToken:        Bool = false
    @State private var editingDatabaseLink: Bool = false
    @State private var editBuffer:          String = ""

    @State private var validating:          Bool    = false
    @State private var validationResult:   String? = nil
    @State private var isValid:            Bool    = false
    @State private var showDisconnectAlert: Bool   = false

    private var isConnected: Bool { appState.credentials != nil && isValid }
    private var canValidate:  Bool { !token.isEmpty && !databaseID.isEmpty && !validating }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                statusBanner
                credentialsCard
                validateCard
                if let creds = appState.credentials,
                   !creds.page_url.isEmpty,
                   let url = URL(string: creds.page_url) {
                    openTrackerCard(url: url)
                }
                if appState.credentials != nil {
                    syncCard
                }
                deviceCard
                if appState.credentials != nil {
                    disconnectCard
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear { loadCredentials() }
        .alert("Disconnect Notion?", isPresented: $showDisconnectAlert) {
            Button("Disconnect", role: .destructive) { disconnectNotion() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your local sessions are safe. Pommy will stop syncing to Notion.")
        }
    }

    // MARK: - Status banner

    private var statusBanner: some View {
        HStack(spacing: 6) {
            let notSetUp = token.isEmpty || databaseID.isEmpty
            let dotColor: Color = notSetUp
                ? .orange
                : (isValid ? .green : Color.secondary.opacity(0.5))
            Circle()
                .fill(dotColor)
                .frame(width: 6, height: 6)
                .campGlow(active: isValid, tint: .green, outerRadius: 6, innerRadius: 3, outerOpacity: 0.55, innerOpacity: 0.40)
            Text(notSetUp
                 ? "Not set up yet"
                 : (isValid ? "Connected" : "Saved · give it a poke to test"))
                .font(.pommyLabel)
                .tracking(0.4)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
        }
        .padding(.leading, 4)
    }

    // MARK: - Credentials card

    private var credentialsCard: some View {
        PommySectionCard {
            credentialRow(
                label:    "Integration token",
                value:    token,
                isSecret: true,
                isEditing: $editingToken
            ) {
                editBuffer   = token
                editingToken = true
            } onSave: {
                token = editBuffer.trimmingCharacters(in: .whitespaces)
                persistCredentials()
            }
            PommyRowDivider()
            credentialRow(
                label:    "Database link",
                value:    databaseLinkDisplay,
                isSecret: false,
                isEditing: $editingDatabaseLink
            ) {
                editBuffer          = databaseLink
                editingDatabaseLink = true
            } onSave: {
                databaseLink = editBuffer.trimmingCharacters(in: .whitespaces)
                databaseID   = NotionCredentials.extractDatabaseID(from: databaseLink) ?? ""
                persistCredentials()
            }
        }
    }

    /// Shows the link itself when valid, or a hint about parsing when the
    /// user has typed something we couldn't extract a database ID from.
    private var databaseLinkDisplay: String {
        if databaseLink.isEmpty { return "" }
        if databaseID.isEmpty   { return "⚠︎ Couldn't find a database ID in this link" }
        return databaseLink
    }

    // MARK: - Validate card

    private var validateCard: some View {
        PommySectionCard {
            Button {
                Task { await validateCredentials() }
            } label: {
                HStack(spacing: 8) {
                    if validating {
                        ProgressView().scaleEffect(0.7).frame(width: 14, height: 14)
                    } else {
                        Image(systemName: "checkmark.shield")
                            .font(.system(size: 12))
                    }
                    Text(validating ? "Validating…" : "Validate connection")
                        .font(.system(size: 13))
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!canValidate)
            .pommyPress(hoverScale: 1.0, pressScale: 0.99)

            if let result = validationResult {
                PommyRowDivider()
                HStack(spacing: 6) {
                    Image(systemName: isValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 12))
                    Text(result)
                        .font(.system(size: 12))
                        .lineLimit(1)
                }
                .foregroundStyle(isValid ? Color.green : Color.red)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
        }
    }

    // MARK: - Open Notion tracker card

    private func openTrackerCard(url: URL) -> some View {
        PommySectionCard {
            Link(destination: url) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 12))
                    Text("Open Notion tracker")
                        .font(.system(size: 13))
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .pommyPress(hoverScale: 1.0, pressScale: 0.99)
        }
    }

    // MARK: - Device card

    private var deviceCard: some View {
        PommySectionCard("Device") {
            PommySettingsRow("Device name") {
                TextField(
                    "",
                    text: Binding(
                        get: { appState.config.device },
                        set: { appState.config.device = $0 }
                    )
                )
                .textFieldStyle(.plain)
                .multilineTextAlignment(.trailing)
                .frame(width: 180)
                .onSubmit { appState.saveConfig() }
            }
        }
    }

    // MARK: - Credential row

    private func credentialRow(
        label:     String,
        value:     String,
        isSecret:  Bool,
        isEditing: Binding<Bool>,
        onEdit:    @escaping () -> Void,
        onSave:    @escaping () -> Void
    ) -> some View {
        Button(action: onEdit) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.pommyLabel)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.4)
                    Text(value.isEmpty
                         ? "Tap to set"
                         : (isSecret ? "••••••••••••" : value))
                        .font(.system(size: 13))
                        .foregroundStyle(value.isEmpty ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.primary))
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "pencil")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .pommyPress(hoverScale: 1.0, pressScale: 0.99)
        .popover(isPresented: isEditing, arrowEdge: .trailing) {
            editPopover(label: label, isSecret: isSecret, onSave: {
                onSave()
                isEditing.wrappedValue = false
            })
        }
    }

    // MARK: - Edit popover

    private func editPopover(
        label:    String,
        isSecret: Bool,
        onSave:   @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(label)
                .font(.pommyLabel)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.4)

            Group {
                if isSecret {
                    SecureField("", text: $editBuffer)
                } else {
                    TextField("", text: $editBuffer)
                }
            }
            .textFieldStyle(.plain)
            .font(.system(size: 13, design: .monospaced))
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Surface.fillSoft, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .frame(minWidth: 260)
            .onSubmit { onSave() }

            HStack {
                Spacer()
                Button("Done") { onSave() }
                    .buttonStyle(.plain)
                    .font(.system(size: 13, weight: .medium))
                    .pommySecondaryButton(cornerRadius: 8, horizontal: 16, vertical: 6)
                    .pommyPress(hoverScale: 1.0, pressScale: 0.97)
            }
        }
        .padding(16)
        .frame(minWidth: 300)
    }

    // MARK: - Sync card

    private var syncCard: some View {
        @Bindable var config = appState.config
        return PommySectionCard("Sync") {
            PommySettingsRow("Auto-sync") {
                Toggle(
                    "",
                    isOn: Binding(
                        get: { config.notionSyncEnabled },
                        set: { enabled in
                            config.notionSyncEnabled = enabled
                            appState.saveConfig()
                            if enabled, let creds = appState.credentials {
                                Task { await appState.syncNotionStats(creds: creds) }
                            }
                        }
                    )
                )
                .labelsHidden()
                .toggleStyle(.switch)
            }
        }
    }

    // MARK: - Disconnect card

    private var disconnectCard: some View {
        PommySectionCard {
            Button {
                showDisconnectAlert = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "minus.circle")
                        .font(.system(size: 12))
                    Text("Disconnect Notion")
                        .font(.system(size: 13))
                    Spacer()
                }
                .foregroundStyle(.red)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .pommyPress(hoverScale: 1.0, pressScale: 0.99)
        }
    }

    // MARK: - Logic

    private func disconnectNotion() {
        try? NotionCredentialsStore.clear()
        appState.credentials          = nil
        appState.notionSyncStatus     = .idle
        appState.notionStats          = nil
        appState.config.notionSyncEnabled = true
        appState.saveConfig()
        token        = ""
        databaseLink = ""
        databaseID   = ""
        validationResult = nil
        isValid          = false
    }

    private func loadCredentials() {
        guard let creds = appState.credentials else { return }
        token        = creds.token
        databaseLink = creds.page_url.isEmpty ? creds.database_id : creds.page_url

        // Re-derive the database ID from the saved link. Earlier builds had a
        // parser bug that stored the `?v=…` view ID instead of the database
        // ID; re-parsing on load auto-heals those installs.
        if let parsed = NotionCredentials.extractDatabaseID(from: databaseLink) {
            databaseID = parsed
            if parsed != creds.database_id {
                persistCredentials()
            }
        } else {
            databaseID = creds.database_id
        }
    }

    private func persistCredentials() {
        let creds = NotionCredentials(
            token:       token,
            database_id: databaseID,
            page_url:    databaseLink
        )
        try? NotionCredentialsStore.save(creds)
        appState.credentials = creds
        validationResult = nil
        isValid          = false
    }

    private func validateCredentials() async {
        guard let creds = appState.credentials else { return }
        validating       = true
        validationResult = nil
        do {
            let title        = try await NotionClient.validate(creds: creds)
            isValid          = true
            validationResult = "Connected: \(title)"
        } catch {
            isValid          = false
            validationResult = error.localizedDescription
        }
        validating = false
    }
}
