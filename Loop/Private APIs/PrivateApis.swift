//
//  PrivateApis.swift
//  Loop
//
//  Created by Kai Azim on 2025-11-27.
//
// This file declares private API functions using `@_silgen_name`.
//
// NOTE:
// `@_silgen_name` directly binds these Swift declarations to linker symbols.
// This is convenient, but unsafe: if the symbol is missing on a given macOS
// version, the process will crash at load time.
//
// For most private APIs, prefer using a dynamic "symbol loader" (see
// SkyLightSymbolLoader) where functions are resolved at runtime and stored
// as optional pointers. This allows graceful fallback on systems where the
// symbols are unavailable, instead of crashing.

import Cocoa

@_silgen_name("GetProcessForPID")
func GetProcessForPID(
    _ pid: pid_t,
    _ psn: inout ProcessSerialNumber
) -> OSStatus

@_silgen_name("_AXUIElementGetWindow")
func AXUIElementGetWindow(
    _ axUiElement: AXUIElement,
    _ wid: inout CGWindowID
) -> AXError
