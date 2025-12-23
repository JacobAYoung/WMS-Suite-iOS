//
//  QuickBooksSettingsView.swift
//  WMS Suite
//
//  COMPLETELY REWRITTEN: OAuth-first design with modern UX
//

import SwiftUI

struct QuickBooksSettingsView: View {
    @StateObject private var tokenManager = QuickBooksTokenManager.shared
    
    // Only these two fields are user-editable
    @State private var clientId = UserDefaults.standard.string(forKey: "quickbooksClientId") ?? ""
    @State private var clientSecret = UserDefaults.standard.string(forKey: "quickbooksClientSecret") ?? ""
    
    // UI State
    @State private var showingCredentialsInput = false
    @State private var isConnecting = false
    @State private var errorMessage: String?
    @State private var showingHelp = false
    
    var body: some View {
        Form {
            // SECTION 1: Connection Status (Always Visible)
            connectionStatusSection
            
            // SECTION 2: Quick Actions
            quickActionsSection
            
            // SECTION 3: OAuth Configuration (Collapsible)
            oauthConfigurationSection
            
            // SECTION 4: Environment Toggle
            environmentSection
            
            // SECTION 5: Help & Instructions
            helpSection
        }
        .navigationTitle("QuickBooks")
        .navigationBarTitleDisplayMode(.large)
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
        .sheet(isPresented: $showingHelp) {
            NavigationView {
                QuickBooksHelpView()
            }
        }
    }
    
    // MARK: - Connection Status Section
    
