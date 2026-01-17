Global rules

Coordinate spaces
	•	Compute all geometry in world space (bounds, indicator rect).
	•	Convert to view space only at paint time.
	•	All stroke widths / blur radii are in screen px, so they should be constant regardless of zoom.
	•	i.e. when you draw in world space, divide px values by zoom to get world units.

Pixel snapping

Figma lines feel crisp because they snap to device pixels.
	•	For 1px lines: align to half-pixel in view space.
	•	Rule: when you compute the indicator rect in view space, snap its top/left to floor(x)+0.5 when thickness is odd pixels.

Theme colors (token names)

Use your design system equivalents; below are semantic names:
	•	accent = primary blue
	•	accentAlpha = accent with opacity applied
	•	fgSecondary = secondary text color (neutral)
	•	borderSubtle = subtle outline color
	•	shadow = black

⸻

1) Drag Ghost (the “preview” of the dragged node)

Base ghost container
	•	Opacity (valid): 0.90
	•	Opacity (invalid): 0.55
	•	Saturation (invalid): 0.0–0.2 (desaturate slightly)
	•	Scale: 1.00 (don’t scale; Figma doesn’t scale the object)
	•	Corner radius: same as original node (do not change)

Shadow (valid)

Two-layer shadow, Figma-like:
	•	Shadow A: y=4px, blur=12px, spread=0, alpha=0.18
	•	Shadow B: y=1px, blur=3px, spread=0, alpha=0.12

Shadow (invalid)
	•	Keep shadows but reduce alpha by ~40%:
	•	A alpha 0.10
	•	B alpha 0.07

Optional “lift” outline (nice touch)
	•	1px outline: borderSubtle @ 20%
	•	Only if your dragged node has no border; otherwise skip to avoid double-border.

Multi-select ghost (v1 optional)

Stack effect (looks great and is cheap):
	•	Render 2 “behind” cards:
	•	Offset: (2px, 2px) and (4px, 4px) in screen px
	•	Opacity: 0.35 and 0.20
	•	No shadows on the behind cards (or super subtle)
	•	Top card is the actual ghost.

⸻

2) Insertion Indicator Line

This is the most important visual. It should be unmistakable but not loud.

Geometry
	•	For vertical auto-layout (Column): draw a horizontal line across the parent content box.
	•	For horizontal auto-layout (Row): draw a vertical line across the parent content box.
	•	Line should be inside padding (content box).
	•	Thickness in screen px: 2px.

Color
	•	Valid indicator: accent @ 100%
	•	Invalid: no indicator (v1), OR show accent @ 30% + dashed (but I recommend: none).

End caps

Figma-ish caps:
	•	Line cap: round
	•	Optional: small end “nubs”:
	•	Add 4px radius circles at each end (screen px), same color.
	•	This feels very Figma.

Glow (subtle)

Add a soft outer glow to pop against busy UIs:
	•	Glow blur: 8px
	•	Glow alpha: 0.25
	•	Glow color: accent

Exact paint order
	1.	Glow (blurred stroke)
	2.	Main 2px line
	3.	End nubs (if using)

Clipping
	•	Clip to parent content rect (post-padding).
	•	If clipping makes the line < 6px long, treat as invalid (“container too small”).

⸻

3) Drop Zone Highlight (target parent)

When valid drop, highlight the parent container subtly.

Outline
	•	Stroke: 1px (screen px)
	•	Color: accent @ 60%
	•	Radius: parent radius (or 6px default)
	•	Draw inside the parent bounds (inset 0.5px) to avoid bleed.

Fill (optional)

Very subtle fill helps readability:
	•	Fill: accent @ 6%
	•	Only when the container is large enough; otherwise outline only.

Animated fade
	•	Fade in/out duration: 80–120ms (fast)
	•	No bouncy animation; keep it “tool-like”.

⸻

4) Drop Slots (optional v1 visual)

Figma often shows only the line, but you can add slot affordance if you want.

Slot overlay (only when hovering inside target parent)
	•	Draw a very subtle “slot band” behind where the indicator is:
	•	Height (for vertical): 8px
	•	Width: full content width
	•	Color: accent @ 4%
	•	This makes it easier to see placement without being noisy.

⸻

5) Invalid target feedback

Keep v1 simple and consistent:

Ghost styling
	•	Opacity 0.55
	•	Desaturate slightly
	•	Cursor: show “not allowed” (if you support it)

Target highlight
	•	None (don’t highlight invalid containers)
	•	No indicator line

Optional invalid reason tooltip (debug only)
	•	Only in debug mode: show small label near cursor:
	•	Background: #111 @ 85%
	•	Text: white @ 90%
	•	Radius: 6px
	•	Padding: 8x6
	•	Font size: 12

⸻

6) Zoom handling (critical)

Here’s the exact rule so you don’t accidentally scale widths:

Let zoom = world→view scale factor.

For any screen-px dimension p:
	•	worldUnits = p / zoom

So:
	•	indicator thickness world = 2 / zoom
	•	outline thickness world = 1 / zoom
	•	glow blur world = 8 / zoom
	•	end nub radius world = 4 / zoom

This ensures the line looks identical at any zoom.

⸻

7) Absolute positioning handling (v1 “do not allow”)

Your spec already says:
	•	v1 never drops into absolute/stack containers.

Here’s how to make that not interfere:

Rules
	1.	If hit target is absolute container:
	•	climb to nearest auto-layout ancestor (expandedParent chain).
	2.	If none found:
	•	invalid, show ghost invalid state, no indicator.
	3.	You should still allow reordering within an auto-layout even if cursor is over an absolute-positioned child overlay, because climbing will land on the auto-layout parent.

Visual
	•	Highlight the climbed-to auto-layout parent (not the absolute container).
	•	Indicator computed within that parent’s content box.

⸻

8) Quick “token sheet” you can drop into code

Indicator
	•	thickness: 2px
	•	color: accent 1.0
	•	glow blur: 8px
	•	glow alpha: 0.25
	•	nub radius: 4px (optional)

Drop highlight
	•	stroke: 1px
	•	stroke alpha: 0.60
	•	fill alpha: 0.06 (optional)

Ghost
	•	valid opacity: 0.90
	•	invalid opacity: 0.55
	•	shadow A: y4 blur12 a0.18
	•	shadow B: y1 blur3 a0.12

