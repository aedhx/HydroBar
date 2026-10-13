---
name: HydroBar
description: The menu bar ring at page scale, on glass over a macOS desktop.
colors:
  water: "#0a84ff"
  water-light: "#64d2ff"
  goal: "#30d158"
  goal-light: "#66d4cf"
  track: "rgba(142, 142, 147, .3)"
  action: "#0068d6"
  action-hover: "#005ec2"
  water-tint: "rgba(10, 132, 255, .25)"
  water-tint-strong: "rgba(10, 132, 255, .4)"
  desktop-blue: "#3060c0"
  mat-dark: "rgba(24, 26, 33, .62)"
  mat-deep: "rgba(14, 16, 22, .72)"
  mat-goal: "rgba(14, 40, 30, .66)"
  mat-light: "rgba(250, 250, 252, .72)"
  mat-light-dark-scheme: "rgba(36, 38, 46, .7)"
  plate: "rgba(48, 50, 60, .66)"
  glass-control: "rgba(255, 255, 255, .14)"
  menubar-dark: "rgba(28, 30, 38, .9)"
  bar-light: "rgba(250, 250, 252, .97)"
  bar-light-dark-scheme: "rgba(36, 38, 46, .97)"
  label-on-dark: "#ffffff"
  label-on-dark-2: "#c9d6ee"
  ink: "#1d1d1f"
  ink-dark-scheme: "#f5f5f7"
  ink-2: "#48484d"
  ink-2-dark-scheme: "#c9d6ee"
  fill: "rgba(120, 120, 128, .14)"
  fill-dark-scheme: "rgba(120, 120, 128, .32)"
  line: "rgba(60, 60, 67, .16)"
  line-dark-scheme: "rgba(255, 255, 255, .12)"
  recap-deep: "#0058c4"
  recap-bright: "#0a6cd6"
typography:
  display:
    fontFamily: "Bricolage Grotesque, ui-rounded, system-ui, sans-serif"
    fontSize: "clamp(48px, 6.4vw, 96px)"
    fontWeight: 760
    lineHeight: 1.02
    letterSpacing: "-0.035em"
  headline:
    fontFamily: "Bricolage Grotesque, ui-rounded, system-ui, sans-serif"
    fontSize: "clamp(38px, 5.4vw, 80px)"
    fontWeight: 760
    lineHeight: 1.02
    letterSpacing: "-0.025em"
  title:
    fontFamily: "Bricolage Grotesque, ui-rounded, system-ui, sans-serif"
    fontSize: "24px"
    fontWeight: 680
    lineHeight: 1.2
    letterSpacing: "-0.01em"
  numeral:
    fontFamily: "Bricolage Grotesque, system-ui, sans-serif"
    fontSize: "clamp(56px, 6vw, 92px)"
    fontWeight: 700
    lineHeight: 0.9
    letterSpacing: "-0.035em"
    fontFeature: "tnum"
  lede:
    fontFamily: "Instrument Sans, system-ui, -apple-system, sans-serif"
    fontSize: "clamp(19px, 1.6vw, 22px)"
    fontWeight: 400
    lineHeight: 1.6
  body:
    fontFamily: "Instrument Sans, system-ui, -apple-system, sans-serif"
    fontSize: "18px"
    fontWeight: 400
    lineHeight: 1.6
  button:
    fontFamily: "Instrument Sans, system-ui, -apple-system, sans-serif"
    fontSize: "18px"
    fontWeight: 650
    lineHeight: 1
  label:
    fontFamily: "Instrument Sans, system-ui, -apple-system, sans-serif"
    fontSize: "15px"
    fontWeight: 600
    lineHeight: 1.25
rounded:
  chip: "8px"
  key: "9px"
  control: "14px"
  plate: "18px"
  card: "22px"
  window-compact: "24px"
  window: "30px"
spacing:
  window-gap-compact: "8px"
  window-gap: "14px"
  section-inline: "clamp(20px, 4vw, 56px)"
  band-block: "clamp(96px, 12vw, 160px)"
  section-block: "clamp(96px, 13vw, 176px)"
