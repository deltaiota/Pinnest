//
//  PinWindowSuite.swift
//  PinnestTests
//

import Testing

/// Parent of every suite that puts real pin windows on screen.
///
/// `.serialized` orders tests *within* a suite, not across suites — so two sibling
/// suites would still run at the same time and overlap each other's windows, and a
/// hit test would answer for the wrong pin. Nesting them here makes the ordering
/// apply to the whole tree.
@Suite(.serialized)
@MainActor
struct PinWindowSuite {}
