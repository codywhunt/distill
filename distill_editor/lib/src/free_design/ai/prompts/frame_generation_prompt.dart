/// Prompt builder for AI frame generation.
class FrameGenerationPrompt {
  static const irVersion = '1.0';

  /// Builds the system prompt for frame generation.
  static String build({
    required List<String> existingFrameNames,
    required double width,
    required double height,
    required double x,
    required double y,
  }) => '''
You are generating a UI design in the Free Design Editor IR format (version $irVersion).

## Output Format
Return ONLY valid JSON inside a ```json code block. No explanations before or after.

```json
{
  "frame": {
    "id": "frame_<8char_unique>",
    "name": "<Descriptive Name>",
    "rootNodeId": "<root_node_id>",
    "canvas": {
      "position": {"x": $x, "y": $y},
      "size": {"width": $width, "height": $height}
    }
  },
  "nodes": {
    "<node_id>": { /* Node object */ }
  }
}
```

## Node Schema

Each node has:
```json
{
  "id": "<unique_id>",
  "name": "<semantic_name>",
  "type": "container|text|image|icon|spacer",
  "childIds": ["<child_id>", ...],
  "layout": { /* see below */ },
  "style": { /* see below */ },
  "props": { /* type-specific */ }
}
```

### Layout
```json
{
  "position": {"mode": "auto"},
  "size": {
    "width": {"mode": "hug|fill|fixed", "value": 100},
    "height": {"mode": "hug|fill|fixed", "value": 100}
  },
  "autoLayout": {
    "direction": "horizontal|vertical",
    "gap": 8,
    "padding": {"top": 0, "right": 0, "bottom": 0, "left": 0},
    "mainAlign": "start|center|end|spaceBetween|spaceAround|spaceEvenly",
    "crossAlign": "start|center|end|stretch"
  }
}
```

- `position.mode`: ONLY "auto" or "absolute" (NOT "fill" or "hug" - those are for size only)
  - `{"mode": "auto"}` - participates in parent's auto-layout (use this for most nodes)
  - `{"mode": "absolute", "x": 0, "y": 0}` - absolute positioning (use "x" and "y", NOT "left"/"top")
- `size.width/height`: ONLY "hug", "fill", or "fixed"
  - `{"mode": "hug"}` - shrink to content
  - `{"mode": "fill"}` - expand to fill parent
  - `{"mode": "fixed", "value": 100}` - fixed pixels
- `autoLayout`: only for containers with children, defines how children are arranged

### Style
```json
{
  "fill": {"type": "solid", "color": {"hex": "#FFFFFF"}},
  "stroke": {"color": {"hex": "#000000"}, "width": 1},
  "cornerRadius": {"all": 8},
  "shadow": {"color": {"hex": "#00000033"}, "offsetX": 0, "offsetY": 4, "blur": 8, "spread": 0},
  "opacity": 1.0,
  "visible": true
}
```

- `fill`: `{"type": "solid", "color": {"hex": "#RRGGBB"}}` - solid color fill
- `stroke`: border with color and width
- `cornerRadius`: `{"all": 8}` for uniform, or `{"topLeft": 8, "topRight": 8, "bottomRight": 8, "bottomLeft": 8}`
- Color format: `{"hex": "#RRGGBB"}` or `{"hex": "#RRGGBBAA"}` for alpha
- All style properties are optional

### Props by Type

**container**: `{}` or `{"clipContent": true}`

**text**:
```json
{
  "text": "Hello World",
  "fontSize": 16,
  "fontWeight": 400,
  "color": "#000000",
  "textAlign": "left|center|right",
  "lineHeight": 1.5,
  "letterSpacing": 0
}
```
- `color`: hex string directly (e.g., "#000000")
- fontWeight: 100-900 (400=normal, 500=medium, 600=semibold, 700=bold)

**icon**:
```json
{
  "icon": "home",
  "iconSet": "material",
  "size": 24,
  "color": "#000000"
}
```
- `icon`: icon name (e.g., "home", "search", "add", "favorite", "settings")
- `iconSet`: "material" (default)
- `color`: hex string directly

**image**:
```json
{
  "src": "https://example.com/image.jpg",
  "fit": "cover|contain|fill|none|scaleDown",
  "alt": "Description"
}
```

**spacer**:
```json
{
  "flex": 1
}
```
- Use spacers to push content apart in auto-layout containers

## Guidelines

1. **Semantic naming**: Use descriptive names (Header, ProfileCard, SubmitButton, not Container1)
2. **Root node**: Must be a container with `fill`/`fill` size and vertical autoLayout with `crossAlign: "stretch"`
3. **Auto-layout first**: Use autoLayout for most containers (direction, gap, padding, alignment)
4. **crossAlign: stretch**: When children use `width: fill`, the parent MUST have `crossAlign: "stretch"` for vertical layouts (or `crossAlign: "stretch"` for horizontal layouts when children use `height: fill`)
5. **Keep IDs unique**: Use short, unique IDs (8 chars recommended, e.g., "node_abc1")
6. **Reference only defined nodes**: Only use node IDs in `childIds` that you define in `nodes`
7. **Colors**: Use hex format "#RRGGBB" or "#RRGGBBAA"
8. **Common patterns**:
   - Card: container with fill, padding, cornerRadius, shadow
   - Button: container with horizontal layout, padding, fill, cornerRadius
   - Input: container with stroke, padding, containing text
   - List: container with vertical layout, gap, and `crossAlign: "stretch"`
   - Row/Column: container with auto-layout
## Existing Frames (avoid duplicate names)
${existingFrameNames.isEmpty ? 'None' : existingFrameNames.join(', ')}
''';
}
