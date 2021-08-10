//
//  AppDelegate.swift
//  MyOTP
//
//  Created by Alexander Koksharov on 05.02.2021.
//

import Cocoa
import SwiftUI
import UniformTypeIdentifiers.UTType

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSDraggingDestination, NSMenuDelegate {
    private let tokens: Tokens = Tokens()

    private var statusBarItem: NSStatusItem!
    private var observation : NSKeyValueObservation?
    private var localMonitor: Any?
    private var globalMonitor: Any?
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

//        statusBarItem.button?.action = #selector(AppDelegate.toggleMainWindow(_:))
//        statusBarItem.button?.sendAction(on: .leftMouseDown)
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { event in
            if event.window == self.statusBarItem.button?.window {
                self.toggleMainWindow(self.statusBarItem.button)
                return nil
            }
            return event
        }
//        observation = statusBarItem.observe(\.button?.isHighlighted, options: [.new, .old]) { _, change in
//            print("\(change.oldValue.debugDescription) -> \(change.newValue.debugDescription)")
//        }

        statusBarItem.button?.window?.registerForDraggedTypes([NSPasteboard.PasteboardType.URL, NSPasteboard.PasteboardType.fileURL])
        statusBarItem.button?.window?.delegate = self;

        mainWindow = NSWindow()
        mainWindow.styleMask = [ .borderless ]
        mainWindow.level = .floating
        mainWindow.backgroundColor = .clear
        mainWindow.isOpaque = true
        mainWindow.isReleasedWhenClosed = false
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }

        hideMainWindow()
    }

    func applicationDidResignActive(_ notification: Notification) {
        hideMainWindow()
    }

//    func draggingEnded(_ sender: NSDraggingInfo) {
//        print("Ended")
//        guard let frame = statusBarItem.button?.window?.frame else {
//            return
//        }
//        guard sender.draggingLocation.x > 0 && sender.draggingLocation.x < frame.width else {
//            return
//        }
//        guard sender.draggingLocation.y > 0 && sender.draggingLocation.y < frame.height else {
//            return
//        }
//
//        //tokens.saveToken(fromImage: nil)
//        showMainWindow()
//    }

//    func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
//        print("enter")
//        return NSDragOperation.copy
//    }
//
//    func draggingExited(_ sender: NSDraggingInfo?) {
//        print("exit")
//    }

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

        NSApp.activate(ignoringOtherApps: true)
        mainWindow.makeKeyAndOrderFront(nil)

        statusBarItem.button?.isHighlighted = true
        if globalMonitor == nil {
            globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { event in
                if event.window != self.statusBarItem.button?.window && event.window != self.mainWindow {
                    self.hideMainWindow()
                }
            }
        }
    }

    open func hideMainWindow() {
        if keepOnTop {
            return
        }
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        NSApp.deactivate()

        mainWindow.contentView = nil
        mainWindow.close()
        statusBarItem.button?.isHighlighted = false
    }

    @objc func toggleMainWindow(_ sender: AnyObject?) {
        if mainWindow.isVisible {
            hideMainWindow()
        } else {
            showMainWindow()
        }
    }

    func keepWindowOnTop(_ keep: Bool) {
        self.keepOnTop = keep
    }

}
