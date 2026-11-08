//
//  main.swift
//  NotchlyXPCHelper
//
//  Created by Alexander on 2025-11-16.
//

import Darwin
import Foundation

class ServiceDelegate: NSObject, NSXPCListenerDelegate {

    /// True when the process at `pid` is the executable of the .app this helper is embedded in.
    private static func isContainingApp(pid: pid_t) -> Bool {
        var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN) * 4)
        guard proc_pidpath(pid, &buffer, UInt32(buffer.count)) > 0 else { return false }
        let callerPath = String(cString: buffer)
        // .../Notchly.app/Contents/XPCServices/NotchlyXPCHelper.xpc -> .../Notchly.app
        let appPath = URL(fileURLWithPath: Bundle.main.bundlePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().path
        return appPath.hasSuffix(".app") && callerPath.hasPrefix(appPath + "/Contents/MacOS/")
    }
    
    /// This method is where the NSXPCListener configures, accepts, and resumes a new incoming NSXPCConnection.
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        
        // Only the app that contains this helper may talk to it: the helper runs outside the sandbox.
        // ponytail: checked by the caller's executable path because releases are ad-hoc signed, so there is no
        // team ID to require. Replace with setCodeSigningRequirement("anchor apple generic and ... team ID")
        // once builds are signed with a Developer ID.
        guard Self.isContainingApp(pid: newConnection.processIdentifier) else {
            NSLog("NotchlyXPCHelper: rejected a connection from pid %d, which is not the containing app", newConnection.processIdentifier)
            return false
        }

        // Configure the connection.
        // First, set the interface that the exported object implements.
        newConnection.exportedInterface = NSXPCInterface(with: (any NotchlyXPCHelperProtocol).self)
        
        // Next, set the object that the connection exports. All messages sent on the connection to this service will be sent to the exported object to handle. The connection retains the exported object.
        let exportedObject = NotchlyXPCHelper()
        newConnection.exportedObject = exportedObject
        
        // Resuming the connection allows the system to deliver more incoming messages.
        newConnection.resume()
        
        // Returning true from this method tells the system that you have accepted this connection. If you want to reject the connection for some reason, call invalidate() on the connection and return false.
        return true
    }
}

// Create the delegate for the service.
let delegate = ServiceDelegate()

// Set up the one NSXPCListener for this service. It will handle all incoming connections.
let listener = NSXPCListener.service()
listener.delegate = delegate

// Resuming the serviceListener starts this service. This method does not return.
listener.resume()
