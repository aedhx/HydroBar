---
version: 1
slug: "website-index-html"
primary_target: "website/index.html"
related_targets: []
---

# Landing page · hydrobar.adx.cool

Scope: the public landing page, `website/index.html`. Visitor mode: Persuade.

Audience and job: general-public Mac users, mostly at a desk, deciding in seconds whether HydroBar fits their day. Action: install it free from the Mac App Store (DMG on GitHub until the App Store link is live). Proof: the interface itself, demonstrated; no testimonials, numbers or press exist and none are invented.

Constraints: colors and glass identical to the app (user, October 2026); keep the established world ( macOS interface recreated faithfully, Bricolage Grotesque display with Instrument Sans text, light and dark). English. WCAG AA. Reduce Motion honored.

Chosen structure: the giant ring (dealt card 2 of the surface round). Memorable moment: the menu bar's tiny ring zoomed to page scale, filling hour by hour as the visitor scrolls through a day.

## Direction contract

THESIS: The page is HydroBar's menu bar ring at a thousand times its size. One ring carries the story from 8 AM to the goal; it refuses the split hero with a product shot and the row of equal feature cards.

OWN-WORLD: Pinned by the user in October 2026: colors and glass identical to the app. A macOS wallpaper (green to blue, a raster with soft waves for the glass to act on) is the ground; the story, the bottle band, privacy and the close are dark material panes over it, like the app's popover; light sections are light material. System blue to cyan is the ring and every water mark, green to mint the goal, the track a 30 % gray. Notifications, menu bar and presets are glass as in macOS. Bricolage Grotesque for headlines, SF Rounded (ui-rounded) for the ring's numerals, Instrument Sans for text.

STORY: The visitor sees their day as a ring, watches it fill as they scroll from morning to night while reminders arrive at the right moments, wait during a call and end with a last call, understands it never nags and never leaves the Mac, and taps Get HydroBar free.

FIRST VIEWPORT: The macOS wallpaper (raster, green to blue waves) frames a dark glass window inset under the menu-bar strip, its blur visibly carrying the wallpaper's forms. Inside it: the ring about 108 % of the window's height, cropped by the window's right and bottom edges, percentage numeral at about a fifth of the ring inside it, pace tick and its time label. Left column: headline, one line of copy, systemBlue primary button "Get HydroBar free" with a secondary scroll link. A thin menu-bar strip across the top carries the nav, the mini ring and the clock. On phones the ring rises into the first screen below the call to action.

FORM: Surface structure 2 of 3 dealt (index 3 on my ordered list of seven: the ring as hero object). seed: none (unavailable)

Signature interaction: scroll-scrubbed day. The ring stays pinned while scrolling steps through the day's moments from 8 AM to 9:20 PM; the menu-bar clock, the moment's time and the tick share each moment's time (12-hour, as in English macOS), the arc fills, notification plates arrive at their times, the 2 PM call holds them, and at the goal the ring turns green with a checkmark. Motion grammar: arcs ease, numerals roll, nothing bounces; Reduce Motion shows the day as discrete stops.

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance

## Revision · 13 October 2026

Owner feedback on the live page: the app's interface was not shown, scrolling was not smooth, and micro-interactions were missing. The direction keeps its world (desktop, glass, ring) and changes its protagonist:

- THESIS, revised: the page is the Mac's menu bar with HydroBar running in it. The app's real popover hangs from the menu bar ring and works; the page-scale ring stays, behind it, and comes forward with the percentage when the popover closes. The earlier refusal of a product shot is withdrawn; the refusal of a row of equal feature cards stands.
- Proof by use: one shared day state drives the popover, the menu bar icon, the widget and the icon's menu. The app's keyboard shortcut (⌃⌥1) works on the page.
- Scroll: the glass no longer blurs live (pre-blurred fixed layer), and the day is scrubbed continuously with eased interpolation instead of nine jumps.
- Motion grammar, revised: the page eases; the recreated app springs, rolls and celebrates as the app does. DESIGN.md records both.