components:
  button-primary:
    backgroundColor: "{colors.action}"
    textColor: "{colors.label-on-dark}"
    typography: "{typography.button}"
    rounded: "{rounded.control}"
    padding: "0 28px"
    height: "56px"
  button-primary-hover:
    backgroundColor: "{colors.action-hover}"
  button-glass:
    backgroundColor: "{colors.glass-control}"
    textColor: "{colors.label-on-dark}"
    typography: "{typography.button}"
    rounded: "{rounded.control}"
    padding: "0 28px"
    height: "56px"
  button-menubar:
    backgroundColor: "{colors.action}"
    textColor: "{colors.label-on-dark}"
    rounded: "{rounded.key}"
    padding: "0 14px"
    height: "32px"
  segmented:
    backgroundColor: "{colors.fill}"
    textColor: "{colors.ink-2}"
    rounded: "{rounded.control}"
    padding: "5px"
  segmented-selected:
    backgroundColor: "{colors.action}"
    textColor: "{colors.label-on-dark}"
    rounded: "10px"
    padding: "12px 22px"
  mark-key:
    backgroundColor: "{colors.water-tint}"
    textColor: "{colors.label-on-dark}"
    rounded: "{rounded.control}"
    padding: "0 20px"
    height: "60px"
  mark-key-hover:
    backgroundColor: "{colors.water-tint-strong}"
  menubar:
    backgroundColor: "{colors.menubar-dark}"
    textColor: "{colors.label-on-dark}"
    padding: "0 22px"
    height: "44px"
  menubar-light:
    backgroundColor: "{colors.bar-light}"
    textColor: "{colors.ink}"
  window-dark:
    backgroundColor: "{colors.mat-dark}"
    textColor: "{colors.label-on-dark}"
    rounded: "{rounded.window}"
    padding: "clamp(96px, 12vw, 160px) clamp(20px, 4vw, 56px)"
  window-light:
    backgroundColor: "{colors.mat-light}"
    textColor: "{colors.ink}"
    rounded: "{rounded.window}"
    padding: "clamp(96px, 13vw, 176px) clamp(20px, 4vw, 56px)"
  notification-plate:
    backgroundColor: "{colors.plate}"
    textColor: "{colors.ink-dark-scheme}"
    rounded: "{rounded.plate}"
    padding: "14px 16px"
    width: "400px"
  recap-card:
    backgroundColor: "{colors.recap-deep}"
    textColor: "{colors.label-on-dark}"
    rounded: "{rounded.card}"
    padding: "30px"
---

# Design System: HydroBar

## Overview

**Creative North Star: "The Ring on the Desktop"**

