//
//  SkyLightSymbolLoader.swift
//  Loop
//
//  Created by Kai Azim on 2025-11-27.
//

import Darwin
import CoreGraphics
import OSLog

enum SkyLightSymbolLoader {
    private static let logger = Logger(category: "SkyLightSymbolLoader")

    private static let frameworkPath = "/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight"
    
    private static let handle: UnsafeMutableRawPointer? = {
        guard let handle =  dlopen(frameworkPath, RTLD_LAZY) else {
            logger.error("SkyLightSymbolLoader: failed to open \(frameworkPath)")
            return nil
        }
        return handle
    }()
    
    
    private static func loadSymbol<T>(_ name: StaticString) -> T? {
        guard let handle else {
            logger.error("SkyLightSymbolLoader: no handle; cannot load symbol \(name)")
            return nil
        }
        
        // Clear any prior error
        dlerror()
        
        guard let sym = dlsym(handle, name.description) else {
            if let err = dlerror() {
                logger.error("SkyLightSymbolLoader: failed to load symbol \(name): \(String(cString: err))")
            } else {
                logger.error("SkyLightSymbolLoader: failed to load symbol \(name)")
            }
            return nil
        }
        
        return unsafeBitCast(sym, to: T.self)
    }
}

extension SkyLightSymbolLoader {
    static let SLSMainConnectionID: (@convention(c) () -> SLSConnectionID)? = {
        loadSymbol("SLSMainConnectionID")
    }()
    
    static let SLSDefaultConnectionForThread: (@convention(c) () -> SLSConnectionID)? = {
        loadSymbol("SLSDefaultConnectionForThread")
    }()
    
    static let SLSWindowQueryWindows: (
        @convention(c) (
            _ cid: SLSConnectionID,
            _ windows: CFArray?,
            _ count: UInt32
        ) -> CFTypeRef
    )? = {
        loadSymbol("SLSWindowQueryWindows")
    }()

    static let SLSWindowQueryResultCopyWindows: (@convention(c) (_ query: CFTypeRef) -> CFTypeRef)? = {
        loadSymbol("SLSWindowQueryResultCopyWindows")
    }()

    static let SLSWindowIteratorGetCount: (@convention(c) (_ iterator: CFTypeRef) -> UInt32)? = {
        loadSymbol("SLSWindowIteratorGetCount")
    }()
    
    static let SLSWindowIteratorAdvance: (@convention(c) (_ iterator: CFTypeRef) -> Bool)? = {
        loadSymbol("SLSWindowIteratorAdvance")
    }()
    
    static let SLSWindowIteratorGetWindowID: (@convention(c) (_ iterator: CFTypeRef) -> CGWindowID)? = {
        loadSymbol("SLSWindowIteratorGetWindowID")
    }()
    
    static let SLSWindowIteratorGetParentID: (@convention(c) (_ iterator: CFTypeRef) -> CGWindowID)? = {
        loadSymbol("SLSWindowIteratorGetParentID")
    }()

    /// Returned value can be converted into `SLSWindowTags`.
    static let SLSWindowIteratorGetTags: (@convention(c) (_ iterator: CFTypeRef) -> UInt64)? = {
        loadSymbol("SLSWindowIteratorGetTags")
    }()
    
    static let SLSWindowIteratorGetAttributes: (@convention(c) (_ iterator: CFTypeRef) -> UInt32)? = {
        loadSymbol("SLSWindowIteratorGetAttributes")
    }()
    
    /// All four corner radii values returned in the array will be identical to each other, as seen in: https://gist.github.com/MrKai77/654975cc2a35cfa5328a7c0a90a01fde
    @available(macOS 26.0, *)
    static let SLSWindowIteratorGetResolvedCornerRadii: (
        @convention(c) (
            _ iterator: CFTypeRef,
            _ wid: UInt32
        ) -> Unmanaged<CFArray>
    )? = {
        loadSymbol("SLSWindowIteratorGetResolvedCornerRadii")
    }()
    
    static let SLSSetWindowBackgroundBlurRadius: (
        @convention(c) (
            _ connection: SLSConnectionID,
            _ wid: CGWindowID,
            _ radius: Int
        ) -> OSStatus
    )? = {
        loadSymbol("SLSSetWindowBackgroundBlurRadius")
    }()
    
    /// Options are described by `SLSWindowCaptureOptions`
    static let SLSHWCaptureWindowList: (
        @convention(c) (
            _ cid: SLSConnectionID,
            _ windowList: UnsafeMutablePointer<CGWindowID>,
            _ windowCount: Int,
            _ options: UInt32
        ) -> Unmanaged<CFArray>
    )? = {
       loadSymbol("SLSHWCaptureWindowList")
    }()
    
    /// For mode, pass in `kCPSUserGenerated` (defined further down).
    static let SLPSSetFrontProcessWithOptions: (
        @convention(c) (
            _ psn: UnsafeMutablePointer<ProcessSerialNumber>,
            _ wid: UInt32,
            _ mode: UInt32
        ) -> CGError
    )? = {
        loadSymbol("_SLPSSetFrontProcessWithOptions")
    }()
    
    static let SLPSPostEventRecordTo: (
        @convention(c) (
            _ psn: UnsafeMutablePointer<ProcessSerialNumber>,
            _ bytes: UnsafeMutablePointer<UInt8>
        ) -> CGError
    )? = {
        loadSymbol("SLPSPostEventRecordTo")
    }()
}

typealias SLSConnectionID = UInt32

struct SLSWindowTags: OptionSet {
    let rawValue: UInt64
    
    static let document = Self(rawValue: 1 << 0)
    static let floating = Self(rawValue: 1 << 1)
    static let attached = Self(rawValue: 1 << 7)
    static let sticky = Self(rawValue: 1 << 11)
    static let ignoresCycle = Self(rawValue: 1 << 18)
    static let modal = Self(rawValue: 1 << 31)
}

 struct SLSWindowCaptureOptions: OptionSet {
    let rawValue: UInt32

    static let ignoreGlobalClipShape = Self(rawValue: 1 << 11)

    // On a retina display, this captures at 1 pt : 4 px
    static let nominalResolution = Self(rawValue: 1 << 9)

    // Captures at 1 pt : 1px
    static let bestResolution = Self(rawValue: 1 << 8)

    // When Stage Manager is enabled, screenshots can become skewed. This param gets us full-size screenshots regardless
    static let fullSize = Self(rawValue: 1 << 19)
}

 let kCPSUserGenerated: UInt32 = 0x200
