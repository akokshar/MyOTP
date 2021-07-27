//
//  ContentView.swift
//  MyOTP
//
//  Created by Alexander Koksharov on 05.02.2021.
//

import SwiftUI

struct MainView: View {
    @EnvironmentObject var tokens: Tokens

    private let cornerRadius: CGFloat = 8
    private let tokenButtonHeight: CGFloat = 64

    @State private var timer: Timer? = nil
    @State private var currentTime: Int64 = Int64(Date().timeIntervalSince1970)

    @State private var changedTokenId: UUID?

//    @State private var isHovering = false

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

    @State private var editToken: Token? = nil
    private var showEditor: Binding<Bool> {
        Binding(
            get: {
                editToken != nil
            },
            set: {
                if !$0 {
                    editToken = nil
                }
            }
        )
    }

    var body: some View {
        VStack() {
            // Header
            HStack(alignment: .center) {
                Text("MyOTP")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(Color.white)
                Spacer()
                Button(
                    action: {
                        editToken = Token("New token","")
                    },
                    label: {
                        Image(systemName: "plus.circle.fill")
//                            .font(.headline)
                    }
                )
                .buttonStyle(CommandButtonStyle(color: .green))
                Button(
                    action:{
                        NSApplication.shared.terminate(nil)
                    },
                    label: {
                        Image(systemName: "xmark.circle.fill")
//                            .font(.headline)
//                            .rotationEffect(.degrees(45), anchor: .center)
                    }
                )
                .buttonStyle(CommandButtonStyle(color: .red))
            }
            .padding([.top], cornerRadius)
            .padding([.leading, .trailing], 10)
            .frame(height: 40, alignment: .center)

            // Tokens list

            ScrollViewReader { (proxy: ScrollViewProxy) in
                List {
                    ForEach(tokens.items) { token in
                        TokenView(
                            token: token,
                            onEdit: {
                                editToken = token
                            },
                            onDelete: {
                                tokens.deleteToken(token)
                            },
                            onPick: {
                                do {
                                    let tokenStr = try token.genTOTP()
                                    let pb = NSPasteboard.general
                                    pb.declareTypes([.string], owner: nil)
                                    pb.setString(tokenStr, forType: .string)
                                    //                                        print(tokenStr)
                                } catch TokenError.TOTPError(let errorMsg) {
                                    alertMessage = "\(errorMsg)"
                                } catch {
                                    alertMessage = "\(error)"
                                }
                                (NSApplication.shared.delegate as! AppDelegate).hideMainWindow()
                            }
                        )
                        .frame(height: tokenButtonHeight)
                    }
//                    .onDelete { <#IndexSet#> in
//                        print("YAY")
//                    }
//                    .contextMenu {
//                        Button("♥️ - Hearts", action: {})
//                        Button("♣️ - Clubs", action: {})
//                        Button("♠️ - Spades", action: {})
//                        Button("♦️ - Diamonds", action: {})
//                    }
                }
//                .listStyle(SidebarListStyle())
//                .listStyle(InsetListStyle())
                .listStyle(PlainListStyle())
                .onChange(of: changedTokenId) { target in
                    if let target = target {
//                        changedTokenId = nil
                        withAnimation {
                            proxy.scrollTo(target, anchor: .center)
                        }
                    }
                }
            }
            .padding([.bottom], cornerRadius )
        }
        .background(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color(.windowBackgroundColor))
                .opacity(0.85)
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.gray, lineWidth: 0.29 )
                .blur(radius: 0.25 )
        )
        .frame(
            minWidth: 300, idealWidth: 350, maxWidth: .infinity,
            minHeight: 278, idealHeight: 278 ,  maxHeight: .infinity,
            alignment: .leading
        )
        .sheet(
            isPresented: showEditor,
            content: {
//                withAnimation {
                EditTokenView(
                    token: editToken!,
                    onDidSave: {
                        changedTokenId = editToken!.id
                        editToken = nil
                    },
                    onCancel: {
                        editToken = nil
                    }
                )
                .environmentObject(tokens)
                .onAppear() {
                    (NSApplication.shared.delegate as! AppDelegate).keepWindowOnTop(true)
                    pause()
                }
                .onDisappear() {
                    (NSApplication.shared.delegate as! AppDelegate).keepWindowOnTop(false)
                    tokens.touch()
                    start()
                }
//                }
            }
        )
        .alert(
            isPresented: showAlert,
            content: {
                Alert(title: Text(alertMessage))
            }
        )
        .onDisappear {
            pause()
        }
        .onAppear {
            tokens.touch()
            start()
        }
