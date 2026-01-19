# Components v2: Implementation Progress

> Living document for tracking progress, lessons learned, and notes between phases.

**Roadmap**: [components-v2-roadmap.md](./components-v2-roadmap.md)
**Started**: 2026-01-18
**Current Phase**: Phase 2 Complete - Ready for Phase 3

---

## Progress Overview

| Phase | Status | Started | Completed | Notes |
|-------|--------|---------|-----------|-------|
| Phase 0: Foundation Hardening | ✅ Complete | 2026-01-18 | 2026-01-18 | All 33 tests passing |
| Phase 1: Slots That Work | ✅ Complete | 2026-01-18 | 2026-01-18 | 48 tests passing (43 unit + 5 integration) |
| Phase 1.5: Component Navigation | ✅ Complete | 2026-01-18 | 2026-01-18 | 19 tests passing (6 unit + 13 integration) |
| Phase 2: Parameters | ✅ Complete | 2026-01-18 | 2026-01-18 | 85 tests passing (35 unit + 12 expansion + 8 integration) |
| Phase 3: Component Library | Not Started | - | - | - |
| Phase 4: Variants | Not Started | - | - | - |

---

## Phase 0: Foundation Hardening

### Status: ✅ Complete

### Tasks Completed
- [x] Add path-based cycle detection
- [x] Add `ExpandedNodeOrigin` with `OriginKind`
- [x] Add `templateUid` to Node
- [x] Add `sourceComponentId` to Node
- [x] Add `ownerInstanceId` to Node
- [x] Clarify `id` vs `name` semantics
- [x] Source-namespace component nodes
- [x] Add `componentNodeId` helper (plus `localIdFromNodeId`, `componentIdFromNodeId`)
- [x] Update existing tests
- [x] Add new Phase 0 tests (cycle detection, origin metadata, override resolution)

### Test Results
```
Total: 33
Passed: 33
Failed: 0
Success: true
```

### Decisions Made During Implementation

1. **Expanded ID format**: `inst_btn1::comp_button::btn_root` - instance namespace prepended to source-namespaced node ID. The first segment (before any `::`) is always the instance ID since instance IDs never contain `::`.

2. **Override key resolution**: Support both local IDs (`'btn_label'`) and namespaced IDs (`'comp_button::btn_label'`) for backward compatibility. This allows existing instance overrides to work while enabling future migration to fully namespaced keys.

3. **Origin excluded from equality**: `ExpandedNode.origin` is NOT included in `operator==` or `hashCode` to avoid churn from list comparison in `instancePath`. Origin is metadata for UI decisions, not node identity.

4. **templateUid uniqueness**: `templateUid` must be unique within a component, not globally. It's typically the local part of the namespaced ID (e.g., `'btn_root'` for `'comp_button::btn_root'`).

5. **Terminology**: Use "localId" consistently throughout (not "localName" or "localPartOfId").

6. **Cycle placeholder debugging**: Cycle and missing component placeholders include `origin.componentId` and `origin.instancePath` for debugging which component caused the cycle and the path to reach it.

### Lessons Learned

- **Override addressing required careful thought**: After namespacing node IDs, existing overrides keyed by local ID would break. Solved by checking both the full ID and the extracted local ID when resolving overrides.

- **Instance path helpers work with new format**: The `split('::').first` approach correctly extracts instance IDs because instance IDs never contain `::`, only component node IDs do.

- **Test updates were straightforward**: Updating test expectations for namespaced IDs was mechanical - just prepending `comp_button::` to component node IDs and `instanceId::comp_button::` to expanded IDs.

### Blockers Encountered
None.

### Notes for Phase 1

1. **SlotOrigin is ready**: The `SlotOrigin` class and `OriginKind.slotContent` are already defined, ready for slot injection tracking.

2. **Override key format**: Current overrides use local IDs. Phase 1 can continue this pattern for slot content, or migrate to namespaced keys.

