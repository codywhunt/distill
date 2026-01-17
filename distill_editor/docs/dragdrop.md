Core invariants (must always be true)

1) One authoritative “drop preview” per pointer move

On every drag update, you must be able to compute a single object like:
	•	intent: reorder | reparent | insertIntoEmpty | noDrop
	•	frameId
	•	draggedDocIds + draggedExpandedIds
	•	targetParentDocId
	•	targetParentExpandedId (the one you’re actually hovering in)
	•	targetChildrenExpandedIds (filtered + ordered)
	•	insertionIndex (0..N)
	•	indicatorWorldRect
	•	reflowOffsetsByExpandedId (only for affected siblings)
	•	reasonIfInvalid (for debugging + UX)

Nothing else should be derived elsewhere (overlay shouldn’t “search”, renderer shouldn’t “guess”, etc.).

2) ID domains are never mixed
	•	Patching (document edits) happens in doc IDs.
	•	Hit testing + bounds + rendering transforms happen in expanded IDs.

So you always need:
	•	expandedId -> docId? (patchTarget)
	•	docId -> expandedIds[] (reverse map)
	•	“which expandedId am I hovering over right now?” (cursor containment)

3) Deterministic target selection

Given the same pointer position + scene state, you must always pick the same:
	•	hovered container
	•	insertion slot
	•	indicator rect
	•	reflow offsets

No “first match in map iteration”, no scanning without tie-breakers.

⸻

Supported user intents (what the system must decide)

On every update you decide one:
	1.	Reorder among siblings
Same parent, same frame, insertion index changes.
	2.	Reparent into another container
Different parent, insertion index within that new parent.
	3.	Move to be sibling of current parent
Reparent to parent’s parent (common when hovering outside).
	4.	Drop into empty container
Parent has 0 eligible children.
	5.	No drop
Invalid due to rules, constraints, mixed frames, unpatchable targets, etc.

⸻

Target selection rules (hit testing → what container is eligible)

A) Which frame is “active”?
	•	If you support multi-frame canvases: pointer must map to exactly one frame.
	•	If dragged selection spans multiple frames: usually disallow reparent/reorder (or only allow move as a group to another frame, but that’s a bigger feature).

B) Which container is “hovered”?

Rules should be explicit:
	•	Only consider containers that are drop-capable:
	•	node type: box/row/column (or equivalent)
	•	not locked
	•	visible
	•	not within excluded subtree
	•	passes canAcceptChildren (capability rule)
	•	Prefer the deepest container containing the cursor
	•	Tie-breakers when multiple candidates map to same docId:
	•	pick the expandedId whose bounds contains cursor
	•	if multiple: pick smallest area (deepest visual)
	•	if still multiple: pick highest z-order

C) Exclusions (“see-through”)

When dragging nodes, the hit test must ignore:
	•	the dragged nodes’ own visual bounds (and optionally their subtree)
	•	“drag ghost / overlay” layers

Otherwise you’ll always hit the dragged node itself and never the true parent.

⸻

Drop validity rules (can we drop here?)

These rules decide whether we produce a DropPreview or NoDrop.

1) Can all dragged nodes be moved as a set?
	•	all dragged nodes have a docId (patchable)
	•	none are locked
	•	selection doesn’t include ancestor + descendant simultaneously (or you normalize it)
	•	optional: maintain selection ordering rules (for bundles)

2) Parent eligibility
	•	target parent exists in doc model
	•	target parent is a container
	•	parent allows children (some nodes might be leaf-only)
	•	parent is patchable or supports “overrides” (instances)
	•	critical: if inside an instance and your system can’t patch order there → disallow reorder/reparent within it

3) Structural constraints

Disallow:
	•	dropping a node into itself
	•	dropping into its own descendant
	•	creating cycles
	•	violating type rules (e.g., text can’t contain children, etc.)

4) Layout constraints

Depends on your model, but typical:
	•	auto-layout containers accept insertion at index
	•	absolute containers might support:
	•	reparent with absolute position preserved
	•	or reparent as last child + set x/y
	•	some containers may forbid mixing absolute & auto children

5) Frame constraints

If frame is the root scope:
	•	disallow moving nodes across frames unless explicitly supported

⸻

Insertion index rules (how we compute the slot)

This is the heart of “reorder among siblings”.