//        .onHover { hovering in
//            if !hovering {
//                (NSApplication.shared.delegate as! AppDelegate).hideMainWindow()
//            }
//        }
    }

    func start() {
//        print("Start")
        self.timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true){ _ in
            tokens.touch()
            currentTime = Int64(Date().timeIntervalSince1970)
//            print(self.currentTime)
        }
    }

    func pause() {
//        print("Pause")
        self.timer?.invalidate()
        timer = nil
    }
}

struct TokenView: View {
    var backgroundColor: Color = Color(.windowBackgroundColor)

    @ObservedObject var token: Token

    @State private var isHovering = false
    @State private var isDeleting = false

    private let spacing: CGFloat = 3
    private let onEdit: () -> Void
    private let onDelete: () -> Void
    private let onPick: () -> Void

    @State var offset = CGSize.zero

    init(token: Token, onEdit: @escaping ()->Void = {}, onDelete:  @escaping ()->Void = {}, onPick: @escaping ()->Void = {}) {
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.onPick = onPick
        self.token = token
    }

    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .center, spacing: spacing) {
                if (self.isDeleting) {
                    VStack(alignment: .center, spacing: 10) {
                        Button(
                            action:{
                                onDelete()
                            },
                            label: {
                                Image(systemName: "checkmark")
                            }
                        )
                        .buttonStyle(CommandButtonStyle(color: .blue))
                    }
                    .padding(.leading, spacing)
                }
                Button(
                    action: {
                        self.isHovering = false
                        self.isDeleting = false
                        onPick()
                    },
                    label: {
                        VStack(alignment: .leading) {
                            Text(token.tokenData.issuer)
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text(token.tokenData.account)
                                .font(.footnote)
                                .allowsTightening(true)
    //                            .multilineTextAlignment(.leading)
                                .truncationMode(.middle)
    //                        HStack {
                            ProgressView(value: token.tokenAge())
                                .frame(height: 5)
    //                        }
                        }
                    }
                )
                .buttonStyle(TokenButtonStyle())
                if (self.isHovering && !self.isDeleting) {
                    VStack(alignment: .center, spacing: 10) {
                        Button(
                            action:{
                                onEdit()
                            },
                            label: {
                                Image(systemName: "highlighter")
                            }
                        )
                        .buttonStyle(CommandButtonStyle(color: .green))
                        Button(
                            action:{
                                self.isDeleting = true
                            },
                            label: {
                                Image(systemName: "trash")
                            }
                        )
                        .buttonStyle(CommandButtonStyle(color: .red))
                    }
                    .padding(.trailing, spacing)
                }
            }
            .onHover { hovering in
                self.isHovering = hovering
                self.isDeleting = false
            }
            .animation(.easeInOut(duration: 0.2))
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
}

struct TokenButtonStyle: ButtonStyle {
    var backgroundColor: Color = Color(.windowBackgroundColor)

    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline) {
            configuration.label
                .padding(10)
        }
        .scaleEffect(configuration.isPressed ? 0.95 : 1)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(isHovering ? Color.primary : Color.secondary, lineWidth: 0.27)
                .blur(radius: 0.1)
        )
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(backgroundColor)
                .opacity(0.9)
        )
        .shadow(color: backgroundColor, radius: 3)
        .frame(alignment: .leading)
        .onHover { hovering in
            self.isHovering = hovering
        }
    }
}

struct CommandButtonStyle: ButtonStyle {
    @State private var isHovering = false

    var color: Color = Color.secondary
    var hoverColor: Color = Color.primary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .foregroundColor(isHovering ? hoverColor : color)
            .onHover { hovering in
                self.isHovering = hovering
            }
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
            .environmentObject(Tokens([
                Token("Amazon @ Lukapo", "devops@lukapo.com"),
                Token("Slack @ Lukapo", "devops@lukapo.com"),
                Token("iCloud @ Personal", "myself@icloud.com")
            ]))
            .previewLayout(.sizeThatFits)
            .frame(width: 350, height: 278, alignment: .center)
    }
}

struct TokenView_Previews: PreviewProvider {
    static var previews: some View {
        TokenView(token: Token("Issuer", "Account"))
            .frame(width: 300, height: 64)
    }
}
