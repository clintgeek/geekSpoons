# Retro Winamp-Inspired UI Design Specification

## 1. Overall Design Language

Create a compact, dense, highly tactile desktop interface inspired by late-1990s PC media players and audio hardware.

The aesthetic should feel:

- Late 1990s / early 2000s Windows desktop software
- Skeuomorphic rather than flat
- Dark, almost-black industrial chassis
- Brushed-metal/chrome controls
- Amber/gold decorative accents
- Phosphor-green LCD/terminal-style displays
- Pixel-perfect, hard-edged geometry
- Dense information presentation
- Strong 3D bevels
- Minimal rounded corners
- High contrast
- Slightly crude by modern UI standards
- Functional rather than decorative
- Nostalgic without becoming cartoonish

Do not modernize the aesthetic.

Avoid:

- Material Design
- Glassmorphism
- Excessive rounded corners
- Soft shadows
- Huge whitespace
- Minimalist SaaS styling
- Modern floating cards
- Contemporary thin-line iconography

The interface should look like software designed when every pixel had to earn its keep.

---

## 2. Canvas and Aspect Ratio

Reference image:

- Canvas: 880 × 412 px
- Overall aspect ratio: approximately 2.14:1
- Wide, short horizontal silhouette
- Major components arranged horizontally
- High information density

For responsive implementations, preserve approximately:

```css
aspect-ratio: 2.14 / 1;
```

Conceptual layout:

```text
+-----------------------------------------------------------+
| menu      gold accent       TITLE       gold accent       |
+-----------------------------------------------------------+
|                                                           |
| +------------+   +-------------------------------------+ |
| | LCD /      |   | TRACK / STATUS DISPLAY              | |
| | VISUALIZER |   +-------------------------------------+ |
| |            |   +-------------------------------------+ |
| |            |   | metadata / sliders / controls       | |
| +------------+   +-------------------------------------+ |
|                                                           |
|             -------- recessed groove --------             |
|                                                           |
| [PREV] [PLAY] [PAUSE] [STOP] [NEXT] [EJECT] [SHUFFLE]   |
|                                              [REPEAT]     |
+-----------------------------------------------------------+
```

---

## 3. Outer Chassis

The entire application is contained inside a dark, physical-looking chassis.

Primary colors:

```css
--black:       #07090b;
--deep-black:  #0b0d10;
--panel:       #15191d;
--panel-dark:  #101317;
--border:      #30363a;
--highlight:   #555c60;
```

Do not use pure black everywhere. Use subtle variations between chassis, panels, recesses, and display areas.

Use layered borders and inset highlights instead of modern floating shadows.

Example:

```css
.player {
    background: #101317;
    border: 2px solid #30363a;
    box-shadow:
        inset 0 1px 0 #555c60,
        inset 0 -2px 0 #050607,
        0 2px 4px rgba(0, 0, 0, 0.7);
}
```

Corners should be extremely tight:

```css
border-radius: 3px;
```

Never use large modern radii such as 12px, 16px, or 24px.

---

## 4. Header

The header occupies approximately 15–18% of the interface height.

It should resemble a narrow piece of industrial electronic equipment.

Layout:

- Small menu button at left
- Decorative amber/gold horizontal strip
- Centered product/application title
- Decorative amber/gold strip
- Minimize button
- Maximize button
- Close button

The title should be visually centered independently of the window-control buttons.

---

## 5. Gold / Amber Accent System

Use muted amber/brass rather than bright yellow.

Palette:

```css
--amber-dark:   #705522;
--amber:        #b38a3b;
--amber-light:  #d4ad5c;
--amber-pale:   #e0bd73;
```

The gold should resemble aged brass, anodized metal, or old electronic equipment trim.

Horizontal accent bars should have multiple tonal layers:

1. Dark outline
2. Gold edge
3. Bright gold center
4. Dark lower edge

Example:

```css
.accent-bar {
    height: 7px;
    background:
        linear-gradient(
            to bottom,
            #604819 0%,
            #c49a48 20%,
            #e2bd70 45%,
            #b1863b 65%,
            #604819 100%
        );
    border-top: 1px solid #2d2415;
    border-bottom: 1px solid #18130b;
}
```

The gradient should feel like physical trim, not a modern decorative gradient.

---

## 6. Typography

Use two distinct typography systems.

### 6.1 Normal UI Typography

Use a condensed, utilitarian sans-serif.

Preferred choices:

- Arial Narrow
- Roboto Condensed
- Liberation Sans Narrow
- Similar condensed sans-serif

Example:

```css
font-family:
    "Arial Narrow",
    "Roboto Condensed",
    "Liberation Sans Narrow",
    sans-serif;
```

Main title:

```css
font-weight: 700;
letter-spacing: 1px;
text-transform: uppercase;
color: #e2e5e7;
```

The title should resemble software branding from the late 1990s rather than a modern website heading.

### 6.2 LCD / Display Typography

Electronic readouts should use a narrow monospaced pixel/bitmap-style font.

Characteristics:

- Monospaced
- Squared glyphs
- Narrow strokes
- Pixel-like appearance
- Uppercase
- Minimal antialiasing
- Bright phosphor green

Good modern substitutes:

- VT323
- Share Tech Mono
- A custom bitmap font

VT323 or a similar narrow terminal font is preferable to chunky arcade fonts.

Example:

```css
font-family: "VT323", monospace;
font-weight: 400;
letter-spacing: 1px;
```

LCD colors:

```css
--lcd-green:       #67ff45;
--lcd-green-dark:  #1b6f19;
--lcd-green-dim:   #326e2b;
```

Subtle glow:

```css
text-shadow: 0 0 2px rgba(90, 255, 50, 0.45);
```

Do not make this cyberpunk neon. The glow should be restrained.

---

## 7. LCD Display Panels

LCD areas should be nearly black.

```css
background: #050805;
```

Use thin dark-green/gray borders.

Example:

```css
.lcd {
    background: #030603;
    border: 1px solid #222a24;
    box-shadow:
        inset 0 0 0 1px #080d09,
        inset 0 2px 6px rgba(0, 0, 0, 0.9);
    color: #67ff45;
    font-family: "VT323", monospace;
}
```

The visual hierarchy should be:

Dark chassis → darker LCD → bright green information.

---

## 8. Visualizer

The audio visualizer should consist of discrete rectangular vertical bars.

Do not use a smooth waveform.

Use small hard-edged blocks separated by approximately 2–4px.

Example:

```text
      ##
      ##
    ####
    ######
  ########
  ########
############
############
```

Bars should vary in height.

Suggested colors:

```css
#286d21
#53c83c
#8ee33e
#c7d83c
```

Use darker greens for lower portions and brighter yellow-green tones toward higher/intense portions.

Characteristics:

- Hard edges
- Rectangular bars
- No rounded corners
- No blur
- No soft glow
- No smooth waveform

Animation, if used, should feel like an old hardware spectrum analyzer.

---

## 9. Main Track Display

The track/title display is a long horizontal LCD strip.

It should occupy roughly 60% of the width of the upper information area.

Background:

```css
background: #050805;
```

Border:

```css
border: 1px solid #29312a;
```

Typography:

```css
color: #66ff43;
font-family: "VT323", monospace;
font-size: clamp(18px, 2vw, 28px);
text-transform: uppercase;
white-space: nowrap;
overflow: hidden;
```

Text can scroll or clip when it exceeds the display width.

It should look like a hardware LCD track display rather than a normal webpage label.

---

## 10. Digital Time Counter

The elapsed-time display should use:

- Large pixel-style digits
- Bright phosphor green
- Monospaced typography
- Tight spacing
- Strong visual prominence

Example:

```css
.time {
    font-family: "VT323", monospace;
    font-size: 64px;
    line-height: 0.8;
    color: #6cff47;
    letter-spacing: 2px;
    text-shadow: 0 0 3px rgba(80, 255, 50, 0.35);
}
```

The digits should evoke an old alarm clock, calculator, or digital stereo display.

Seven-segment styling is acceptable but not mandatory.

---

## 11. Metadata Readouts

Technical information such as:

```text
192 kbps
44 kHz
mono
stereo
```

should use the LCD/pixel typography.

Numeric values may be placed inside tiny recessed dark boxes.

Example:

```css
.value {
    background: #030503;
    border: 1px solid #172019;
    padding: 2px 5px;
    color: #6bff49;
    font-family: "VT323", monospace;
}
```

Units can use gray:

```css
.unit {
    color: #b8bcbf;
}
```

Active states such as `stereo` should be green.

Inactive states should be gray.

---

## 12. Sliders

Sliders should resemble physical recessed controls.

Do not use modern browser-style sliders.

The track should be a narrow horizontal groove.

Conceptually:

```text
+------------------------------+
|###############|              |
+------------------------------+
                ^
              handle
```

Track:

```css
.slider-track {
    height: 10px;
    background: #090b0c;
    border: 1px solid #373d40;
    box-shadow:
        inset 0 2px 3px rgba(0, 0, 0, 0.9),
        inset 0 -1px 0 #555;
}
```

The active portion may use amber:

```css
background:
    linear-gradient(
        to bottom,
        #9a5c12,
        #f0a52c,
        #bd7017
    );
```

---

## 13. Slider Knobs

Slider knobs should look like chunky physical metal fader caps.

Approximate size:

```css
width: 28px;
height: 22px;
```

Metallic appearance:

```css
background:
    linear-gradient(
        to bottom,
        #e2e4e3 0%,
        #aeb3b4 20%,
        #6c7173 50%,
        #d0d3d3 75%,
        #777b7c 100%
    );
```

Add:

- Dark outline
- Top highlight
- Bottom shadow
- Dark central slot or line

---

## 14. Buttons

Buttons are one of the defining characteristics of the design.

They should be small, rectangular, three-dimensional metal controls with strong bevels.

They should look like physical objects that can be pressed.

Conceptually:

```text
      light top edge
+----------------------+
|                      |
|        ICON          |
|                      |
+----------------------+
      dark bottom edge
```

Button palette:

```css
--button-face:   #aeb2b3;
--button-light:  #e4e7e7;
--button-mid:    #8a8f91;
--button-dark:   #414648;
--button-shadow: #17191a;
```

Example:

```css
.button {
    background:
        linear-gradient(
            to bottom,
            #e0e3e3 0%,
            #aeb2b3 25%,
            #8b9091 65%,
            #c7caca 100%
        );

    border: 1px solid #25292b;

    box-shadow:
        inset 1px 1px 0 #f1f3f3,
        inset -1px -1px 0 #3c4041,
        2px 2px 0 #080909;

    color: #202426;
}
```

---

## 15. Button Geometry

Buttons should have chamfered/beveled silhouettes rather than ordinary rounded rectangles.

Use `clip-path` if appropriate:

```css
clip-path: polygon(
    6px 0,
    calc(100% - 6px) 0,
    100% 6px,
    100% calc(100% - 6px),
    calc(100% - 6px) 100%,
    6px 100%,
    0 calc(100% - 6px),
    0 6px
);
```

This creates a machined, hardware-like appearance.

Do not rely on `border-radius` as the primary button treatment.

---

## 16. Button Icons

Use extremely simple geometric icons:

- Previous
- Play
- Pause
- Stop
- Next
- Eject
- Shuffle
- Repeat
- Speaker

Icons should resemble old bitmap UI glyphs.

Characteristics:

- Geometric
- Thick
- Monochrome
- Centered
- Dark gray
- Approximately 16–24px

Avoid thin-line modern icon sets such as typical Lucide-style icons.

For example, a play icon can be a simple triangle:

```css
clip-path: polygon(
    25% 15%,
    80% 50%,
    25% 85%
);
```

---

## 17. Button States

### Normal

Metallic gray face with strong beveling.

### Hover

Slightly brighter:

```css
filter: brightness(1.08);
```

### Pressed

Reverse the bevel so the control appears physically depressed:

```css
box-shadow:
    inset 2px 2px 3px rgba(0, 0, 0, 0.6),
    inset -1px -1px 0 #d0d3d3;
```

Move the button slightly:

```css
transform: translate(1px, 1px);
```

Do not use modern scale-based button animations.

---

## 18. Secondary Buttons

Controls such as:

- EQ
- PL
- Shuffle
- Repeat

should be smaller rectangular metallic buttons.

They use the same metal/bevel treatment but with less dramatic geometry.

Labels should be dark gray or nearly black.

Example:

```css
font-family: Arial, sans-serif;
font-size: 13px;
font-weight: bold;
```

---

## 19. Separator / Recessed Groove

Between the main information area and the playback controls should be a long recessed horizontal slot.

It should appear physically cut into the chassis.

Example:

```css
.separator {
    height: 10px;
    background: #0a0c0d;
    border-top: 1px solid #3d4245;
    border-bottom: 1px solid #050607;
    box-shadow:
        inset 0 2px 3px rgba(0, 0, 0, 0.8);
}
```

A small centered metallic tab may sit within or over the groove.

The tab should use the amber/brass palette.

---

## 20. Chassis Borders

Use multiple nested edges.

Visual hierarchy:

```text
OUTER BLACK
    ↓
DARK GRAY BORDER
    ↓
LIGHT GRAY HIGHLIGHT
    ↓
DARK INNER BORDER
    ↓
BLACK PANEL
```

Example:

```css
.panel {
    border: 1px solid #34393c;

    box-shadow:
        inset 0 1px 0 #666b6d,
        inset 0 -1px 0 #050606,
        0 1px 0 #000;
}
```

---

## 21. Color Palette

### Chassis

```text
#050607  deepest black
#090b0d  black
#101316  primary chassis
#171b1f  panel
#252a2d  dark border
#3a4043  medium border
#5b6164  highlight
```

### Metal

```text
#3f4446
#686d6f
#898e90
#aeb2b3
#d3d6d6
#e7e9e9
```

### Amber

```text
#604719
#81632b
#a77e36
#c29a4d
#ddb96b
```

### LCD Green

```text
#174d18
#286d25
#3c9d2d
#59d63b
#69ff48
```

### Display Black

```text
#020402
#050805
#080c08
```

---

## 22. Lighting Philosophy

All physical-looking components should share the same directional lighting.

Assume the primary light source comes from the top-left.

Therefore:

- Top edges are lighter
- Left edges are lighter
- Bottom edges are darker
- Right edges are darker

This consistency is critical.

Do not independently invent different shadow directions for different components.

---

## 23. Shadows

Use hard, compact shadows.

Good:

```css
box-shadow: 2px 2px 0 #050505;
```

Good:

```css
box-shadow:
    inset 1px 1px 0 #eee,
    inset -1px -1px 0 #333;
```

Avoid huge soft shadows such as:

```css
box-shadow: 0 15px 40px rgba(...);
```

The original design language predates large soft web-style shadows.

---

## 24. Texture

A very subtle texture can be used on chassis and metal surfaces.

Example:

```css
background-image:
    repeating-linear-gradient(
        0deg,
        rgba(255, 255, 255, 0.015) 0,
        rgba(255, 255, 255, 0.015) 1px,
        transparent 1px,
        transparent 3px
    );
```

Keep this nearly invisible.

The interface should not look like it is made from a giant sheet of brushed steel.

---

## 25. Pixel Fidelity

The design should intentionally embrace pixel-era rendering.

For bitmap assets:

```css
image-rendering: pixelated;
```

Avoid:

- Excessive antialiasing
- Hairline SVG icons
- Smooth rounded controls
- Floating cards
- Excessive whitespace
- Giant typography
- Modern dashboard conventions
- Soft, diffuse shadows

Borders should generally use 1px or 2px increments.

Favor spacing values such as:

```text
4px
6px
8px
10px
12px
16px
```

Avoid excessive fractional spacing.

---

## 26. Component Density

The UI should feel packed.

There should be relatively little empty space.

Controls should sit close together while maintaining clear grouping.

Visual hierarchy should primarily come from:

1. Brightness
2. Borders
3. Bevels
4. Color
5. Typography

Do not rely on large amounts of whitespace to establish hierarchy.

---

## 27. CSS Architecture

Separate the visual language into reusable primitives.

Example design tokens:

```css
:root {
    --chassis: #101316;
    --panel: #171b1f;
    --black: #050607;

    --metal-dark: #414648;
    --metal: #aeb2b3;
    --metal-light: #e4e7e7;

    --amber: #b38a3b;
    --amber-light: #d4ad5c;

    --lcd: #050805;
    --green: #67ff45;
}
```

Useful reusable components:

```text
.player
.panel
.lcd
.lcd-text
.metal-button
.metal-slider
.accent-bar
.recessed-slot
.digital-display
.visualizer
```

The overall aesthetic should come from these reusable primitives rather than independently styling every component.

---

## 28. What Makes the Design Feel Authentic

The following characteristics are more important than any individual CSS value.

### 1. Hard geometry

Everything should be rectangular, chamfered, beveled, or mechanically recessed.

### 2. Physical controls

Buttons should look like objects you could physically press.

### 3. High information density

Pack a lot of small information into a relatively small surface.

### 4. Limited palette

Almost everything should be black, gray, silver, amber, or phosphor green.

### 5. Pixel typography

LCD information should look electronic rather than web-based.

### 6. Directional lighting

Every bevel should follow the same top-left light source.

### 7. No modern UI conventions

Avoid:

- Cards
- Pills
- Floating panels
- Excessive whitespace
- Giant icons
- Soft rounded surfaces
- Glass effects

### 8. Fake hardware

The UI should feel like a physical stereo component translated directly into software.

### 9. Controlled imperfection

It should be slightly chunky, slightly cramped, and slightly over-designed.

Do not clean it up until it resembles a 2026 product dashboard.

### 10. Contrast between technologies

The chassis should look like dark plastic/metal.

Controls should look like machined metal.

Accents should look like brass.

Displays should look like green phosphor electronics.

---

# One-Paragraph AI Generation Prompt

Design a compact late-1990s/early-2000s desktop audio-player interface with a wide approximately 2.14:1 aspect ratio. Use a nearly black industrial plastic/metal chassis with layered 1–2px gray borders, inset grooves, hard shadows, and top-left directional bevel lighting. Use dark charcoal panels, brushed-looking silver/chrome rectangular controls, muted brass/amber horizontal accent bars, and phosphor-green monochrome LCD displays. Typography should combine bold condensed sans-serif for branding and small labels with a narrow monospaced bitmap/pixel font for all electronic readouts. LCD panels should be nearly black with bright green pixelated text and restrained phosphor glow. Include dense technical metadata, large digital time digits, a block-based green audio spectrum visualizer, horizontal recessed sliders with chunky metallic fader caps, and compact beveled playback buttons using simple geometric bitmap-style icons. Buttons should have aggressive chamfered corners, bright top-left bevel highlights, dark bottom-right bevels, and a pressed state that reverses the bevel. Keep corners extremely tight. Avoid modern rounded cards, glass, soft shadows, excessive whitespace, Material Design, minimalist SaaS styling, or contemporary iconography. The result should feel like physical late-90s PC audio hardware rendered as a dense desktop application: dark, mechanical, tactile, pixel-perfect, information-dense, slightly chunky, nostalgic but technically polished.