Inputs required
	•	hovered parent expanded bounds
	•	list of eligible children in visual order
	•	cursor position (frame-local or world)
	•	layout direction (horizontal/vertical)
	•	padding + gap
	•	alignment rules (start/center/etc.) if they affect child positioning

Output
	•	insertionIndex in 0..N

Algorithm expectations
	•	If cursor is before first child midpoint → index 0
	•	Between child i and i+1 → index i+1
	•	After last child midpoint → index N
	•	If no children → index 0 (inside padding)

Hysteresis (must-have feel rule)

To avoid flip-flop:
	•	If previous index exists, require cursor to move past boundary by ε (8px/zoom is fine)
	•	Separate thresholds for:
	•	changing index
	•	switching parent container (optional but very nice)

Filtered children list must be used everywhere

Children used for:
	•	insertion index
	•	indicator placement
	•	reflow offsets
must be the same list (same IDs, same order).

⸻

Indicator rules (visual feedback must match intent)

What it must represent
	•	The exact final insertion slot
	•	In the correct coordinate space (world)
	•	Clipped to parent (usually)

Where it draws
	•	For horizontal layout: vertical line between items
	•	For vertical layout: horizontal line
	•	For empty container: line at padding start
	•	For absolute parent: either
	•	no indicator (if you don’t support ordering)
	•	or show “drop outline” instead of an insertion line

It must never depend on scanning mappings

Overlay must use the already-computed DropPreview.indicatorWorldRect.

⸻

Reflow / sibling animation rules (preview of what will happen)

When to apply reflow offsets

Only when intent is:
	•	reorder among siblings, or
	•	insert into auto-layout parent

Which nodes get offsets
	•	all siblings at/after insertionIndex (in filtered children list)
	•	exclude dragged nodes themselves

Offset amount
	•	main-axis size of the dragged bundle + gap(s)
	•	if multi-select bundle:
	•	preserve internal ordering
	•	include gaps between bundle nodes if they remain adjacent after drop

ID domain

Offsets must be keyed by expanded IDs (because render engine positions expanded nodes).

⸻

Drop commit rules (what happens on pointer up)

If NoDrop
	•	revert any preview state
	•	no doc change

If reorder within same parent
	•	compute new child order in doc model
	•	remove dragged ids from list
	•	insert at final index (careful: index changes when removing)
	•	patch document

If reparent
	•	remove from old parent child list
	•	insert into new parent at index
	•	update layout props if needed:
	•	absolute position conversion
	•	auto-layout “fill/hug” normalization if your model requires it

If drop into absolute container
	•	set x/y based on cursor (and optionally preserve relative offset from drag start)

⸻

Edge cases you must explicitly handle

Selection / hierarchy
	•	dragging parent + child selected → normalize to highest ancestor only
	•	dragging multiple nodes with different parents:
	•	either disallow reorder
	•	or treat as “bundle reparent to common parent only”
	•	multi-select order:
	•	preserve relative order (visual or doc order) when inserting

Instances / expanded scenes
	•	doc node appears multiple times via instances:
	•	docId -> multiple expandedIds
	•	you must choose the expandedId under cursor
	•	patchTarget null nodes:
	•	unpatchable → can’t be drop target (or can only accept drop at higher patchable ancestor)

Hover ambiguity
	•	cursor overlaps child bounds and parent bounds:
	•	hit-testing must “see through” dragged nodes
	•	cursor near boundary between parent and sibling container:
	•	require parent-switch hysteresis

Layout weirdness
	•	gap = 0
	•	padding varies
	•	alignment center/end
	•	scroll/clipping: parent might be clipped; indicator should still be visible correctly

Bounds freshness
	•	if bounds lag one frame behind, your insertion will feel broken
	•	you need a rule: “use last-known bounds” + stable fallback
	•	and avoid “return null so indicator disappears”

Overflow
	•	render flex overflow logs during drag (like you saw)
	•	usually means reflow preview is pushing children beyond constraints
	•	fix is often: clip/allow overflow during preview OR compute reflow differently OR use overlay-only preview rather than moving real layout widgets

⸻

Minimal “contract” between systems (so it never breaks again)

Hit-test system provides:
	•	hovered container expandedId + docId
	•	z-order deterministic

Layout/bounds system provides:
	•	bounds for any expandedId (frame-local + world transform)

Drag engine computes:
	•	DropPreview (single source)

Renderer consumes:
	•	reflowOffsetsByExpandedId

Overlay consumes:
	•	indicatorWorldRect

