//
//  EditTokenView.swift
//  MyOTP
//
//  Created by Alexander Koksharov on 10.02.2021.
//

import SwiftUI
import UniformTypeIdentifiers.UTType

extension NSTextField {
    open override var focusRingType: NSFocusRingType {
        get { .none }
        set { }
    }
}

struct EditTokenView: View {
    @EnvironmentObject var tokens: Tokens
    @ObservedObject var token: Token

    @State var selectedTab = 2
    @State var isTargeted = false
    @State var isSecretVisible = false

    @State private var alertMessage: String = ""
    private var showAlert: Binding<Bool> {
        Binding(
            get: {
                alertMessage != ""
            },
            set: {
                if !$0 {
                    alertMessage = ""
                }
            }
        )
    }

    private let onDidSave: ()->Void
    private let onCancel: ()->Void

    init(token: Token, onDidSave: @escaping ()->Void = {}, onCancel: @escaping ()->Void = {}) {
        self.onDidSave = onDidSave
        self.onCancel = onCancel
        self.token = token
    }

    var body: some View {
        VStack {
            TabView(selection: $selectedTab) {
                VStack {
                    Text("Drag QR image here...")
                    GroupBox {
                        Image(systemName: "qrcode")
                            .font(.largeTitle)
                            .frame(width: 100, height: 100, alignment: .center)
                    }
                    .onDrop(of: [.url, .fileURL], isTargeted: $isTargeted) { (items) -> Bool in
                        guard items.count > 0 else {
                            alertMessage = "No items dropped"
                            return false
                        }

                        items[0].loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { data, error in
                            DispatchQueue.main.async {
                            guard error == nil else {
                                alertMessage = error.debugDescription
                                return
                            }
                            guard let data = data as! Data?, let url = URL(dataRepresentation: data, relativeTo: nil) else {
                                alertMessage = "Cant construct image URL"
                                return
                            }
                            do {
                                try token.loadFromQRCode(NSImage(contentsOf: url))
                                selectedTab = 2
                            } catch TokenError.LoadQRCodeError(let errorMsg) {
                                alertMessage = "\(errorMsg)"
                            } catch {
                                alertMessage = "\(error)"
                            }
                            }
                        }
                        return true
                    }
                    .foregroundColor(isTargeted ? .accentColor : .secondary)
                }
                .tabItem {
                    Text("Scan QR image")
                }
                .tag(1)
                VStack(alignment: .leading) {
                    Section {
                        VStack(alignment: .leading) {
                            Text("Issuer:")
                                .font(.headline)
                            TextField("issuer name", text: $token.tokenData.issuer)
                                .textFieldStyle(PlainTextFieldStyle())
                                .font(.body)
                        }
                        .padding(5)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray, lineWidth: 1))
                    }
                    Section {
                        VStack(alignment: .leading) {
                            Text("Account:")
                                .font(.headline)
                            TextField("account name", text: $token.tokenData.account)
                                .textFieldStyle(PlainTextFieldStyle())
                                .font(.body)
                        }
                        .padding(5)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray, lineWidth: 1))
                    }
                    Section {
                        VStack(alignment: .leading) {
                            Text("Secret:")
                                .font(.headline)
                            HStack {
                                if isSecretVisible {
                                    TextField("secret", text: $token.tokenData.secret)
                                        .textFieldStyle(PlainTextFieldStyle())
                                        .font(.body)
                                } else {
                                    SecureField("secret", text: $token.tokenData.secret)
                                        .textFieldStyle(PlainTextFieldStyle())
                                        .font(.body)
                                }
                                Button(
                                    action: {
                                        isSecretVisible.toggle()
                                    },
                                    label: {
                                        Image(systemName: self.isSecretVisible ? "eye.slash" : "eye")
                                    }
                                )
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(5)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray, lineWidth: 1))
                    }
                    Section {
                        VStack(alignment: .leading) {
                            Text("Options:")
                                .font(.headline)
                            HStack {
                                Picker("Algorithm:", selection: $token.tokenData.alg) {
                                    Text("SHA1").tag(Algorithm.SHA1.rawValue)
                                    Text("SHA256").tag(Algorithm.SHA256.rawValue)
                                    Text("SHA512").tag(Algorithm.SHA512.rawValue)
                                }
                                .pickerStyle(SegmentedPickerStyle())
                                Spacer()
                                Stepper("Time interval: \(token.tokenData.period)", value: $token.tokenData.period, in: 30...60)
                                Spacer()
                                Stepper("Digits: \(token.tokenData.digits)", value: $token.tokenData.digits, in: 6...8)
                            }
                        }
                        .padding(5)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray, lineWidth: 1))
                    }
                }
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .tabItem {
                    Text("Manual")
                }
                .padding(5)
                .tag(2)
            }
//            .focusable(false)
            HStack {
                Button {
                    do {
                        try tokens.saveToken(token)
                        onDidSave()
                    } catch TokenError.KeychainError(let errorMsg) {
                        alertMessage = "\(errorMsg)"
                    } catch {
                        alertMessage = "\(error)"
                    }
                } label: {
                    Text("Save")
                }
                Button {
                    onCancel()
                } label: {
                    Text("Cancel")
                }
            }
        }
        .alert(
            isPresented: showAlert,
            content: {
                Alert(title: Text(alertMessage))
            }
        )
        .padding()
        .background(Color(.windowBackgroundColor).opacity(0.95))
        .frame(width: 500, height: 350, alignment: .center)
//        .animation(Animation.easeInOut(duration:0.2))
    }
}

struct EditTokenView_Previews: PreviewProvider {
    static var previews: some View {
        EditTokenView(token: Token("New token", "user@example.com"))
            .previewLayout(.sizeThatFits)
            .frame(width: 520, height: 400, alignment: .center)
    }
}