HydroBar's web surfaces are the Mac itself, magnified. A macOS wallpaper, green at the top left and deep blue at the bottom right with soft waves, is the ground of every page. Each section is a window of frosted glass set on that desktop with a visible gap around it, the way the app's popover sits over whatever is behind it. The hero is the app itself: HydroBar's popover hangs from the ring in the site's menu bar and works (presets, Hold to Add, today's log, undo). Behind it, the menu bar ring is blown up to page scale; when the popover closes, the ring comes forward with the day's percentage.

The palette and the material are the app's, not an interpretation of it: macOS systemBlue to systemCyan for water, systemGreen to systemMint for a reached goal, a 30% gray for the unfilled track, and translucent dark or light material with a bright rim. Bricolage Grotesque gives the headlines a warm, slightly irregular voice; Instrument Sans does the explaining. Interface pieces such as notifications, preset buttons, the menu bar and the monthly recap card are recreated faithfully from the app's SwiftUI views and strings, so the page proves the product by showing it.

Density is calm: large type, generous section padding, one idea per window. Motion has two registers. The page eases: content rises in once, arcs fill, a selector's thumb slides. The recreated app moves the way the app does: its ring settles with a small spring, numbers roll, a preset flashes when hit, and reaching the goal bursts once. Both light and dark color schemes are first-class.

**Key Characteristics:**
- A fixed macOS wallpaper behind everything; every section is a glass pane over it.
- Water is blue to cyan, the goal is green to mint, the empty track is neutral gray.
- Rings, arcs and dials are the primary graphic language, from the 22px brand mark to a ring larger than the viewport.
- Real macOS interface recreated, never illustrated or described, and working wherever it can: one shared day state drives the popover, the menu bar icon, the widget and the icon's menu.
- Bricolage Grotesque headlines over Instrument Sans text, in light and dark.

## Colors

The app's own macOS system colors, set on translucent material over a blue-green desktop.

### Primary
- **Water Blue** (`water`): systemBlue. The start of every water gradient: the hero ring's arc, the 24-hour dial's active hours, unfinished month rings, the bottle's water, text selection and the scrollbar. It draws; it never carries white text.
- **Shallow Cyan** (`water-light`): systemCyan. The end of the water gradient (diagonal on rings, top-to-bottom in the bottle) and the accent on a typed amount inside a notification.
- **Action Blue** (`action`, hover `action-hover`): a deeper blue for every button that carries a white label (primary buttons, the selected segment, the hit preset), chosen so the label passes WCAG AA.
- **Water Tint** (`water-tint`, hover `water-tint-strong`): systemBlue at 25% (40% on hover), the fill of preset and bottle-mark keys on dark glass.

### Secondary
- **Goal Green** (`goal`): systemGreen. The start of the goal gradient and the solid of the goal checkmark disc, the last-call dot on the dial and the check in a met month.
- **Mint** (`goal-light`): systemMint. The end of the goal gradient on the closed ring.
- **Goal Glass** (`mat-goal`): a green-tinted dark material that replaces the story window's material when the day's ring closes.

### Neutral
- **Track Gray** (`track`): systemGray at 30%, the unfilled part of the hero ring. On light material, unfilled rings use `fill` instead.
- **Desktop Blue** (`desktop-blue`): the page background beneath the wallpaper and the middle stop of its fallback gradient.
- **Window Dark** (`mat-dark`) and **Window Deep** (`mat-deep`): dark material for the story stage, the bottle band and the close (Window Dark), and for privacy and the footer (Window Deep).
- **Window Light** (`mat-light`; `mat-light-dark-scheme` in dark mode): light material for explanatory sections.
- **Plate** (`plate`): the darker material of notification and preset plates.
- **Glass Control** (`glass-control`): white at 14%, the secondary glass button.
- **Menu Bar** (`menubar-dark`, `bar-light`, `bar-light-dark-scheme`): the near-opaque site menu bar over dark and light grounds.
- **Label on Dark** (`label-on-dark`) and **Window Secondary** (`label-on-dark-2`): primary and secondary text on dark glass. The secondary is tinted toward the windows' blue rather than a neutral gray.
- **Ink** (`ink`, `ink-2`, with `-dark-scheme` variants): primary and secondary text on light material.
- **Fill** (`fill`, `fill-dark-scheme`): systemFill, for segmented control wells, key caps, code blocks and unfilled rings on light material.
- **Hairline** (`line`, `line-dark-scheme`): 1px dividers between list rows and FAQ items.
- **Recap Blue** (`recap-deep` to `recap-bright`): the monthly recap card's gradient, the app's water card darkened for AA contrast on white text.

### Named Rules
**The Two Waters Rule.** Blue to cyan means water logged; green to mint means the goal is reached. Green appears only at a reached goal (the closed ring, the last call, a met month), never as a general success or accent color.

**The White-on-Action Rule.** systemBlue (#0a84ff) is for drawing. Any surface with a white label uses Action Blue (#0068d6, hover #005ec2).

**The Gray Track Rule.** The unfilled part of every ring is neutral gray (Track Gray on dark, Fill on light), never a pale tint of blue.

## Typography

**Display Font:** Bricolage Grotesque (self-hosted, OFL, variable 200–800), with ui-rounded and system-ui as fallbacks
**Body Font:** Instrument Sans (self-hosted, OFL, variable 400–700), with system-ui as fallback
**Code:** ui-monospace, SF Mono, Menlo, for the deep-link example only

**Character:** Bricolage brings a friendly, hand-adjusted grotesque to the big statements; Instrument Sans is plain and precise for the explanations. Neither tries to imitate the system font; the faithful macOS recreation lives in the interface plates, not in the page's type.

### Hierarchy
- **Display** (760, clamp(48px, 6.4vw, 96px), 1.02, -0.035em): the hero headline only. 40px on phones.
- **Headline** (760, clamp(38px, 5.4vw, 80px), 1.02, -0.025em): one per section window. The close uses a larger clamp(44px, 6vw, 92px).
- **Title** (680, 24px, 1.2, -0.01em): sub-items in a window. The same family at 680 sets definition terms (22px), FAQ questions (21px) and list row names (19px).
- **Numeral** (700, clamp(56px, 6vw, 92px), 0.9, -0.035em, tabular): times of day in the story, the recap total (64px), and the ring percentage, which scales with the ring at a fifth of its diameter (line height 0.86, -0.04em).
- **Lede** (400, clamp(19px, 1.6vw, 22px), 1.6): the paragraph under each headline, max 34em.
- **Body** (400, 18px, 1.6): running text, held to 28–44em.
- **Button** (650, 18px, 1): every button label; 14px in the menu bar.
- **Label** (600, 15px, 1.25): the tick's time label, meta lines, month names, menu bar items (500).

### Named Rules
**The Two Voices Rule.** Bricolage speaks (headlines, titles, questions, terms and numerals); Instrument Sans explains (body, ledes, buttons and labels). Never swap them.

**The Tabular Clock Rule.** Every number that changes in place (the clock, the percentage, litres, times) uses tabular figures so it updates without shifting.

The build's numeral stack currently names a rounded system face ahead of Bricolage. That is drift, not part of this rule: numerals are Bricolage.

## Layout

The page is a desktop with windows on it. A fixed 44px menu bar runs across the top. Below it, each section is a pane set 14px in from the viewport and from its neighbours (8px under 760px), so the wallpaper shows in every gap. Content inside a pane is held to 1240px and padded inline by clamp(20px, 4vw, 56px). Light panes breathe with clamp(96px, 13vw, 176px) of block padding; dark bands use clamp(96px, 12vw, 160px), and the close goes up to clamp(110px, 14vw, 190px).

The story is a pinned stage: a dark window 58px below the top (52px on phones), as tall as the viewport minus 72px, which stays put while about six and a half viewports of scroll move through the day. Scrolling sets a target and the display eases toward it frame by frame, so the clock and the pace ticks glide from one moment to the next instead of jumping. The popover hangs from the menu bar icon, scaled to the window's height; the big ring is centered on it and sized so its hole contains the popover. In notification moments the popover closes, the ring scales down to fit the window and shows the percentage, and the notification sits top right, where macOS puts it. Copy sits in a column of min(520px, 36vw) on the left. Under 760px the popover moves to the bottom of the window and the notification below the ring.

Inside panes, content is two columns with a clamp(40px, 6vw, 96px) gap, collapsing to one column at 900px (860px or 760px for some grids). Feature lists are rows divided by hairlines rather than grids of cards. Twelve month rings sit in a 12-column row, wrapping to 6 under 760px.

Breakpoints: 560px, 760px, 860px, 900px.

## Elevation & Depth

Depth is material, not shadow stacking. A single raster wallpaper (2560×1600, rendered from an authored SVG; a CSS gradient from #6aa98f through #3f86a6 and #3060c0 to #22389e stands in while it loads) is fixed behind everything. Every pane shows that wallpaper blurred and saturated (`blur(28px) saturate(170%)`) under its material tint, so the waves and colors move through it as the page scrolls. The blur is not computed live: `wallpaper-blur.jpg` is the wallpaper blurred once, drawn on a fixed layer that each pane reveals through a rounded `clip-path` (`.pane > .glass`). The result is the same picture as a backdrop filter, without re-blurring a window-sized area on every scroll frame. Live `backdrop-filter` is kept for small surfaces over moving content: the popover, notifications, the widget and the menu. Each glass pane carries a rim: a bright 1px top highlight, a 1px inner hairline and one wide soft drop.

A **desk** (`.desk`) is the opposite cut: an opening in a pane that shows the sharp wallpaper, where app interface is set down as it would be on the desktop.

### Shadow Vocabulary
- **Rim, dark glass** (`inset 0 1px 0 rgba(255,255,255,.26), inset 0 0 0 1px rgba(255,255,255,.12), 0 24px 60px rgba(0,0,0,.22)`): every dark pane and the story stage.
- **Rim, light glass** (`inset 0 1px 0 rgba(255,255,255,.9), inset 0 0 0 1px rgba(255,255,255,.55), 0 24px 60px rgba(0,0,0,.14)`): light panes. In dark mode, light panes take the dark rim.
- **Plate** (`0 18px 40px rgba(0,0,0,.26), inset 0 1px 0 rgba(255,255,255,.2), inset 0 0 0 1px rgba(255,255,255,.12)`): notification and preset plates.
- **Card** (`0 24px 50px rgba(0,0,0,.14)`): the opaque recap card.
- **Pressed segment** (`0 2px 6px rgba(0,0,0,.14)`): the selected segment.
- **Glass hairline** (`inset 0 0 0 1px rgba(255,255,255,.14)` to `.22`): keys, chips and the glass button on dark material.

### Named Rules
**The Desktop Rule.** Every section is a glass window over the wallpaper, with the wallpaper visible around it. No section is an opaque, full-bleed slab.

**The Rim Rule.** Glass is never drawn without its rim: top highlight, inner hairline, soft drop.

## Shapes

Continuous, Mac-like rounding, stepped down as elements nest: windows 30px (24px on phones), the recap card 22px, plates 18px (the preset tray 16px), buttons, wells and keys 14px, segments 10px, small keys 9px, chips and focus rings 8px. Rings use round caps on their arcs; the pace tick is a 160-unit rounded bar. The bottle is a rounded silhouette (44-unit body corners, 10-unit cap) clipped around its water. Borders are inner hairlines (inset box-shadows), never outer strokes, except the 1px rules between list rows.

## Components

### Buttons
Solid, Mac-sized and calm.
- **Shape:** gently rounded (14px), 56px tall, 28px side padding.
- **Primary:** Action Blue with a white Button label. Hover darkens to the hover blue and lifts 1px; active presses 1px down; 0.2s on the standard ease.
- **Glass (secondary on dark):** white at 14% with a 22% inner hairline and the glass blur.
- **Unavailable:** transparent with a 1.5px white inner outline at 60%, no lift, default cursor.
- **Menu bar:** the primary at 32px tall, 9px corners, 14px label.
- **Text link with arrow:** 600 weight, no underline; the arrow drops 3px on hover.
- **Focus (all):** a 3px outline in the current text color, 4px offset, 8px corners.

### Segmented control
A systemFill well (14px corners, 5px padding) holding text buttons in Instrument Sans 650 16px. The selected segment fills with Action Blue, white text and the pressed-segment shadow.

### Keys (presets and bottle marks)
Water Tint fill with a white inner hairline at 14%. Bottle marks are 60px tall with 22px numerals; presets are smaller (9px corners). Hover deepens the tint; a used mark goes to white at 10% with secondary text. A preset that was just hit fills with Action Blue.

### Windows (cards / containers)
- **Corner Style:** 30px (24px under 760px).
- **Background:** Window Dark, Window Deep or Window Light material, blurred.
- **Shadow Strategy:** the dark or light rim (see Elevation & Depth).
- **Internal Padding:** section-inline sideways, section-block or band-block vertically.

### Navigation (menu bar)
A 44px bar fixed to the top: the app icon and "HydroBar" in Bricolage 760 17px, text links in Instrument Sans 500 15px (underlined on hover), then a mini ring in a 30×24px well, a tabular clock and the menu-bar button. It is dark glass over dark panes and turns into the light bar with a hairline under it when a light pane is beneath it. Under 900px the links and clock are hidden.

### Notification plate (signature)
A faithful macOS notification: 400px wide, Plate material with the plate shadow, 18px corners, a 38px app icon, a bold 14px title, a 14px body, a 12px "now", and action chips (white at 12%, 8px corners) carrying the user's presets. Its type follows the Mac's own system text face (falling back to Instrument Sans) because it reproduces macOS.

### The app popover (signature)
HydroBar's popover at its real 320px, scaled with `zoom`: dark glass with the plate rim, a header with the chart and gear icons, the 180px ring (12px stroke, pace tick, percentage, amounts, pace caption), the day chip, three preset keys, the Hold to Add button, today's log and Reset my day. Its type is the Mac's system face. In the hero it is live; the chart icon switches it to Statistics. The Statistics view (two tiles, the monthly recap card, twelve year bars with the goal line, the streak) is also shown on a desk in the Progress section.

### The ring (signature)
A thick-stroked circle: Track Gray underneath, a round-capped water-gradient arc on top, a light pace tick, and the Numeral percentage in the middle. At the goal the arc switches to the goal gradient, the window takes a green tint and a green check disc appears; past 100% a second, darker lap starts. The same anatomy scales from the 18px menu bar mini ring to the popover, the widget, the dial and the page-scale ring behind the popover.

### Mac App Store badge
A black, 14px-rounded badge with the Apple mark, a small line and "Mac App Store". While the listing is not live it reads "Coming soon to the" and is not a link; setting `APP_STORE_URL` turns it into "Download on the" and links it. At launch, replace it with Apple's official badge artwork.

### Recap card
The app's monthly recap card: the Recap Blue gradient at 135°, 22px corners, 30px padding, a 64px Numeral total and white text at 88% for secondary lines.

## Do's and Don'ts

### Do:
- **Do** set every section as a glass pane over the wallpaper: 14px gaps (8px under 760px), 30px corners (24px), the matching rim, and the pre-blurred fixed layer (`.pane` with a `.glass` child).
- **Do** keep anything that holds a `.glass` or a `.desk` free of `transform`, `filter` and `backdrop-filter` on itself and its ancestors: they would capture the fixed layer.
- **Do** use dark material for the story, the bottle band, privacy, the close and the footer, and light material for explanatory sections; in dark mode the light material becomes rgba(36, 38, 46, .7) with the dark rim.
- **Do** recreate macOS interface from the app's own views and strings (notifications, presets, menu bar, recap card) instead of illustrating it.
- **Do** let the site menu bar follow the ground beneath it: dark glass over dark panes, the light bar over light panes.
- **Do** ease the page's transitions with cubic-bezier(.16, 1, .3, 1): 0.2s for buttons, 0.45–0.9s for content, around 1s for arcs.
- **Do** give every control an answer to hover, press and focus, and make recreated interface respond like the app.
- **Do** collapse every transition to 0.01ms under Reduce Motion, so the day reads as discrete stops.

### Don't:
- **Don't** put white text on systemBlue (#0a84ff); use Action Blue (#0068d6).
- **Don't** use green for anything other than a reached goal.
- **Don't** tint a ring's empty track blue; it stays Track Gray or Fill.
- **Don't** replace the raster wallpaper with a flat color or a plain CSS gradient: the glass needs its soft forms to act on. The gradient is only a loading fallback.
- **Don't** lay features out as a row of equal cards; use hairline-divided rows inside a pane.
- **Don't** put a live `backdrop-filter` on a pane-sized surface: that is what made scrolling stutter.
- **Don't** spring the page itself. The small overshoot (`--spring`) belongs to the recreated app: its ring, its checkmark, a key being pressed.