Patcher consumes:
	•	docId reorder/reparent operations

⸻

SPECIFICATION

Drag & Drop Spec (Figma-like) — v1

Scope (v1)

Supports reorder + reparent inside auto-layout containers (Row/Column equivalents).
Absolute positioning drop is disabled (no dropping into stack/absolute parents; no “free placement” on canvas).

⸻

1) Definitions

ID Domains
	•	Doc ID: stable document node id (child_1)
	•	Expanded ID: rendered instance/namespace id (inst1::child_1)
	•	PatchTarget: expandedId -> docId? (null = not patchable)

Containers

A node is a layout container if:
	•	node.layout.autoLayout != null
	•	and node type is container-capable (box/row/column in your model)

Drag Session Inputs
	•	draggedDocIds: Set<String>
	•	draggedExpandedIds: Set<String> (the specific rendered instances being dragged)
	•	originParentDocId
	•	originFrameId

⸻

2) v1 Rules (Hard Constraints)

2.1 Allowed drops

✅ Allowed:
	•	Reorder among siblings in same auto-layout parent
	•	Reparent into a different auto-layout parent (same frame)
	•	Multi-select bundle moves only if all nodes share same origin parent (v1)

❌ Disallowed (v1):
	•	Dropping into absolute/stack parents (autoLayout == null)
	•	Dropping into non-patchable targets (patchTarget null)
	•	Dropping across frames
	•	Dropping across different origin parents (multi-select)

UX requirement: disallowed targets must show clear “not allowed” feedback (cursor + ghost styling), and no indicator line.

⸻

3) System Invariants

3.1 Single source of truth: DropPreview

On every drag update, compute one authoritative object.

enum DropIntent { none, reorder, reparent }

class DropPreview {
  final DropIntent intent;

  // Frame
  final String frameId;

  // Dragged
  final List<String> draggedDocIds;        // stable order (see 4.2)
  final List<String> draggedExpandedIds;   // exact instances being dragged

  // Target
  final String targetParentDocId;
  final String targetParentExpandedId;

  // Children (authoritative list used by index + indicator + reflow)
  final List<String> targetChildrenExpandedIds; // filtered, ordered
  final int insertionIndex;                      // 0..N

  // Visuals
  final Rect indicatorWorldRect;                // already world space
  final Axis indicatorAxis;                     // vertical line vs horizontal line
  final Map<String, Offset> reflowOffsetsByExpandedId;

  // Debug + UX
  final bool isValid;
  final String? invalidReason;
}

No other part of the system may recompute children lists, mappings, indicator position, or reflow. They must consume DropPreview.

⸻

4) Drag Lifecycle

4.1 Drag start
	1.	Capture:

	•	originParentDocId (doc parent)
	•	originParentExpandedId (expanded instance parent under cursor)
	•	draggedDocIds
	•	draggedExpandedIds (the ones actually selected/dragged)

	2.	Normalize selection:

	•	Remove descendants if ancestor is selected
	•	Ensure stable ordering (4.2)

	3.	Start ghost overlay (see Styling section).

4.2 Stable ordering for multi-select bundle

For v1 (same parent only):
	•	Use the parent’s expanded child order to order dragged items.
	•	If multiple expanded instances map to same docId, use the ones in draggedExpandedIds.

Output:
	•	draggedExpandedIdsOrdered[]
	•	draggedDocIdsOrdered[] (parallel)

This is used for:
	•	reflow space needed
	•	commit insertion order

⸻

5) Drop Target Resolution

5.1 Determine hovered parent container (expanded-first)

Input: cursor worldPos

Algorithm:
	1.	Determine active frameId containing cursor.
	2.	Convert to frameLocalPos
	3.	Hit test containers in deterministic topmost order:
	•	Iterate render order topmost-first
	•	Consider only containers where:
	•	patchTarget exists (expanded->docId != null)
	•	doc node is container-capable
	4.	Apply exclusions:
	•	ignore any container whose docId is in draggedDocIds
	•	ignore any container whose expandedId is in draggedExpandedIds (and optionally their subtree)
	5.	First container that contains cursor wins:
	•	targetParentExpandedId
	•	targetParentDocId = patchTarget[targetParentExpandedId]

5.2 v1 “absolute parents are not valid”

If document.nodes[targetParentDocId].layout.autoLayout == null:
	•	DropPreview.intent = none
	•	isValid = false, reason = "target_not_auto_layout"
	•	Provide “not-allowed” ghost styling
	•	Do not show indicator line or slot highlight

