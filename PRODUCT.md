# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

The product itself is a native macOS menu bar app (SwiftUI, macOS 15.1+). This record governs its web surfaces: the landing page at hydrobar.adx.cool and the App Store visuals rendered from HTML.

## Users

Mac users who want to drink enough water during their day, most often at a desk, at work. They are general public, not developers: they arrive from a link or a search, and their job is to decide in a few seconds whether this app fits their day, then install it from the Mac App Store. Power users (Raycast, keyboard shortcuts, open source) are a secondary audience, served further down the page.

## Product Purpose

HydroBar lives in the menu bar: one click logs a glass, a ring shows where the day stands, and reminders come only when they make sense. Success is a visitor who installs it from the Mac App Store and, the next day, drinks without having to think about it.

## Positioning

Reminders planned from the user's actual day rather than a fixed timer: they start from the last glass, stay within active hours, stop once the goal is reached, wait during calls, come more often when the user is behind pace, and say where the user stands. Days off have their own hours, cadence and goal. All of it with no account and no data leaving the Mac.

## Operating Context

The app sits in the macOS menu bar next to the clock, opened by a click, a global keyboard shortcut, a notification button, a desktop widget, Control Center (macOS 26), the Shortcuts app, Siri, a Focus filter, Raycast or `hydrobar://` deep links. Notifications offer the user's presets as buttons and a typed amount.

## Capabilities and Constraints

- Free. The Mac App Store link is not live yet; until it is, the direct download (DMG on GitHub Releases) is the working action.
- macOS 15.1 or later, Apple silicon and Intel. Control Center button requires macOS 26.
- 9 languages: English, French, German, Spanish, Italian, Japanese, Dutch, Portuguese, Simplified Chinese.
- Units: ml, cl, L, US and UK fl oz.
- Not available: iPhone app, Apple Health sync (HealthKit is not available to Mac apps), drink types (on the roadmap).
- Goal suggestion: about 30 ml per kg of body weight, presented as a starting point, not medical advice. HydroBar is not a medical device.

## Brand Commitments

- Name: HydroBar (capital H and B).
- Mascot and app icon: a felt water drop with a face (`Resources/HydroBar-icon.png`).
- The established visual world of the web surfaces is kept: the felt-drop blue as the accent, the macOS interface recreated faithfully, light and dark themes. Confirmed by the user in October 2026.
- Voice: plain, specific, friendly; describes what the app does rather than claiming.

## Evidence on Hand

- The app's own interface, reproduced from its SwiftUI views and localized strings (`marketing/`, `website/`).
- App icon and mascot, `Resources/`.
- Open source under MIT, code at github.com/aedhx/HydroBar.
- No testimonials, user counts, ratings, press or awards exist. None may be invented; the page proves by demonstration.

## Product Principles

- Show the app working rather than describing it.
- Respect the user's day: fewer, better-timed interruptions over more.
- Nothing leaves the Mac; say so concretely.
- Calm by default, specific when it matters.

## Accessibility & Inclusion

WCAG 2.2 AA contrast on the web surfaces; every motion respects Reduce Motion; the app itself supports VoiceOver and does not rely on color alone to show the goal.