    private var connectionStatusSection: some View {
        Section {
            HStack(spacing: 16) {
                // Status Icon
                Image(systemName: tokenManager.isAuthenticated ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(tokenManager.isAuthenticated ? .green : .secondary)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(tokenManager.isAuthenticated ? "Connected" : "Not Connected")
                        .font(.headline)
                    
                    if let companyId = tokenManager.getCompanyId() {
                        Text("Company ID: \(companyId)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Connect to QuickBooks to get started")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Quick Actions Section
    
    private var quickActionsSection: some View {
        Section {
            if tokenManager.isAuthenticated {
                // Disconnect Button
                Button(role: .destructive, action: disconnect) {
                    Label("Disconnect QuickBooks", systemImage: "power")
                }
            } else {
                // Connect Button
                Button(action: connect) {
                    HStack {
                        if isConnecting {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "link.circle.fill")
                        }
                        Text(isConnecting ? "Connecting..." : "Connect to QuickBooks")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(clientId.isEmpty || clientSecret.isEmpty || isConnecting)
                .listRowBackground(Color.accentColor.opacity(0.1))
                
                if clientId.isEmpty || clientSecret.isEmpty {
                    Text("⚠️ Enter OAuth credentials below to connect")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
    }
    
    // MARK: - OAuth Configuration Section
    
    private var oauthConfigurationSection: some View {
        Section {
            DisclosureGroup("OAuth Credentials", isExpanded: $showingCredentialsInput) {
                VStack(alignment: .leading, spacing: 16) {
                    // Client ID
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Client ID")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Enter from Developer Portal", text: $clientId)
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    
                    // Client Secret
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Client Secret")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        SecureField("Enter from Developer Portal", text: $clientSecret)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    // Save Button
                    Button(action: saveCredentials) {
                        Text("Save Credentials")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(clientId.isEmpty || clientSecret.isEmpty)
                }
                .padding(.vertical, 8)
            }
        } header: {
            Text("Configuration")
        } footer: {
            VStack(alignment: .leading, spacing: 8) {
                Text("Get your OAuth credentials from the QuickBooks Developer Portal:")
                
                Link("Open Developer Portal →", destination: URL(string: "https://developer.intuit.com/app/developer/myapps")!)
                    .font(.caption)
                    .bold()
            }
        }
    }
    
    // MARK: - Environment Section
    
    private var environmentSection: some View {
        Section {
            Toggle(isOn: $tokenManager.useSandbox) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sandbox Mode")
                        .font(.body)
                    Text("Use test environment for development")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        } header: {
            Text("Environment")
        } footer: {
            Text("Enable Sandbox to test with fake data. Disable for production use with real QuickBooks company.")
        }
    }
    
    // MARK: - Help Section
    
    private var helpSection: some View {
        Section {
            Button(action: { showingHelp = true }) {
                HStack {
                    Image(systemName: "book.fill")
                        .foregroundColor(.blue)
                    Text("Setup Instructions")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Link(destination: URL(string: "https://developer.intuit.com/app/developer/myapps")!) {
                HStack {
                    Image(systemName: "arrow.up.right.square")
                        .foregroundColor(.blue)
                    Text("QuickBooks Developer Portal")
                }
            }
            
            Link(destination: URL(string: "https://developer.intuit.com/app/developer/qbo/docs/get-started")!) {
                HStack {
                    Image(systemName: "doc.text")
                        .foregroundColor(.blue)
                    Text("API Documentation")
                }
            }
        } header: {
            Text("Help & Resources")
        }
    }
    
    // MARK: - Actions
    
    private func saveCredentials() {
        tokenManager.setCredentials(clientId: clientId, clientSecret: clientSecret)
        errorMessage = nil
        
        // Show success feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    private func connect() {
        guard !clientId.isEmpty, !clientSecret.isEmpty else {
            errorMessage = "Please enter Client ID and Secret first"
            return
        }
        
        // Save credentials first
        saveCredentials()
        
        isConnecting = true
        errorMessage = nil
        
        // Get root view controller
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            errorMessage = "Unable to present login"
            isConnecting = false
            return
        }
        
        // Start OAuth flow
        tokenManager.startOAuthFlow(presentingViewController: rootViewController)
        
        // Reset connecting state
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isConnecting = false
        }
    }
    
    private func disconnect() {
        tokenManager.logout()
        errorMessage = nil
        
        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }
}

// MARK: - Help View

struct QuickBooksHelpView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("🎯 Quick Start")
                        .font(.title2)
                        .bold()
                    
                    Text("Follow these steps to connect QuickBooks:")
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }
            
            Section("Step 1: Create Developer App") {
                InstructionStep(
                    number: 1,
                    title: "Go to Developer Portal",
                    detail: "Visit developer.intuit.com and sign in"
                )
                InstructionStep(
                    number: 2,
                    title: "Create an App",
                    detail: "Click 'My Apps' → 'Create an app' → Select 'QuickBooks Online'"
                )
                InstructionStep(
                    number: 3,
                    title: "Configure App",
                    detail: "Name: WMS Suite\nScopes: Accounting"
                )
            }
            
            Section("Step 2: Get Credentials") {
                InstructionStep(
                    number: 4,
                    title: "Open Keys & Credentials",
                    detail: "In your app, go to 'Keys & credentials' tab"
                )
                InstructionStep(
                    number: 5,
                    title: "Copy Client ID",
                    detail: "Copy your Development Client ID"
                )
                InstructionStep(
                    number: 6,
                    title: "Copy Client Secret",
                    detail: "Click 'Show' and copy your Client Secret"
                )
                InstructionStep(
                    number: 7,
                    title: "Add Redirect URI",
                    detail: "Add: wmssuite://oauth-callback\nThen click Save"
                )
            }
            
            Section("Step 3: Connect in App") {
                InstructionStep(
                    number: 8,
                    title: "Paste Credentials",
                    detail: "Enter Client ID and Secret in the app"
                )
                InstructionStep(
                    number: 9,
                    title: "Click 'Connect to QuickBooks'",
                    detail: "Browser will open for you to login"
                )
                InstructionStep(
                    number: 10,
                    title: "Authorize",
                    detail: "Login to QuickBooks and authorize the app"
                )
            }
            
            Section("Important Notes") {
                Label("Use Sandbox mode for testing", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                Label("Switch to Production when ready to go live", systemImage: "checkmark.circle")
                    .font(.caption)
                Label("Tokens refresh automatically - no manual intervention needed", systemImage: "arrow.clockwise")
                    .font(.caption)
            }
        }
        .navigationTitle("Setup Guide")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }
}

struct InstructionStep: View {
    let number: Int
    let title: String
    let detail: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Color.accentColor)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        QuickBooksSettingsView()
    }
}