⸻

6) Insertion Index (Auto-layout only)

6.1 Authoritative children list

Compute targetChildrenExpandedIds as:
	1.	From renderDoc.nodes[targetParentExpandedId].childIds (expanded IDs)
	2.	Filter out:

	•	any child whose patchTarget[childExpandedId] is in draggedDocIds
	•	any childExpandedId in draggedExpandedIds
	•	any child with patchTarget null (unpatchable children are ignored for ordering in v1)

This filtered list is used everywhere.

6.2 Insertion index calculation

Inputs:
	•	targetChildrenExpandedIds
	•	cursorFrameLocalPos
	•	bounds for each child expandedId (frame-local)
	•	parent direction:
	•	row => horizontal
	•	column => vertical
	•	parent padding + gap

Rule:
	•	Compare cursor to each child’s midpoint on the main axis.
	•	Index is the count of children whose midpoint is “before” cursor.
	•	Clamp to [0, N]

Empty list:
	•	index = 0

6.3 Hysteresis

To prevent flip-flop:
	•	Track lastInsertionIndex and lastCursorPos
	•	Only allow index change if cursor crosses boundary by:

threshold = 8px / zoom

Boundary definition:
	•	midpoint between adjacent child midpoints, or child midpoint for edge cases.

⸻

7) Indicator & Slot Highlight

7.1 Indicator rectangle (world space)

Computed from parent bounds + insertion slot:
	•	For horizontal auto-layout: indicator is a vertical line
	•	For vertical auto-layout: indicator is a horizontal line

For index = 0:
	•	place at parent padding start

For index = N:
	•	place after last child + gap

For index between:
	•	place halfway through the gap between prev and next child (or prev child end + gap/2)

Important: The indicator must be clipped to the parent’s content box (minus padding), matching Figma.

7.2 Slot highlight (optional but very Figma)

In addition to the line, show a subtle “drop slot” highlight:
	•	a translucent rounded rect spanning the cross-axis inside parent padding.
	•	centered on the insertion line.

This makes it obvious you’re reordering within the parent.

⸻

8) Reflow Offsets (Preview)

Only when DropPreview.isValid == true AND parent is auto-layout.

8.1 Space needed

For a bundle:
	•	spaceNeeded = sum(mainAxisSize of dragged items) + gap * (bundleCount)
	•	include one gap for the inserted slot
	•	include internal gaps if the bundle remains adjacent (v1 assumes adjacent)

8.2 Offsets

For each child at positions i >= insertionIndex in targetChildrenExpandedIds:
	•	horizontal: Offset(spaceNeeded, 0)
	•	vertical: Offset(0, spaceNeeded)

Keyed by expandedId of those siblings.

⸻

9) Drop Commit (Pointer Up)

If DropPreview.isValid == false: no-op.

Else:
	•	Determine if intent == reorder (same parent) or reparent (different parent)
	•	Patch in doc space:

9.1 Reorder
	•	parentDoc.childIds remove draggedDocIds (in any order)
	•	Insert draggedDocIdsOrdered at insertion index (adjusted for removals)

9.2 Reparent
	•	Remove from origin parent
	•	Insert into target parent at insertion index
	•	v1 does not convert layout modes; only allowed when both origin and target are auto-layout containers.

⸻

10) Absolute Positioning Handling (v1)

10.1 Disallow absolute drop targets

A parent is “absolute” if:
	•	node.layout.autoLayout == null

Behavior:
	•	Ghost shows “not allowed”
	•	No indicator line
	•	No reflow offsets
	•	On drop: no changes

10.2 Prevent absolute from interfering with hit testing

When searching for target parent:
	•	You may still hit-test absolute containers for containment,
but they must be rejected immediately and the system should continue searching for the nearest eligible auto-layout ancestor.

Rule: “Walk up” to find nearest eligible ancestor:
	•	If hovered container is absolute, climb parent chain (expanded → doc) until you find an auto-layout container or hit frame root.
	•	If none found: invalid.

This prevents “stack parents” from hijacking the drop target.

⸻

11) Styling Spec (Figma-like)

Below is the styling contract for three visuals:
	1.	Drag Ghost
	2.	Insertion Indicator
	3.	Drop Slot / Target Highlight

(Use your design system tokens, but keep these proportions.)