3. **Patch targeting for slots**: Currently instance children have `patchTargetId: null`. Slot content should have `patchTargetId` pointing to the actual slot content node (stored in document under the instance's ownership).

---

## Phase 1: Slots That Work

### Status: ✅ Complete

### Tasks Completed
- [x] Add `SlotAssignment` model
- [x] Add `slots` to `InstanceProps`
- [x] Expand slot with injected content
- [x] Make slot content editable (all descendants get patchTargetId)
- [x] Handle default slot content (non-editable, component-owned)
- [x] Slot UI in property panel
- [x] Show slot content in layer tree
- [x] Slot content lifecycle (cleanup on instance delete, clear slot)
- [x] `slotChildrenByInstance` index for O(1) layer tree lookup

### Test Results
```
Total: 48 (43 unit tests + 5 integration tests)
Passed: 48
Failed: 0
```

**Unit Tests (expanded_scene_builder_test.dart)**:
1. slot with no assignment renders as placeholder
2. slot with assignment renders injected content
3. slot replacement changes parent childIds correctly
4. slot with defaultContentId uses default when empty
5. injected content is editable (patchTargetId set)
6. injected content descendants are editable
7. component children still not editable
8. slot content has slotContent origin kind
9. slot content has correct slotOrigin
10. slotChildrenByInstance index is populated

**Integration Tests (slot_injection_test.dart)**:
1. delete instance cleans up slot content
2. clear slot deletes old content
3. delete instance cleans up nested slot content
4. collectOwnedSubtrees returns all owned nodes

### Decisions Made During Implementation

1. **Safe expanded ID encoding**: Content node IDs are sanitized with `contentNodeId.replaceAll('::', '__')` before embedding in expanded IDs. This prevents parsing ambiguity when content node IDs contain `::`.

2. **Slot returns exactly ONE expanded ID**: `_expandSlot` returns a single ID (injected content root, default content root, or placeholder). The slot node is replaced, not wrapped, keeping parent childIds clean.

3. **`slotChildrenByInstance` index**: Built during scene expansion for O(1) lookup in layer tree. Maps instance expanded ID → list of slot content root expanded IDs.

4. **All slot content descendants editable**: Not just the root node - every descendant of slot content gets `patchTargetId = node.id` using `editableTarget: true`.

5. **Default content NOT editable**: Default slot content uses `editableTarget: false` and `OriginKind.componentChild` because it's component-owned.

6. **Layer tree uses `origin.kind == instanceRoot`**: Rather than relying on `patchTargetId == null` heuristic, check origin kind explicitly for determining which nodes show slot children.

7. **`collectOwnedSubtrees` deduplicates**: Returns unique node IDs using a Set to handle nested ownership correctly.

8. **Cycle protection in slot discovery**: `_findComponentSlots` uses a visited set to prevent infinite loops on malformed component graphs.

9. **Instance nodes are real ExpandedNodes**: `_expandInstance` creates an `ExpandedNode` for the instance itself with `OriginKind.instanceRoot`, `patchTargetId = instanceNode.id`, and `childIds = [componentRootExpandedId]`. This makes instances selectable in the layer tree while keeping component internals hidden.

### Lessons Learned

- **`ExpandedNode.fromNode` needed `editableTarget` param**: The original `??` operator for `patchTargetId` defaulted null to `node.id`, making it impossible to create non-editable nodes. Added explicit `editableTarget: bool` parameter.

- **Slot content nodes need `ownerInstanceId`**: All nodes in slot content must have `ownerInstanceId` pointing to the owning instance for proper lifecycle cleanup when the instance is deleted.

- **Integration tests found deduplication bug**: The `collectOwnedSubtrees` method was double-counting nested owned nodes. Fixed by using Set-based deduplication.

- **Instance selection required creating ExpandedNode for instances**: The scene builder was only setting `patchTarget[instanceId]` without creating an actual `ExpandedNode` for the instance. This meant `OriginKind.instanceRoot` was never set, breaking layer tree selection. Fixed by creating an instance `ExpandedNode` with `OriginKind.instanceRoot` and the component root as its child.

### Blockers Encountered
None.

### Notes for Phase 1.5

1. **Slot content is fully editable**: Slot content and all its descendants can be selected and modified via the property panel.

2. **Slot UI ready**: Property panel shows slot controls for instances with slots. Users can add/clear slot content.

3. **Layer tree displays slot content**: Instance nodes show their slot content as virtual children using the `slotChildrenByInstance` index.

---

## Phase 1.5: Minimal Component Navigation

### Status: ✅ Complete

### Tasks Completed
- [x] Add `FrameKind` enum (`design` | `component`)
- [x] Add `componentId` to Frame
- [x] Add `kind` field to Frame (defaults to `design`)
- [x] Update Frame `copyWith`, `fromJson`, `toJson`, `==`, `hashCode`
- [x] Backwards-compatible JSON parsing (missing `kind` defaults to `design`)
- [x] Add `findComponentFrame(componentId)` to CanvasState
- [x] Add `navigateToComponent(componentId)` to CanvasState
- [x] Add `createComponentFrame(componentId, position)` to EditorDocumentStore
- [x] Make instance badge clickable in NodeTreeItem
- [x] Wire up `onGoToComponent` callback in WidgetTreePanel
- [x] Add unit tests for Frame model changes
- [x] Add integration tests for component navigation

### Test Results
```
Unit Tests (frame_test.dart): 13 total, 13 passed
Integration Tests (component_navigation_test.dart): 13 total, 13 passed
Total: 26
Passed: 26
Failed: 0
```

### Decisions Made During Implementation

1. **Instance badge click for navigation**: Rather than adding a context menu, clicking the purple component badge navigates to the component's editing frame. This is intuitive because the badge already indicates "this is a component instance."

2. **Component frames share component root node**: Component frames don't create their own root node - they point directly to `ComponentDef.rootNodeId`. This avoids duplicating nodes and ensures edits to the component frame affect the actual component.

3. **Frame size derived from component root**: When creating a component frame, the size is derived from the component's root node layout if it has fixed dimensions. Falls back to 375x400 if dimensions aren't determinable.

4. **Auto-create component frame on navigation**: `navigateToComponent` creates the frame if it doesn't exist, placing it near the viewport center. This provides a seamless experience - users don't need to manually create component frames.

5. **Tooltip feedback**: Instance badge tooltip changes from "Component instance" to "Click to edit component" when the callback is available, providing clear affordance.

### Lessons Learned

- **Frame model changes were straightforward**: Adding `kind` and `componentId` with backwards-compatible defaults made the migration seamless.

- **CanvasState already had the infrastructure**: The `selectFrame` and `animateToFit` patterns were already established, making `navigateToComponent` easy to implement.

- **Integration tests needed careful setup**: Creating valid component-instance-frame relationships in tests requires setting up `sourceComponentId`, `templateUid`, and proper node hierarchies.

### Blockers Encountered
None.

### Notes for Phase 2

1. **Component frames are navigable**: Users can now click instance badges to open the component for editing.

2. **`Frame.componentId` available**: The link from frame to component is established, enabling the property panel to show component-specific controls.

3. **`findComponentFrame(componentId)` helper**: Can be used by other features (e.g., library panel) to check if a component frame exists.

---

## Phase 2: Parameters

### Status: ✅ Complete

### Tasks Completed
- [x] Add `ComponentParamDef` model
- [x] Add `ParamBinding` model
- [x] Add `ParamType`, `OverrideBucket`, `ParamField` enums
- [x] Add `ParamTarget` typedef for keying resolved values
- [x] Add `params` to ComponentDef (with `@Deprecated` `exposedProps` for backwards compatibility)
- [x] Add `paramOverrides` to InstanceProps (with `@Deprecated` `overrides` for backwards compatibility)
- [x] Apply params during expansion with pre-indexed binding lookup
- [x] Parameter section in prop panel (grouped by `param.group`)
- [x] Override indicators (accent-colored bar)
- [x] Reset param action (via SetProp with empty map)
- [x] Type coercion for invalid paramOverride values
- [x] Support for multiple param types: string, number, boolean, color, enumValue
- [x] Export from models.dart barrel file

### Test Results
```
Unit Tests (component_param_test.dart): 23 total, 23 passed
Expansion Tests (expanded_scene_builder_test.dart - Parameter Application group): 12 total, 12 passed
Integration Tests (parameter_binding_test.dart): 8 total, 8 passed
Total: 85 (combined with existing 42 expansion tests)
Passed: 85
Failed: 0
```

**Unit Tests (component_param_test.dart)**:
1. ParamType enum serialization round-trips
2. OverrideBucket enum serialization round-trips
3. ParamField enum serialization round-trips
4. ParamBinding creates with required fields
5. ParamBinding JSON round-trip preserves data
6. ParamBinding equality works correctly
7. ComponentParamDef creates with required fields
8. ComponentParamDef creates with all optional fields
9. ComponentParamDef JSON round-trip for string/number/boolean/color/enum params
10. ComponentParamDef copyWith creates modified copy
11. ComponentParamDef equality handles enumOptions correctly
12. ParamTarget can be used as map key

**Expansion Tests (expanded_scene_builder_test.dart - Parameter Application group)**:
1. param with no override uses default value
2. param override applied to correct node
3. param binding resolves by templateUid
4. unknown param key ignored gracefully
5. isOverridden set correctly when param is explicitly overridden
6. defaults apply but node NOT marked as overridden (CRITICAL)
7. legacy overrides layer on top of param defaults
8. type coercion handles invalid values gracefully
9. number param applies to layout width
10. color param applies to style fill
11. multiple params apply to different nodes

**Integration Tests (parameter_binding_test.dart)**:
1. param override via SetProp updates expanded scene
2. reset param by replacing entire paramOverrides map
3. param change updates expanded scene with color
4. multiple params can be set independently
5. undo restores previous param value
6. param override persists through document round-trip
7. nested instances with params work correctly

### Decisions Made During Implementation

1. **Pre-index params by `targetTemplateUid`**: Build `bindingsByTemplateUid` map once per instance expansion for O(params bound to node) instead of O(all params) lookup. This is important for components with many parameters.

2. **Use `(bucket, field)` as key for resolved values**: The `ParamTarget` typedef `({OverrideBucket bucket, ParamField field})` prevents field confusion across buckets. A `text` field in `props` bucket is distinct from any potential `text` field in other buckets.

3. **`isOverridden` semantics**: Only true when an explicit `paramOverrides[key]` exists. Parameter defaults are applied to nodes but do NOT set `isOverridden = true`. This prevents false positives in the UI.

4. **Layer param + legacy overrides**: Params (defaults + explicit overrides) are applied first, then legacy `overrides` are applied on top. This ensures backward compatibility while allowing migration to the new system.

5. **Type coercion with fallback to default**: Invalid values in `paramOverrides` (wrong type, null, etc.) fall back to the parameter's `defaultValue` rather than crashing. This prevents expansion failures from bad JSON.

6. **`@Deprecated` annotations**: Both `ComponentDef.exposedProps` and `InstanceProps.overrides` are marked as deprecated to guide migration while maintaining backward compatibility.

7. **Param reset via entire map replacement**: The patch system doesn't support nested map key deletion, so resetting a param uses `SetProp(path: '/props/paramOverrides', value: {})` to replace the entire map. Individual key updates use `SetProp(path: '/props/paramOverrides/$key', value: newValue)`.

8. **Parameter grouping in UI**: Parameters are grouped by their `group` field (defaulting to "General") in the property panel, making it easier to organize many parameters.

### Lessons Learned

- **API discovery for immutable models**: The codebase uses immutable models without `copyWith` for some types (`TokenEdgePadding`, `Stroke`). Had to create new instances with preserved values rather than using copyWith.

- **NumericValue vs FixedNumeric**: `NumericValue` is the abstract base class; `FixedNumeric` is the concrete implementation for fixed values. No `NumericValue.fixed()` factory exists.

- **HexColor uses `.hex` not `.value`**: The `ColorValue` hierarchy uses type-specific properties (`HexColor.hex`, `TokenColor.token`).

- **Parameter bindings use `templateUid` not node ID**: This is crucial because component node IDs are namespaced (`comp_button::btn_label`) but `templateUid` is the stable identifier (`btn_label`) that survives renaming.

- **Component change propagation requires instance tracking**: When a component's source nodes change, `CanvasState._onStoreChanged()` must invalidate ALL frames containing instances of that component, not just the frame containing the changed node. The fix tracks affected component IDs via `node.sourceComponentId` and scans all frames for instances of those components.

### Blockers Encountered

- **Patch system limitation**: Setting individual keys in nested maps (`/props/paramOverrides/$key`) to `null` doesn't work cleanly due to unmodifiable map errors. Workaround: replace the entire `paramOverrides` map when resetting parameters.

### Notes for Phase 3

1. **Parameters are fully functional**: Components can define typed parameters with bindings to node fields. Instances can override parameters, and the property panel shows controls grouped by category.

2. **UI controls available for all param types**: String (TextEditor), Number (NumberEditor), Boolean (BooleanEditor), Color (ColorPickerPopover), Enum (DropdownEditor).

3. **Override indicator pattern**: A small accent-colored bar appears next to overridden parameters, clickable to reset. This pattern can be reused for other override indicators.

4. **Type coercion is defensive**: The expansion system won't crash on malformed `paramOverrides` - it falls back to defaults gracefully.

---

## Phase 3: Component Library Panel

### Status: Not Started

### Tasks Completed
- [ ] Component Library panel widget
- [ ] Drag-to-instantiate
- [ ] "Create component from selection"
- [ ] Component search/filter
- [ ] Show component sets grouped

### Test Results
```
Total: -
Passed: -
Failed: -
```

### Decisions Made During Implementation
_Document any decisions made that weren't covered in the roadmap._

### Lessons Learned
_What worked well? What was harder than expected?_

### Blockers Encountered
_Any blockers and how they were resolved._

### Notes for Phase 4
_Anything the next phase needs to know._

---

## Phase 4: Variants

### Status: Not Started

### Tasks Completed
- [ ] Add `ComponentSet` model
- [ ] Add `VariantAxis` model
- [ ] Add variant membership to ComponentDef
- [ ] Add `componentSets` to EditorDocument
- [ ] Variant switcher in prop panel
- [ ] "Create variant" action
- [ ] "Create variant set" action
- [ ] Variant grid view in library

### Test Results
```
Total: -
Passed: -
Failed: -
```

### Decisions Made During Implementation
_Document any decisions made that weren't covered in the roadmap._

### Lessons Learned
_What worked well? What was harder than expected?_

### Blockers Encountered
_Any blockers and how they were resolved._

### Notes for Phase 5 (Future)
_Anything future work needs to know._

---

## Cross-Phase Notes

### Architecture Insights

1. **Component change propagation requires explicit instance tracking**: The `CanvasState` cache invalidation logic must track which components are affected by node changes (via `sourceComponentId`) and then scan all frames for instances of those components. Simply invalidating the frame containing the changed node is insufficient because instances in other frames also depend on that component's definition.

2. **`getFrameForNode()` only returns direct containment**: This helper finds the frame whose subtree contains a node ID, but doesn't account for component/instance relationships. Frames with instances of a component aren't "found" when searching for component source nodes.

### Technical Debt Created

1. **O(frames × nodes) scan for instance invalidation**: The current implementation scans all frames and their subtrees when a component changes. For large documents with many frames, this could become a bottleneck. Consider maintaining a reverse index: `componentId → Set<frameId>` that's updated when instances are added/removed.

### Documentation Gaps
_Areas where the roadmap was unclear or needed updates._

### Performance Observations
_Any performance considerations discovered during implementation._

---

## Changelog

| Date | Phase | Change | Author |
|------|-------|--------|--------|
| 2026-01-18 | Phase 2 | Fixed cache invalidation: component source node changes now propagate to all frames containing instances of that component via `_onStoreChanged()` in CanvasState | Claude |
| 2026-01-18 | Phase 2 | Completed Phase 2: Parameters - ComponentParamDef model, ParamBinding, typed params (string/number/boolean/color/enum), pre-indexed binding resolution, property panel UI with grouping, override indicators, backwards-compatible with legacy overrides, 85 tests passing | Claude |
| 2026-01-18 | Phase 1.5 | Completed Phase 1.5: Component Navigation - FrameKind enum, Frame.componentId, navigateToComponent, createComponentFrame, clickable instance badges, 26 tests passing | Claude |
| 2026-01-18 | Phase 1 | Fixed instance selection: scene builder now creates ExpandedNode for instances with OriginKind.instanceRoot, enabling layer tree selection | Claude |
| 2026-01-18 | Phase 1 | Completed Phase 1: Slots That Work - SlotAssignment model, slot expansion, slot content editability, property panel UI, layer tree display, lifecycle cleanup, 48 tests passing | Claude |
| 2026-01-18 | Phase 0 | Completed Phase 0: Foundation Hardening - cycle detection, origin metadata, source namespacing, helper functions, 33 tests passing | Claude |

---

*Document created: January 2026*
