//
//  AppDelegate.swift
//  MyOTP
//
//  Created by Alexander Koksharov on 05.02.2021.
//

import Cocoa
import SwiftUI
import UniformTypeIdentifiers.UTType

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSDraggingDestination {
    private let tokens: Tokens = Tokens()

    private var statusBarItem: NSStatusItem!
//    private var monitor: Any?
//    private var dragMonitor: Any?
    private var mainWindow: NSWindow!
    private var keepOnTop: Bool = false

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        statusBarItem = NSStatusBar.system.statusItem(withLength: CGFloat(NSStatusItem.squareLength))
        statusBarItem.button?.image = NSImage.init(size: NSSize(width: 24, height: 24), flipped: false) { rect in
            let icon = NSImage(named: "Icon")
            guard let representation = icon?.bestRepresentation(for: rect, context: nil, hints: nil) else {
                return false
            }
            return representation.draw(in: rect)
        }

//        let statusBarMenu = NSMenu(title: "MyOTP")
//        statusBarItem.menu = statusBarMenu
//
//        let menuItem = NSMenuItem()
//        menuItem.view = NSHostingView(
//            rootView: MainView()
//                .environmentObject(Tokens())
//        )
//        menuItem.view?.setFrameSize(NSSize(width: 200, height: 400))
//        statusBarMenu.addItem(menuItem)
//
//        return

        statusBarItem.button?.action = #selector(AppDelegate.toggleMainWindow(_:))
        statusBarItem.button?.sendAction(on: .leftMouseDown)
        statusBarItem.button?.window?.registerForDraggedTypes([NSPasteboard.PasteboardType.URL, NSPasteboard.PasteboardType.fileURL])
        statusBarItem.button?.window?.delegate = self;
//        statusBarItem.button?.window?.backgroundColor = NSColor.red

        mainWindow = NSWindow()
        mainWindow.styleMask = [ .borderless ]
        mainWindow.level = .floating
        mainWindow.backgroundColor = .clear
        mainWindow.isOpaque = true
        mainWindow.isReleasedWhenClosed = false
// // //        mainWindow.hidesOnDeactivate = true
//        mainWindow.contentView = NSHostingView(
//            rootView: MainView()
//                .environmentObject(tokens)
//        )
    }

    func applicationWillTerminate(_ aNotification: Notification) {
//        if let monitor = dragMonitor {
//            NSEvent.removeMonitor(monitor)
//            dragMonitor = nil
//        }
    }

    func applicationWillHide(_ notification: Notification) {
        print("HIDE")
    }

    func applicationDidResignActive(_ notification: Notification) {
        hideMainWindow()
    }

    func draggingEnded(_ sender: NSDraggingInfo) {
        print("Ended")
        guard let frame = statusBarItem.button?.window?.frame else {
            return
        }
        guard sender.draggingLocation.x > 0 && sender.draggingLocation.x < frame.width else {
            return
        }
        guard sender.draggingLocation.y > 0 && sender.draggingLocation.y < frame.height else {
            return
        }

        //tokens.saveToken(fromImage: nil)
        showMainWindow()
    }

    func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        print("enter")
        return NSDragOperation.copy
    }

    func draggingExited(_ sender: NSDraggingInfo?) {
        print("exit")
    }

//    func draggingUpdated(sender: NSDraggingInfo!) -> NSDragOperation  {
//        print("UPDATED")
//        return NSDragOperation.copy
//    }

    open func showMainWindow() {
        guard let button = statusBarItem.button else {
            return
        }

        let currentScreen = NSScreen.screens.first{ screen in
            //TODO: find screen with statusbar button
            return true
        }
        guard let screen = currentScreen else {
            return
        }

        guard let buttonRect = button.window?.convertToScreen(button.frame) else {
            return
        }

        mainWindow.contentView = NSHostingView(
            rootView: MainView()
                .environmentObject(tokens)
        )

        var windowRect = NSRect(
            x: buttonRect.origin.x,
            y: buttonRect.origin.y - mainWindow.frame.height - 6,
            width: mainWindow.frame.width,
            height: mainWindow.frame.height
        )

        let d = screen.frame.width - (windowRect.maxX + 6)
        if d < 0 {
            windowRect.origin.x += d
        }
        mainWindow.setFrame(windowRect, display: true, animate: true)

//        if monitor == nil {
//            monitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown) { event in
//                self.hideMainWindow()
//            }
//        }

        mainWindow.makeKeyAndOrderFront(mainWindow)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    open func hideMainWindow() {
        if keepOnTop {
            return
        }
//        if let monitor = monitor {
//            NSEvent.removeMonitor(monitor)
//        monitor = nil
//        }
        NSApplication.shared.deactivate()
        mainWindow.contentView = nil
        mainWindow.close()
    }

    @objc func toggleMainWindow(_ sender: AnyObject?) {
        if mainWindow != nil && mainWindow.isVisible {
//        if mainWindow.isVisible {
            hideMainWindow()
        } else {
            showMainWindow()
        }
    }

    func keepWindowOnTop(_ keep: Bool) {
        self.keepOnTop = keep
    }

}