11.1 Drag Ghost

Default (valid target)
	•	Opacity: ~0.85
	•	Scale: 1.0 (no cartoon scaling)
	•	Shadow: soft, medium blur (Figma-like floating card)
	•	Corner radius: match node radius (or 6–8dp fallback)
	•	Optional: slight background tint overlay (very subtle) to differentiate from original

Invalid target
	•	Opacity: ~0.55
	•	Apply desaturation (or reduced contrast)
	•	Add “not allowed” cursor or badge (small ⃠ icon top-right)
	•	No indicator line

Multi-select ghost
	•	“Stacked cards” effect:
	•	2–3 layers behind with slight offset (2–4dp) and lower opacity
	•	Top card is the actual preview

11.2 Insertion Indicator Line
	•	Thickness: 2dp (Figma feels crisp at 2)
	•	Color: Figma blue accent (use your primary accent; should pop)
	•	End caps: square (not rounded) OR very slight rounding (1dp)
	•	Length: spans parent content height/width excluding padding
	•	Always renders above nodes (overlay layer)

11.3 Drop Slot Highlight (recommended)

A subtle fill showing the insertion region:
	•	Fill: accent color at ~10–14% opacity
	•	Corner radius: 6dp
	•	Size:
	•	horizontal layout: width ~8–12dp, height spans parent content
	•	vertical layout: height ~8–12dp, width spans parent content
	•	Centered on indicator line

11.4 Target container highlight (optional)

When hovering a valid container:
	•	Outline stroke: 1dp accent at ~60–70% opacity
	•	Or glow: outer shadow with low opacity
This helps when container has no visible background.

⸻

12) Debug Requirements (must-have while building)

On every drag update, log once (throttled):
	•	frameId
	•	hoveredExpandedId, hoveredDocId
	•	targetParentExpandedId, targetParentDocId
	•	isAutoLayout
	•	childrenCountFiltered
	•	insertionIndex
	•	intent
	•	invalidReason

And expose a debug overlay toggle:
	•	draws parent bounds
	•	draws child midpoints
	•	draws computed insertion line

⸻

13) Acceptance Tests (manual)
	1.	Reorder within row

	•	Drag child A across siblings → slot line appears inside parent, siblings reflow, drop commits order.

	2.	Reparent into another row/column

	•	Hover new container → container highlights, line appears inside it, drop moves node.

	3.	Hover absolute container

	•	Ghost shows invalid, no indicator.
	•	If an auto-layout ancestor exists, it becomes the target instead.

	4.	Multi-select reorder

	•	Select two adjacent siblings, drag → bundle inserts, order preserved.

⸻

Here’s the “render contract” + a concrete DropPreviewBuilder skeleton you can hand to your agent. It’s designed so RenderEngine never needs doc IDs and the overlay never scans maps.

⸻

Render contract

Core rule

Rendering consumes only expanded-space data.
Editing/patching consumes only doc-space data.
The bridge happens once during drag update inside DropPreviewBuilder.

What RenderEngine gets

RenderEngine should accept exactly:

class RenderOverlayState {
  /// Sibling reflow preview (keyed by EXPANDED child id)
  final Map<String, Offset> reflowOffsetsByExpandedId;

  /// Optional: transform for the ghost itself (world -> frame local handled by overlay)
  /// Ghost is typically rendered outside RenderEngine, but if you do it inside:
  final Map<String, Offset> ghostOffsetsByExpandedId; // usually only dragged ones

  const RenderOverlayState({
    this.reflowOffsetsByExpandedId = const {},
    this.ghostOffsetsByExpandedId = const {},
  });
}

Important:
	•	reflowOffsetsByExpandedId keys must match RenderDocument.nodes.keys (expanded ids).
	•	RenderEngine applies those offsets exactly once (you already fixed that).

What the overlays get (indicator + target highlight + ghost)

Overlays should take the DropPreview and paint using:
	•	indicatorWorldRect
	•	targetParentWorldRect (optional)
	•	isValid, invalidReason
	•	ghostWorldTransform (optional)

No overlay code should ever do:
	•	scan(scene.patchTarget.entries)
	•	docId -> expandedId conversion
	•	getExpandedScene() mapping lookups other than reading what the builder gave it

⸻

Data model: DropPreview + commit patch

enum DropIntent { none, reorder, reparent }

class DropPreview {
  final DropIntent intent;
  final bool isValid;
  final String? invalidReason;

  final String frameId;

  // Dragged
  final List<String> draggedDocIdsOrdered;
  final List<String> draggedExpandedIdsOrdered;

  // Target parent
  final String? targetParentDocId;
  final String? targetParentExpandedId;

  // Target children (authoritative)
  final List<String> targetChildrenExpandedIds;  // filtered list used by index/reflow/indicator
  final List<String?> targetChildrenDocIds;       // parallel via patchTarget (optional but useful)

  final int? insertionIndex;

  // Visuals
  final Rect? indicatorWorldRect;
  final Axis? indicatorAxis;

  // Render offsets (expanded keys)
  final Map<String, Offset> reflowOffsetsByExpandedId;

  const DropPreview({
    required this.intent,
    required this.isValid,
    this.invalidReason,
    required this.frameId,
    required this.draggedDocIdsOrdered,
    required this.draggedExpandedIdsOrdered,
    this.targetParentDocId,
    this.targetParentExpandedId,
    this.targetChildrenExpandedIds = const [],
    this.targetChildrenDocIds = const [],
    this.insertionIndex,
    this.indicatorWorldRect,
    this.indicatorAxis,
    this.reflowOffsetsByExpandedId = const {},
  });
}

class DropCommitPlan {
  final bool canCommit;
  final String? reason;

  final String originParentDocId;
  final String targetParentDocId;
  final int insertionIndex;

  final List<String> draggedDocIdsOrdered;

  final bool isReparent; // origin != target

  const DropCommitPlan({
    required this.canCommit,
    this.reason,
    required this.originParentDocId,
    required this.targetParentDocId,
    required this.insertionIndex,
    required this.draggedDocIdsOrdered,
    required this.isReparent,
  });
}


⸻

DropPreviewBuilder (pseudo-implementation)

Responsibilities

Given:
	•	cursor world position
	•	active drag session (selected nodes, start state)
	•	frame render data (RenderDocument, ExpandedScene patchTarget, bounds cache)
	•	document nodes

It produces:
	•	DropPreview
	•	and a DropCommitPlan (optional, for pointer-up)

Key: Precomputed per-frame lookups (do once per frame build)

Build these alongside render compilation:

class FrameLookups {
  // Expanded -> Doc (already exists as scene.patchTarget)
  final Map<String, String?> expandedToDoc;

  // Doc -> Expanded list (MISSING today; build once)
  final Map<String, List<String>> docToExpanded;

  // Expanded -> Parent Expanded (optional but hugely useful for ancestor climb)
  final Map<String, String?> expandedParent;

  // Expanded -> children expanded (already renderDoc.nodes[id].childIds)
  // You may not need to copy it if renderDoc is accessible.

  const FrameLookups({
    required this.expandedToDoc,
    required this.docToExpanded,
    required this.expandedParent,
  });
}

How to build docToExpanded
When building ExpandedScene / RenderDocument, you already traverse nodes. For each expandedId:
	•	docId = expandedToDoc[expandedId]
	•	if docId != null: docToExpanded[docId].add(expandedId)

This eliminates all runtime scanning.

⸻

Builder algorithm

API

class DropPreviewBuilder {
  DropPreview build({
    required CanvasState state,
    required DragSession session,
    required Offset cursorWorld,
    required double zoom,
  });
}

Step 0: Guardrails
	•	If not move drag / no node targets: return intent:none

Step 1: Resolve frame
	•	Determine frameId under cursor (or locked from drag start)
	•	Convert cursorWorld -> frameLocal

Step 2: Resolve hovered container (expanded-first)

ContainerHit? hit = state.hitTestContainerEx(
  frameId,
  cursorWorld,
  excludeDocIds: session.draggedDocIds,
  excludeExpandedIds: session.draggedExpandedIds,
);

Where:

class ContainerHit {
  final String expandedId;
  final String docId;
  const ContainerHit({required this.expandedId, required this.docId});
}

Step 3: Climb to nearest valid auto-layout parent (v1)

We explicitly avoid absolute interfering:

ContainerHit? resolveEligibleTarget(ContainerHit? hit) {
  var current = hit;
  while (current != null) {
    final docNode = state.document.nodes[current.docId];
    if (docNode != null && docNode.layout.autoLayout != null) {
      return current;
    }
    // climb via expanded parent -> doc mapping
    final parentExpanded = lookups.expandedParent[current.expandedId];
    if (parentExpanded == null) return null;
    final parentDoc = lookups.expandedToDoc[parentExpanded];
    if (parentDoc == null) {
      // keep climbing; unpatchable container
      current = ContainerHit(expandedId: parentExpanded, docId: '__unpatchable__');
      continue;
    }
    current = ContainerHit(expandedId: parentExpanded, docId: parentDoc);
  }
  return null;
}

If no eligible target:
	•	return invalidReason = "no_autolayout_target"

Step 4: Validate patchability + multi-select constraints

v1 constraints:
	•	all dragged nodes must share same origin parent
	•	all dragged nodes patchable
	•	target patchable
	•	target in same frame

If fail:
	•	intent:none, invalidReason

Step 5: Build authoritative children list (expanded ids)

From renderDoc:

final childrenExpandedAll =
  renderDoc.nodes[targetParentExpandedId]!.childIds; // expanded list

Filter:
	•	remove children whose docId is dragged
	•	remove childrenExpanded that are draggedExpanded
	•	remove children with patchTarget null (optional for v1 ordering)

Also compute parallel doc ids:

final childrenExpanded = <String>[];
final childrenDoc = <String?>[];
for (final childExp in childrenExpandedAll) {
  final childDoc = lookups.expandedToDoc[childExp];
  if (childDoc == null) continue; // v1: ignore unpatchable
  if (session.draggedDocIds.contains(childDoc)) continue;
  if (session.draggedExpandedIds.contains(childExp)) continue;
  childrenExpanded.add(childExp);
  childrenDoc.add(childDoc);
}

Store this list on session if you want hysteresis stability.

Step 6: Compute insertion index (with hysteresis)

Compute midpoints from bounds cache:

int computeIndex(...) { ... } // midpoint logic

Then apply hysteresis:
	•	use session.lastInsertionIndex + session.lastInsertionCursorFrameLocal
	•	threshold = 8 / zoom

Step 7: Compute indicator world rect

Use:
	•	target parent bounds (expanded)
	•	child bounds (expanded)
	•	parent auto-layout padding + gap
	•	insertionIndex
Return world rect (frame origin + frame local rect)

Rule: clamp indicator within parent content box.

Step 8: Compute reflow offsets (expanded keys)

Compute spaceNeeded along main axis only (bundle size + gap).

Then:

final offsets = <String, Offset>{};
for (var i = insertionIndex; i < childrenExpanded.length; i++) {
  offsets[childrenExpanded[i]] = direction == horizontal
    ? Offset(spaceNeeded, 0)
    : Offset(0, spaceNeeded);
}

Step 9: Decide intent (reorder vs reparent)
	•	originParentDocId == targetParentDocId => reorder
	•	else reparent

Step 10: Return DropPreview

All fields populated. Overlay + renderer just consume it.

⸻

Commit logic (pointer up)

On drop, use DropCommitPlan derived from preview:

Rules:
	•	If preview invalid => no-op
	•	Reorder:
	•	remove draggedDocIds from origin parent childIds
	•	insert at index adjusted for removals
	•	Reparent:
	•	remove from origin parent
	•	insert into target parent

Important edge case: index adjustment when dragging within same list:
	•	When moving items forward, removing them shifts the effective insertion index.
	•	Fix by computing index in the filtered list (you already do this). Then commit uses that same filtered index.

⸻

Visual contract (exact behaviors)

Ghost overlay
	•	Render in overlay layer (above canvas)
	•	Position = cursor + initial grab offset
	•	Valid target: 0.85 opacity + soft shadow
	•	Invalid: 0.55 opacity + “not allowed” badge
	•	Multi-select: stacked cards (2 back layers)

Indicator + slot
	•	Only show if preview.isValid && preview.insertionIndex != null
	•	Draw:
	1.	slot highlight rect (10–14% accent)
	2.	2dp indicator line (accent)
	•	Clip to parent content rect

Target highlight
	•	If valid: outline parent with 1dp accent @ ~60%
	•	If invalid: no outline (or subtle warning outline)

⸻

“Absolute positioning does not interfere” (v1 enforcement)

This is the key behavioral rule:
	•	Hit testing may return any container under cursor,
	•	but resolveEligibleTarget() must climb until it finds autoLayout != null.
	•	If it reaches frame root without finding one: invalid.

That prevents stack/absolute layers from hijacking the drop target and causing exactly the “indicator outside parent” feeling.

⸻

