/// Original ChatGPT and iMessage clone demo frames
/// Clean, modern designs showcasing canvas capabilities

import 'dart:ui';
import '../../src/free_design/free_design.dart';

/// Create a demo document with sample frames and nodes.
/// Features minimalist, Apple-inspired design (2 sample frames for review).
EditorDocument createMinimalDemoFrames() {
  final now = DateTime.now();

  // =========================================================================
  // ChatGPT Interface Frame
  // =========================================================================
  final chatGptFrame = Frame(
    id: 'frame_chatgpt',
    name: 'ChatGPT',
    rootNodeId: 'gpt_root',
    canvas: const CanvasPlacement(
      position: Offset(0, 100),
      size: Size(393, 852),
    ),
    createdAt: now,
    updatedAt: now,
  );

  // Root container - iPhone 14 Pro dimensions
  final gptRoot = Node(
    id: 'gpt_root',
    name: 'ChatGPT Screen',
    type: NodeType.container,
    props: ContainerProps(),
    layout: NodeLayout(
      size: SizeMode.fixed(393, 852),
      autoLayout: AutoLayout(
        direction: LayoutDirection.vertical,
        mainAlign: MainAxisAlignment.start,
        crossAlign: CrossAxisAlignment.stretch,
      ),
    ),
    style: NodeStyle(fill: SolidFill(HexColor('#FFFFFF'))),
    childIds: [
      'gpt_status_bar',
      'gpt_header',
      'gpt_chat_area',
      'gpt_input_area',
      'gpt_footer',
    ],
  );

  // Status Bar (9:41, signal, wifi, battery)
  final gptStatusBar = Node(
    id: 'gpt_status_bar',
    name: 'Status Bar',
    type: NodeType.container,
    props: ContainerProps(),
    layout: NodeLayout(
      size: SizeMode.fixed(393, 54),
      autoLayout: AutoLayout(
        direction: LayoutDirection.horizontal,
        padding: TokenEdgePadding.symmetric(horizontal: 24, vertical: 14),
        mainAlign: MainAxisAlignment.spaceBetween,
        crossAlign: CrossAxisAlignment.center,
      ),
    ),
    childIds: ['gpt_time', 'gpt_status_icons'],
  );

  final gptTime = Node(
    id: 'gpt_time',
    name: 'Time',
    type: NodeType.text,
    props: TextProps(
      text: '9:41',
      fontSize: 17,
      fontWeight: 600,
      color: '#000000',
    ),
    layout: NodeLayout(size: SizeMode.hug()),
  );

  final gptStatusIcons = Node(
    id: 'gpt_status_icons',
    name: 'Status Icons',
    type: NodeType.container,
    props: ContainerProps(),
    layout: NodeLayout(
      size: SizeMode.hug(),
      autoLayout: AutoLayout(
        direction: LayoutDirection.horizontal,
        gap: FixedNumeric(6),
        mainAlign: MainAxisAlignment.end,
        crossAlign: CrossAxisAlignment.center,
      ),
    ),
    childIds: ['gpt_signal', 'gpt_wifi', 'gpt_battery'],
  );

  final gptSignal = Node(
    id: 'gpt_signal',
    name: 'Signal',
    type: NodeType.icon,
    props: IconProps(icon: 'signal_cellular_alt', size: 16, color: '#000000'),
    layout: NodeLayout(size: SizeMode.fixed(16, 16)),
  );

  final gptWifi = Node(
    id: 'gpt_wifi',
    name: 'WiFi',
    type: NodeType.icon,
    props: IconProps(icon: 'wifi', size: 16, color: '#000000'),
    layout: NodeLayout(size: SizeMode.fixed(16, 16)),
  );

  final gptBattery = Node(
    id: 'gpt_battery',
    name: 'Battery',
    type: NodeType.container,
    props: ContainerProps(),
    layout: NodeLayout(size: SizeMode.fixed(27, 13)),
    style: NodeStyle(
      fill: SolidFill(HexColor('#000000')),
      cornerRadius: CornerRadius.circular(3),
    ),
  );

  // Header with menu, title, and edit icon
  final gptHeader = Node(
    id: 'gpt_header',
    name: 'Header',
    type: NodeType.container,
    props: ContainerProps(),
    layout: NodeLayout(
      size: SizeMode.fixed(393, 44),
      autoLayout: AutoLayout(
        direction: LayoutDirection.horizontal,
        padding: TokenEdgePadding.symmetric(horizontal: 16, vertical: 8),
        mainAlign: MainAxisAlignment.spaceBetween,
        crossAlign: CrossAxisAlignment.center,
      ),
    ),
    childIds: ['gpt_menu_icon', 'gpt_title_row', 'gpt_edit_icon'],
  );

  final gptMenuIcon = Node(
    id: 'gpt_menu_icon',
    name: 'Menu',
    type: NodeType.icon,
    props: IconProps(icon: 'menu', size: 24, color: '#000000'),
    layout: NodeLayout(size: SizeMode.fixed(24, 24)),
  );

  final gptTitleRow = Node(
    id: 'gpt_title_row',
    name: 'Title Row',
    type: NodeType.container,
    props: ContainerProps(),
    layout: NodeLayout(
      size: SizeMode.hug(),
      autoLayout: AutoLayout(
        direction: LayoutDirection.horizontal,
        gap: FixedNumeric(4),
        mainAlign: MainAxisAlignment.center,
        crossAlign: CrossAxisAlignment.center,
      ),
    ),
    childIds: ['gpt_title_text', 'gpt_chevron'],
  );

  final gptTitleText = Node(
    id: 'gpt_title_text',
    name: 'Title',
    type: NodeType.text,
    props: TextProps(
      text: 'ChatGPT',
      fontSize: 17,
      fontWeight: 600,
      color: '#000000',
    ),
    layout: NodeLayout(size: SizeMode.hug()),
  );

  final gptChevron = Node(
    id: 'gpt_chevron',
    name: 'Chevron',
    type: NodeType.icon,
    props: IconProps(icon: 'chevron_right', size: 20, color: '#000000'),
    layout: NodeLayout(size: SizeMode.fixed(20, 20)),
  );

  final gptEditIcon = Node(
    id: 'gpt_edit_icon',
    name: 'Edit',
    type: NodeType.icon,
    props: IconProps(icon: 'edit', size: 24, color: '#000000'),
    layout: NodeLayout(size: SizeMode.fixed(24, 24)),
  );

  // Main chat area (scrollable)
  final gptChatArea = Node(
    id: 'gpt_chat_area',
    name: 'Chat Area',
    type: NodeType.container,
    props: ContainerProps(),
    layout: NodeLayout(
      size: SizeMode.fill(),
      autoLayout: AutoLayout(
        direction: LayoutDirection.vertical,
        padding: TokenEdgePadding.symmetric(horizontal: 16, vertical: 8),
        gap: FixedNumeric(16),
        mainAlign: MainAxisAlignment.start,
        crossAlign: CrossAxisAlignment.stretch,
      ),
    ),
    childIds: [
      'gpt_action_row_1',
      'gpt_user_message',
      'gpt_ai_response',
      'gpt_progress_card',
      'gpt_action_row_2',
    ],
  );

  // Action row (copy, speak, like, dislike)
  final gptActionRow1 = Node(
    id: 'gpt_action_row_1',
    name: 'Action Row 1',
    type: NodeType.container,
    props: ContainerProps(),
    layout: NodeLayout(
      size: SizeMode.hug(),
      autoLayout: AutoLayout(
        direction: LayoutDirection.horizontal,
        gap: FixedNumeric(16),
        mainAlign: MainAxisAlignment.start,
        crossAlign: CrossAxisAlignment.center,
      ),
    ),
    childIds: [
      'gpt_copy_icon',
      'gpt_speak_icon',
      'gpt_like_icon',
      'gpt_dislike_icon',
    ],
  );

  final gptCopyIcon = Node(
    id: 'gpt_copy_icon',
    name: 'Copy',
    type: NodeType.icon,
    props: IconProps(icon: 'content_copy', size: 20, color: '#6B7280'),
    layout: NodeLayout(size: SizeMode.fixed(20, 20)),
  );

  final gptSpeakIcon = Node(
    id: 'gpt_speak_icon',
    name: 'Speak',
    type: NodeType.icon,
    props: IconProps(icon: 'volume_up', size: 20, color: '#6B7280'),
    layout: NodeLayout(size: SizeMode.fixed(20, 20)),
  );

  final gptLikeIcon = Node(
    id: 'gpt_like_icon',
    name: 'Like',
    type: NodeType.icon,
    props: IconProps(icon: 'thumb_up_outlined', size: 20, color: '#6B7280'),
    layout: NodeLayout(size: SizeMode.fixed(20, 20)),
  );

  final gptDislikeIcon = Node(
    id: 'gpt_dislike_icon',
    name: 'Dislike',
    type: NodeType.icon,
    props: IconProps(icon: 'thumb_down_outlined', size: 20, color: '#6B7280'),
    layout: NodeLayout(size: SizeMode.fixed(20, 20)),
  );

  // User message bubble (right aligned, dark)
  final gptUserMessage = Node(
    id: 'gpt_user_message',
    name: 'User Message',
    type: NodeType.container,
    props: ContainerProps(),
    layout: NodeLayout(
      size: SizeMode.hug(),
      autoLayout: AutoLayout(
        direction: LayoutDirection.horizontal,
        mainAlign: MainAxisAlignment.end,
        crossAlign: CrossAxisAlignment.start,
      ),
    ),
    childIds: ['gpt_user_bubble'],
  );

  final gptUserBubble = Node(
    id: 'gpt_user_bubble',
    name: 'User Bubble',
    type: NodeType.container,
    props: ContainerProps(),
    layout: NodeLayout(
      size: SizeMode.hug(),
      autoLayout: AutoLayout(
        direction: LayoutDirection.vertical,
        padding: TokenEdgePadding.symmetric(horizontal: 16, vertical: 12),
        mainAlign: MainAxisAlignment.center,
        crossAlign: CrossAxisAlignment.start,
      ),
      constraints: LayoutConstraints(maxWidth: 280),
    ),
    style: NodeStyle(
      fill: SolidFill(HexColor('#2F2F2F')),
      cornerRadius: CornerRadius(
        topLeft: FixedNumeric(20),
        topRight: FixedNumeric(20),
        bottomRight: FixedNumeric(4),
        bottomLeft: FixedNumeric(20),
      ),
    ),
    childIds: ['gpt_user_text'],
  );

  final gptUserText = Node(
    id: 'gpt_user_text',
    name: 'User Text',
    type: NodeType.text,
    props: TextProps(
      text: 'yes i am interested in global trends',
      fontSize: 16,
      fontWeight: 400,
      color: '#FFFFFF',
      lineHeight: 1.4,
    ),
    layout: NodeLayout(size: SizeMode.hug()),
  );

  // AI Response (no bubble, left aligned)
  final gptAiResponse = Node(
    id: 'gpt_ai_response',
    name: 'AI Response',
    type: NodeType.container,
    props: ContainerProps(),
    layout: NodeLayout(
      size: SizeMode.hug(),
      autoLayout: AutoLayout(
        direction: LayoutDirection.vertical,
        gap: FixedNumeric(16),
        mainAlign: MainAxisAlignment.start,
        crossAlign: CrossAxisAlignment.start,
      ),
    ),
    childIds: ['gpt_ai_text'],
  );

  final gptAiText = Node(
    id: 'gpt_ai_text',
    name: 'AI Text',
    type: NodeType.text,
    props: TextProps(
      text:
          "Great! I'll explore global trends in future jobs, including emerging industries, evolving roles, and the skills expected to be in high demand over the next 5–10 years. I'll also highlight which sectors are growing due to tech innovation, climate change, and demographic shifts.\n\nI'll let you know as soon as the research is ready.",
      fontSize: 16,
      fontWeight: 400,
      color: '#000000',
      lineHeight: 1.5,
    ),
    layout: NodeLayout(size: SizeMode.hug()),
  );

  // Progress Card
  final gptProgressCard = Node(
    id: 'gpt_progress_card',
    name: 'Progress Card',
    type: NodeType.container,
    props: ContainerProps(),
    layout: NodeLayout(
      size: SizeMode.hug(),
      autoLayout: AutoLayout(
        direction: LayoutDirection.vertical,
        padding: TokenEdgePadding.allFixed(16),
        gap: FixedNumeric(12),
        mainAlign: MainAxisAlignment.start,
        crossAlign: CrossAxisAlignment.stretch,
      ),
    ),
    style: NodeStyle(
      cornerRadius: CornerRadius.circular(16),
      stroke: Stroke(
        color: HexColor('#E5E7EB'),
        width: 1,
        position: StrokePosition.inside,
      ),
    ),
    childIds: ['gpt_card_header', 'gpt_card_footer'],
  );

  final gptCardHeader = Node(
    id: 'gpt_card_header',
    name: 'Card Header',
    type: NodeType.container,
    props: ContainerProps(),
    layout: NodeLayout(
      size: SizeMode.hug(),
      autoLayout: AutoLayout(
        direction: LayoutDirection.vertical,
        gap: FixedNumeric(4),
        mainAlign: MainAxisAlignment.start,
        crossAlign: CrossAxisAlignment.start,
      ),
    ),
    childIds: ['gpt_card_title', 'gpt_card_subtitle'],
  );

  final gptCardTitle = Node(
    id: 'gpt_card_title',
    name: 'Card Title',
    type: NodeType.text,
    props: TextProps(
      text: 'Mapping out data sources',
      fontSize: 16,
      fontWeight: 600,
      color: '#000000',
    ),
    layout: NodeLayout(size: SizeMode.hug()),
  );

  final gptCardSubtitle = Node(
    id: 'gpt_card_subtitle',
    name: 'Card Subtitle',
    type: NodeType.text,
    props: TextProps(
      text: '29 sources',
      fontSize: 14,
      fontWeight: 400,
      color: '#6B7280',
    ),
    layout: NodeLayout(size: SizeMode.hug()),
  );

  final gptCardFooter = Node(
    id: 'gpt_card_footer',
    name: 'Card Footer',
    type: NodeType.container,
    props: ContainerProps(),
    layout: NodeLayout(
      size: SizeMode.hug(),
      autoLayout: AutoLayout(
        direction: LayoutDirection.horizontal,
        gap: FixedNumeric(12),
        mainAlign: MainAxisAlignment.spaceBetween,
        crossAlign: CrossAxisAlignment.center,
      ),
    ),
    childIds: ['gpt_progress_bar', 'gpt_details_btn'],
  );

  final gptProgressBar = Node(
    id: 'gpt_progress_bar',
    name: 'Progress Bar',
    type: NodeType.container,
    props: ContainerProps(),
    layout: NodeLayout(size: SizeMode.fixed(200, 6)),
    style: NodeStyle(
      fill: SolidFill(HexColor('#E5E7EB')),
      cornerRadius: CornerRadius.circular(3),
    ),
    childIds: ['gpt_progress_fill'],
  );

  final gptProgressFill = Node(
    id: 'gpt_progress_fill',
    name: 'Progress Fill',
    type: NodeType.container,
    props: ContainerProps(),
    layout: NodeLayout(size: SizeMode.fixed(60, 6)),
    style: NodeStyle(
      fill: SolidFill(HexColor('#000000')),
      cornerRadius: CornerRadius.circular(3),
    ),
  );

  final gptDetailsBtn = Node(
    id: 'gpt_details_btn',
    name: 'Details Button',
    type: NodeType.container,
    props: ContainerProps(),
    layout: NodeLayout(
      size: SizeMode.hug(),
      autoLayout: AutoLayout(
        direction: LayoutDirection.horizontal,
        padding: TokenEdgePadding.symmetric(horizontal: 16, vertical: 8),
        mainAlign: MainAxisAlignment.center,
        crossAlign: CrossAxisAlignment.center,
      ),
    ),
    style: NodeStyle(
      cornerRadius: CornerRadius.circular(20),
      stroke: Stroke(
        color: HexColor('#D1D5DB'),
        width: 1,
        position: StrokePosition.inside,
      ),
    ),
    childIds: ['gpt_details_text'],
  );

  final gptDetailsText = Node(
    id: 'gpt_details_text',
    name: 'Details Text',
    type: NodeType.text,
    props: TextProps(
      text: 'Details',
      fontSize: 14,
      fontWeight: 500,
      color: '#374151',
    ),
    layout: NodeLayout(size: SizeMode.hug()),
  );

  // Action row 2 (speaker, like, dislike)
  final gptActionRow2 = Node(
    id: 'gpt_action_row_2',
    name: 'Action Row 2',
    type: NodeType.container,
    props: ContainerProps(),
    layout: NodeLayout(
      size: SizeMode.hug(),
      autoLayout: AutoLayout(
        direction: LayoutDirection.horizontal,
        gap: FixedNumeric(16),
        mainAlign: MainAxisAlignment.start,
        crossAlign: CrossAxisAlignment.center,
      ),
    ),
    childIds: ['gpt_speaker_icon_2', 'gpt_like_icon_2', 'gpt_dislike_icon_2'],
  );

  final gptSpeakerIcon2 = Node(
    id: 'gpt_speaker_icon_2',
    name: 'Speaker',
    type: NodeType.icon,
    props: IconProps(icon: 'volume_up', size: 20, color: '#6B7280'),
    layout: NodeLayout(size: SizeMode.fixed(20, 20)),
  );

  final gptLikeIcon2 = Node(
    id: 'gpt_like_icon_2',
    name: 'Like',
    type: NodeType.icon,
    props: IconProps(icon: 'thumb_up_outlined', size: 20, color: '#6B7280'),
    layout: NodeLayout(size: SizeMode.fixed(20, 20)),
  );

  final gptDislikeIcon2 = Node(
    id: 'gpt_dislike_icon_2',
    name: 'Dislike',
    type: NodeType.icon,
    props: IconProps(icon: 'thumb_down_outlined', size: 20, color: '#6B7280'),
    layout: NodeLayout(size: SizeMode.fixed(20, 20)),
  );

  // Input Area
  final gptInputArea = Node(
    id: 'gpt_input_area',
    name: 'Input Area',
    type: NodeType.container,
    props: ContainerProps(),
    layout: NodeLayout(
      size: SizeMode.hug(),
      autoLayout: AutoLayout(
        direction: LayoutDirection.vertical,
        padding: TokenEdgePadding.symmetric(horizontal: 16, vertical: 12),
        gap: FixedNumeric(12),
        mainAlign: MainAxisAlignment.start,
        crossAlign: CrossAxisAlignment.stretch,
      ),
    ),
    style: NodeStyle(
      fill: SolidFill(HexColor('#F3F4F6')),
      cornerRadius: CornerRadius(
        topLeft: FixedNumeric(24),
        topRight: FixedNumeric(24),
        bottomLeft: FixedNumeric(0),
        bottomRight: FixedNumeric(0),
      ),
    ),
    childIds: ['gpt_input_field', 'gpt_input_actions'],
  );

  final gptInputField = Node(
    id: 'gpt_input_field',
    name: 'Input Field',
    type: NodeType.text,
    props: TextProps(
      text: 'Ask anything',
      fontSize: 16,
      fontWeight: 400,
      color: '#9CA3AF',
    ),
    layout: NodeLayout(size: SizeMode.hug()),
  );

  final gptInputActions = Node(
    id: 'gpt_input_actions',
    name: 'Input Actions',
    type: NodeType.container,
    props: ContainerProps(),
    layout: NodeLayout(
      size: SizeMode.hug(),
      autoLayout: AutoLayout(
        direction: LayoutDirection.horizontal,
        mainAlign: MainAxisAlignment.spaceBetween,
        crossAlign: CrossAxisAlignment.center,
      ),
    ),
    childIds: ['gpt_input_left', 'gpt_input_right'],
  );

  final gptInputLeft = Node(
    id: 'gpt_input_left',
    name: 'Input Left',
    type: NodeType.container,
    props: ContainerProps(),
    layout: NodeLayout(
      size: SizeMode.hug(),
      autoLayout: AutoLayout(
        direction: LayoutDirection.horizontal,
        gap: FixedNumeric(12),
        mainAlign: MainAxisAlignment.start,
        crossAlign: CrossAxisAlignment.center,
      ),
    ),
    childIds: ['gpt_plus_btn', 'gpt_sliders_btn'],
  );

  final gptPlusBtn = Node(
    id: 'gpt_plus_btn',
    name: 'Plus',
    type: NodeType.container,
    props: ContainerProps(),
    layout: NodeLayout(
      size: SizeMode.fixed(32, 32),
      autoLayout: AutoLayout(
        direction: LayoutDirection.horizontal,
        mainAlign: MainAxisAlignment.center,
        crossAlign: CrossAxisAlignment.center,
      ),
    ),
    style: NodeStyle(
      fill: SolidFill(HexColor('#FFFFFF')),
      cornerRadius: CornerRadius.circular(16),
    ),
    childIds: ['gpt_plus_icon'],
  );

  final gptPlusIcon = Node(
    id: 'gpt_plus_icon',
    name: 'Plus Icon',
    type: NodeType.icon,
    props: IconProps(icon: 'add', size: 20, color: '#374151'),
    layout: NodeLayout(size: SizeMode.fixed(20, 20)),
  );

  final gptSlidersBtn = Node(
    id: 'gpt_sliders_btn',
    name: 'Sliders',
    type: NodeType.container,
    props: ContainerProps(),
    layout: NodeLayout(
      size: SizeMode.fixed(32, 32),
      autoLayout: AutoLayout(
        direction: LayoutDirection.horizontal,
        mainAlign: MainAxisAlignment.center,
        crossAlign: CrossAxisAlignment.center,
      ),
    ),
    style: NodeStyle(
      fill: SolidFill(HexColor('#FFFFFF')),
      cornerRadius: CornerRadius.circular(16),
    ),
    childIds: ['gpt_sliders_icon'],
  );

  final gptSlidersIcon = Node(
    id: 'gpt_sliders_icon',
    name: 'Sliders Icon',
    type: NodeType.icon,
    props: IconProps(icon: 'tune', size: 20, color: '#374151'),
    layout: NodeLayout(size: SizeMode.fixed(20, 20)),
  );

  final gptInputRight = Node(
    id: 'gpt_input_right',
    name: 'Input Right',
    type: NodeType.container,
    props: ContainerProps(),
    layout: NodeLayout(
      size: SizeMode.hug(),
      autoLayout: AutoLayout(
        direction: LayoutDirection.horizontal,
        gap: FixedNumeric(8),
        mainAlign: MainAxisAlignment.end,
        crossAlign: CrossAxisAlignment.center,
      ),
    ),
    childIds: ['gpt_mic_btn', 'gpt_wave_btn'],
  );

  final gptMicBtn = Node(
    id: 'gpt_mic_btn',
    name: 'Mic',
    type: NodeType.container,
    props: ContainerProps(),
    layout: NodeLayout(
      size: SizeMode.fixed(32, 32),
      autoLayout: AutoLayout(
        direction: LayoutDirection.horizontal,
        mainAlign: MainAxisAlignment.center,
        crossAlign: CrossAxisAlignment.center,
      ),
    ),
    style: NodeStyle(
      fill: SolidFill(HexColor('#FFFFFF')),
      cornerRadius: CornerRadius.circular(16),
    ),
    childIds: ['gpt_mic_icon'],
  );

  final gptMicIcon = Node(
    id: 'gpt_mic_icon',
    name: 'Mic Icon',
    type: NodeType.icon,
    props: IconProps(icon: 'mic', size: 20, color: '#374151'),
    layout: NodeLayout(size: SizeMode.fixed(20, 20)),
  );

  final gptWaveBtn = Node(
    id: 'gpt_wave_btn',
    name: 'Wave',
    type: NodeType.container,
    props: ContainerProps(),
    layout: NodeLayout(
      size: SizeMode.fixed(32, 32),
      autoLayout: AutoLayout(
        direction: LayoutDirection.horizontal,
        mainAlign: MainAxisAlignment.center,
        crossAlign: CrossAxisAlignment.center,
      ),
    ),
    style: NodeStyle(
      fill: SolidFill(HexColor('#000000')),
      cornerRadius: CornerRadius.circular(16),
    ),
    childIds: ['gpt_wave_icon'],
  );

  final gptWaveIcon = Node(
    id: 'gpt_wave_icon',
    name: 'Wave Icon',
    type: NodeType.icon,
    props: IconProps(icon: 'graphic_eq', size: 20, color: '#FFFFFF'),
    layout: NodeLayout(size: SizeMode.fixed(20, 20)),
  );

  // Footer with home indicator and ChatGPT branding
  final gptFooter = Node(
    id: 'gpt_footer',
    name: 'Footer',
    type: NodeType.container,
    props: ContainerProps(),
    layout: NodeLayout(
      size: SizeMode.fixed(393, 20),
      autoLayout: AutoLayout(
        direction: LayoutDirection.vertical,
        padding: TokenEdgePadding.symmetric(horizontal: 16, vertical: 2),
        gap: FixedNumeric(12),
        mainAlign: MainAxisAlignment.start,
        crossAlign: CrossAxisAlignment.center,
      ),
    ),
    style: NodeStyle(fill: SolidFill(HexColor('#F3F4F6'))),
    childIds: ['gpt_home_indicator', 'gpt_branding'],
  );

  final gptHomeIndicator = Node(
    id: 'gpt_home_indicator',
    name: 'Home Indicator',
    type: NodeType.container,
    props: ContainerProps(),
    layout: NodeLayout(size: SizeMode.fixed(134, 5)),
    style: NodeStyle(
      fill: SolidFill(HexColor('#000000')),
      cornerRadius: CornerRadius.circular(3),
    ),
  );

  // =========================================================================
  // Component Demo Frame - Showcases Components, Instances, and Slots
  // =========================================================================
  final componentDemoFrame = Frame(
    id: 'frame_component_demo',
    name: 'Component Demo',
    rootNodeId: 'demo_root',
    canvas: const CanvasPlacement(
      position: Offset(600, 100),
      size: Size(400, 600),
    ),
    createdAt: now,
    updatedAt: now,
  );

  // Root container for demo
  final demoRoot = Node(
    id: 'demo_root',
    name: 'Demo Root',
    type: NodeType.container,
    props: ContainerProps(),
    layout: NodeLayout(
      size: SizeMode.fixed(400, 600),
      autoLayout: AutoLayout(
        direction: LayoutDirection.vertical,
        padding: TokenEdgePadding.allFixed(24),
        gap: FixedNumeric(16),
        mainAlign: MainAxisAlignment.start,
        crossAlign: CrossAxisAlignment.stretch,
      ),
    ),
    style: NodeStyle(fill: SolidFill(HexColor('#F5F5F5'))),
    childIds: [
      'demo_title',
      'demo_section_components',
      'demo_button_row',
      'demo_section_slots',
      'demo_card_instance',
      'demo_card_instance_2',
    ],
  );

  final demoTitle = Node(
    id: 'demo_title',
    name: 'Demo Title',
    type: NodeType.text,
    props: TextProps(
      text: 'Component System Demo',
      fontSize: 24,
      fontWeight: 700,
      color: '#1A1A1A',
    ),
    layout: NodeLayout(size: SizeMode.hug()),
  );

  // Section header for components
  final demoSectionComponents = Node(
    id: 'demo_section_components',
    name: 'Section: Components',
    type: NodeType.text,
    props: TextProps(
      text: 'Button Instances (with overrides)',
      fontSize: 14,
      fontWeight: 500,
      color: '#666666',
    ),
    layout: NodeLayout(size: SizeMode.hug()),
  );

  // Row containing button instances
  final demoButtonRow = Node(
    id: 'demo_button_row',
    name: 'Button Row',
    type: NodeType.container,
    props: ContainerProps(),
    layout: NodeLayout(
      size: SizeMode.hug(),
      autoLayout: AutoLayout(
        direction: LayoutDirection.horizontal,
        gap: FixedNumeric(12),
        mainAlign: MainAxisAlignment.start,
        crossAlign: CrossAxisAlignment.center,
      ),
    ),
    childIds: ['inst_primary_btn', 'inst_secondary_btn', 'inst_icon_btn'],
  );

  // Instance 1: Primary button (using typed params - label overridden)
  final instPrimaryBtn = Node(
    id: 'inst_primary_btn',
    name: 'Primary Button',
    type: NodeType.instance,
    props: InstanceProps(
      componentId: 'comp_button',
      paramOverrides: {
        'label': 'Primary', // This will show override indicator
      },
    ),
    layout: NodeLayout(size: SizeMode.hug()),
  );

  // Instance 2: Secondary button (using typed params - multiple overrides)
  final instSecondaryBtn = Node(
    id: 'inst_secondary_btn',
    name: 'Secondary Button',
    type: NodeType.instance,
    props: InstanceProps(
      componentId: 'comp_button',
      paramOverrides: {
        'label': 'Secondary',
        'backgroundColor': '#34C759', // Green instead of blue
        'opacity': 0.8,
      },
    ),
    layout: NodeLayout(size: SizeMode.hug()),
  );

  // Instance 3: Icon button (with icon)
  final instIconBtn = Node(
    id: 'inst_icon_btn',
    name: 'Icon Button',
    type: NodeType.instance,
    props: InstanceProps(
      componentId: 'comp_icon_button',
      overrides: {
        'icon_btn_icon': {
          'props': {'icon': 'favorite'},
        },
      },
    ),
    layout: NodeLayout(size: SizeMode.hug()),
  );

  // Section header for slots
  final demoSectionSlots = Node(
    id: 'demo_section_slots',
    name: 'Section: Slots',
    type: NodeType.text,
    props: TextProps(
      text: 'Card with Slot (placeholder)',
      fontSize: 14,
      fontWeight: 500,
      color: '#666666',
    ),
    layout: NodeLayout(size: SizeMode.hug()),
  );

  // Instance of card component (which contains a slot WITH CONTENT)
  final demoCardInstance = Node(
    id: 'demo_card_instance',
    name: 'Card Instance',
    type: NodeType.instance,
    props: InstanceProps(
      componentId: 'comp_card',
      paramOverrides: {
        'title': 'Card with Slot Content',
        'subtitle': 'The blue area below is injected slot content!',
      },
      slots: {'content': SlotAssignment(rootNodeId: 'slot_content_root')},
    ),
    layout: NodeLayout(size: SizeMode.hug()),
  );

  // Slot content - this is injected into the card's content slot
  // Note: ownerInstanceId links this to the card instance for lifecycle management
  final slotContentRoot = Node(
    id: 'slot_content_root',
    name: 'Slot Content',
    type: NodeType.container,
    props: ContainerProps(),
    layout: NodeLayout(
      size: SizeMode.hug(),
      autoLayout: AutoLayout(
        direction: LayoutDirection.vertical,
        padding: TokenEdgePadding.allFixed(12),
        gap: FixedNumeric(8),
        mainAlign: MainAxisAlignment.center,
        crossAlign: CrossAxisAlignment.center,
      ),
    ),
    style: NodeStyle(
      fill: SolidFill(HexColor('#E3F2FD')),
      cornerRadius: CornerRadius.circular(8),
    ),
    ownerInstanceId: 'demo_card_instance',
    childIds: ['slot_content_icon', 'slot_content_text'],
  );

  final slotContentIcon = Node(
    id: 'slot_content_icon',
    name: 'Content Icon',
    type: NodeType.icon,
    props: IconProps(icon: 'check_circle', size: 32, color: '#1976D2'),
    layout: NodeLayout(size: SizeMode.fixed(32, 32)),
    ownerInstanceId: 'demo_card_instance',
  );

  final slotContentText = Node(
    id: 'slot_content_text',
    name: 'Content Text',
    type: NodeType.text,
    props: TextProps(
      text: 'This content was injected into the slot!',
      fontSize: 14,
      fontWeight: 500,
      color: '#1976D2',
      textAlign: TextAlign.center,
    ),
    layout: NodeLayout(size: SizeMode.hug()),
    ownerInstanceId: 'demo_card_instance',
  );

  // Second card instance WITHOUT slot content (shows empty slot placeholder)
  final demoCardInstance2 = Node(
    id: 'demo_card_instance_2',
    name: 'Card (Empty Slot)',
    type: NodeType.instance,
    props: InstanceProps(
      componentId: 'comp_card',
      paramOverrides: {
        'title': 'Card with Empty Slot',
        'subtitle': 'The gray area below is the slot placeholder',
      },
      // No slots assignment - uses empty placeholder
    ),
    layout: NodeLayout(size: SizeMode.hug()),
  );

  // =========================================================================
  // Component Frames (for editing components on canvas)
  // =========================================================================

  // Button Component Frame
  final buttonComponentFrame = Frame(
    id: 'frame_comp_button',
    name: 'Button',
    rootNodeId: 'comp_button::btn_root',
    componentId: 'comp_button', // Links this frame to the component
    canvas: const CanvasPlacement(
      position: Offset(1050, 100),
      size: Size(150, 50),
    ),
    createdAt: now,
    updatedAt: now,
  );

  // Card Component Frame
  final cardComponentFrame = Frame(
    id: 'frame_comp_card',
    name: 'Card',
    rootNodeId: 'comp_card::card_root',
    componentId: 'comp_card', // Links this frame to the component
    canvas: const CanvasPlacement(
      position: Offset(1050, 200),
      size: Size(250, 200),
    ),
    createdAt: now,
    updatedAt: now,
  );

  // =========================================================================
  // Component Definitions
  // =========================================================================

  // Button Component Definition (with typed params for Phase 2 testing)
  final buttonComponent = ComponentDef(
    id: 'comp_button',
    name: 'Button',
    description: 'A simple button with label',
    rootNodeId: 'comp_button::btn_root',
    params: [
      // Text parameter - binds to label's text prop
      ComponentParamDef(
        key: 'label',
        type: ParamType.string,
        defaultValue: 'Click Me',
        group: 'Content',
        binding: ParamBinding(
          targetTemplateUid: 'btn_label',
          bucket: OverrideBucket.props,
          field: ParamField.text,
        ),
      ),
      // Color parameter - binds to root's fill color
      ComponentParamDef(
        key: 'backgroundColor',
        type: ParamType.color,
        defaultValue: '#007AFF',
        group: 'Style',
        binding: ParamBinding(
          targetTemplateUid: 'btn_root',
          bucket: OverrideBucket.style,
          field: ParamField.fillColor,
        ),
      ),
      // Number parameter - binds to root's corner radius
      ComponentParamDef(
        key: 'cornerRadius',
        type: ParamType.number,
        defaultValue: 8,
        group: 'Style',
        binding: ParamBinding(
          targetTemplateUid: 'btn_root',
          bucket: OverrideBucket.style,
          field: ParamField.cornerRadius,
        ),
      ),
      // Opacity parameter
      ComponentParamDef(
        key: 'opacity',
        type: ParamType.number,
        defaultValue: 1.0,
        group: 'Style',
        binding: ParamBinding(
          targetTemplateUid: 'btn_root',
          bucket: OverrideBucket.style,
          field: ParamField.opacity,
        ),
      ),
    ],
    // ignore: deprecated_member_use_from_same_package
    exposedProps: {'label': 'Click Me'},
    createdAt: now,
    updatedAt: now,
  );

  // Button component nodes (source-namespaced)
  final btnRoot = Node(
    id: 'comp_button::btn_root',
    name: 'Button Container',
    type: NodeType.container,
    props: ContainerProps(),
    layout: NodeLayout(
      size: SizeMode.hug(),
      autoLayout: AutoLayout(
        direction: LayoutDirection.horizontal,
        padding: TokenEdgePadding.symmetric(horizontal: 16, vertical: 10),
        mainAlign: MainAxisAlignment.center,
        crossAlign: CrossAxisAlignment.center,
      ),
    ),
    style: NodeStyle(
      fill: SolidFill(HexColor('#007AFF')),
      cornerRadius: CornerRadius.circular(8),
    ),
    sourceComponentId: 'comp_button',
    templateUid: 'btn_root',
    childIds: ['comp_button::btn_label'],
  );

  final btnLabel = Node(
    id: 'comp_button::btn_label',
    name: 'Button Label',
    type: NodeType.text,
    props: TextProps(
      text: 'Click Me',
      fontSize: 14,
      fontWeight: 600,
      color: '#FFFFFF',
    ),
    layout: NodeLayout(size: SizeMode.hug()),
    sourceComponentId: 'comp_button',
    templateUid: 'btn_label',
  );

  // Icon Button Component Definition
  final iconButtonComponent = ComponentDef(
    id: 'comp_icon_button',
    name: 'Icon Button',
    description: 'A button with an icon',
    rootNodeId: 'comp_icon_button::icon_btn_root',
    exposedProps: {'icon': 'star'},
    createdAt: now,
    updatedAt: now,
  );

  // Icon Button component nodes (source-namespaced)
  final iconBtnRoot = Node(
    id: 'comp_icon_button::icon_btn_root',
    name: 'Icon Button Container',
    type: NodeType.container,
    props: ContainerProps(),
    layout: NodeLayout(
      size: SizeMode.fixed(44, 44),
      autoLayout: AutoLayout(
        direction: LayoutDirection.horizontal,
        mainAlign: MainAxisAlignment.center,
        crossAlign: CrossAxisAlignment.center,
      ),
    ),
    style: NodeStyle(
      fill: SolidFill(HexColor('#FF3B30')),
      cornerRadius: CornerRadius.circular(22),
    ),
    sourceComponentId: 'comp_icon_button',
    templateUid: 'icon_btn_root',
    childIds: ['comp_icon_button::icon_btn_icon'],
  );

  final iconBtnIcon = Node(
    id: 'comp_icon_button::icon_btn_icon',
    name: 'Button Icon',
    type: NodeType.icon,
    props: IconProps(icon: 'star', size: 20, color: '#FFFFFF'),
    layout: NodeLayout(size: SizeMode.fixed(20, 20)),
    sourceComponentId: 'comp_icon_button',
    templateUid: 'icon_btn_icon',
  );

  // Card Component Definition (with a slot and typed params!)
  final cardComponent = ComponentDef(
    id: 'comp_card',
    name: 'Card',
    description: 'A card component with title, subtitle, and content slot',
    rootNodeId: 'comp_card::card_root',
    params: [
      // Title parameter
      ComponentParamDef(
        key: 'title',
        type: ParamType.string,
        defaultValue: 'Card Title',
        group: 'Content',
        binding: ParamBinding(
          targetTemplateUid: 'card_title',
          bucket: OverrideBucket.props,
          field: ParamField.text,
        ),
      ),
      // Subtitle parameter
      ComponentParamDef(
        key: 'subtitle',
        type: ParamType.string,
        defaultValue: 'Card subtitle text',
        group: 'Content',
        binding: ParamBinding(
          targetTemplateUid: 'card_subtitle',
          bucket: OverrideBucket.props,
          field: ParamField.text,
        ),
      ),
      // Card background color
      ComponentParamDef(
        key: 'cardBackground',
        type: ParamType.color,
        defaultValue: '#FFFFFF',
        group: 'Style',
        binding: ParamBinding(
          targetTemplateUid: 'card_root',
          bucket: OverrideBucket.style,
          field: ParamField.fillColor,
        ),
      ),
      // Card corner radius
      ComponentParamDef(
        key: 'cardRadius',
        type: ParamType.number,
        defaultValue: 12,
        group: 'Style',
        binding: ParamBinding(
          targetTemplateUid: 'card_root',
          bucket: OverrideBucket.style,
          field: ParamField.cornerRadius,
        ),
      ),
    ],
    // ignore: deprecated_member_use_from_same_package
    exposedProps: {'title': 'Card Title', 'subtitle': 'Card subtitle text'},
    createdAt: now,
    updatedAt: now,
  );

  // Card component nodes (source-namespaced)
  final cardRoot = Node(
    id: 'comp_card::card_root',
    name: 'Card Container',
    type: NodeType.container,
    props: ContainerProps(),
    layout: NodeLayout(
      size: SizeMode.hug(),
      autoLayout: AutoLayout(
        direction: LayoutDirection.vertical,
        padding: TokenEdgePadding.allFixed(16),
        gap: FixedNumeric(12),
        mainAlign: MainAxisAlignment.start,
        crossAlign: CrossAxisAlignment.stretch,
      ),
      constraints: LayoutConstraints(minWidth: 200),
    ),
    style: NodeStyle(
      fill: SolidFill(HexColor('#FFFFFF')),
      cornerRadius: CornerRadius.circular(12),
      shadow: Shadow(color: HexColor('#00000020'), blur: 8, offsetY: 2),
    ),
    sourceComponentId: 'comp_card',
    templateUid: 'card_root',
    childIds: ['comp_card::card_header', 'comp_card::card_content_slot'],
  );

  final cardHeader = Node(
    id: 'comp_card::card_header',
    name: 'Card Header',
    type: NodeType.container,
    props: ContainerProps(),
    layout: NodeLayout(
      size: SizeMode.hug(),
      autoLayout: AutoLayout(
        direction: LayoutDirection.vertical,
        gap: FixedNumeric(4),
        mainAlign: MainAxisAlignment.start,
        crossAlign: CrossAxisAlignment.start,
      ),
    ),
    sourceComponentId: 'comp_card',
    templateUid: 'card_header',
    childIds: ['comp_card::card_title', 'comp_card::card_subtitle'],
  );

  final cardTitle = Node(
    id: 'comp_card::card_title',
    name: 'Card Title',
    type: NodeType.text,
    props: TextProps(
      text: 'Card Title',
      fontSize: 18,
      fontWeight: 600,
      color: '#1A1A1A',
    ),
    layout: NodeLayout(size: SizeMode.hug()),
    sourceComponentId: 'comp_card',
    templateUid: 'card_title',
  );

  final cardSubtitle = Node(
    id: 'comp_card::card_subtitle',
    name: 'Card Subtitle',
    type: NodeType.text,
    props: TextProps(
      text: 'Card subtitle text',
      fontSize: 14,
      fontWeight: 400,
      color: '#666666',
    ),
    layout: NodeLayout(size: SizeMode.hug()),
    sourceComponentId: 'comp_card',
    templateUid: 'card_subtitle',
  );

  // This is the SLOT - a placeholder for content injection
  final cardContentSlot = Node(
    id: 'comp_card::card_content_slot',
    name: 'Content Slot',
    type: NodeType.slot,
    props: SlotProps(
      slotName: 'content',
      defaultContentId: null, // No default content
    ),
    layout: NodeLayout(
      size: SizeMode.fixed(double.infinity, 60),
      autoLayout: AutoLayout(
        direction: LayoutDirection.vertical,
        mainAlign: MainAxisAlignment.center,
        crossAlign: CrossAxisAlignment.center,
      ),
    ),
    style: NodeStyle(
      fill: SolidFill(HexColor('#F0F0F0')),
      cornerRadius: CornerRadius.circular(8),
      stroke: Stroke(
        color: HexColor('#CCCCCC'),
        width: 1,
        position: StrokePosition.inside,
      ),
    ),
    sourceComponentId: 'comp_card',
    templateUid: 'card_content_slot',
  );

  return EditorDocument.empty(documentId: 'demo_doc')
      // Component Demo Frame
      .withFrame(componentDemoFrame)
      .withNode(demoRoot)
      .withNode(demoTitle)
      .withNode(demoSectionComponents)
      .withNode(demoButtonRow)
      .withNode(instPrimaryBtn)
      .withNode(instSecondaryBtn)
      .withNode(instIconBtn)
      .withNode(demoSectionSlots)
      .withNode(demoCardInstance)
      .withNode(demoCardInstance2)
      // Slot content nodes (owned by demo_card_instance)
      .withNode(slotContentRoot)
      .withNode(slotContentIcon)
      .withNode(slotContentText)
      // Button Component nodes
      .withNode(btnRoot)
      .withNode(btnLabel)
      .withComponent(buttonComponent)
      .withFrame(buttonComponentFrame) // Component frame for Button
      // Icon Button Component nodes
      .withNode(iconBtnRoot)
      .withNode(iconBtnIcon)
      .withComponent(iconButtonComponent)
      // Card Component nodes (with slot)
      .withNode(cardRoot)
      .withNode(cardHeader)
      .withNode(cardTitle)
      .withNode(cardSubtitle)
      .withNode(cardContentSlot)
      .withComponent(cardComponent)
      .withFrame(cardComponentFrame) // Component frame for Card
      // ChatGPT Frame
      .withFrame(chatGptFrame)
      .withNode(gptRoot)
      .withNode(gptStatusBar)
      .withNode(gptTime)
      .withNode(gptStatusIcons)
      .withNode(gptSignal)
      .withNode(gptWifi)
      .withNode(gptBattery)
      .withNode(gptHeader)
      .withNode(gptMenuIcon)
      .withNode(gptTitleRow)
      .withNode(gptTitleText)
      .withNode(gptChevron)
      .withNode(gptEditIcon)
      .withNode(gptChatArea)
      .withNode(gptActionRow1)
      .withNode(gptCopyIcon)
      .withNode(gptSpeakIcon)
      .withNode(gptLikeIcon)
      .withNode(gptDislikeIcon)
      .withNode(gptUserMessage)
      .withNode(gptUserBubble)
      .withNode(gptUserText)
      .withNode(gptAiResponse)
      .withNode(gptAiText)
      .withNode(gptProgressCard)
      .withNode(gptCardHeader)
      .withNode(gptCardTitle)
      .withNode(gptCardSubtitle)
      .withNode(gptCardFooter)
      .withNode(gptProgressBar)
      .withNode(gptProgressFill)
      .withNode(gptDetailsBtn)
      .withNode(gptDetailsText)
      .withNode(gptActionRow2)
      .withNode(gptSpeakerIcon2)
      .withNode(gptLikeIcon2)
      .withNode(gptDislikeIcon2)
      .withNode(gptInputArea)
      .withNode(gptInputField)
      .withNode(gptInputActions)
      .withNode(gptInputLeft)
      .withNode(gptPlusBtn)
      .withNode(gptPlusIcon)
      .withNode(gptSlidersBtn)
      .withNode(gptSlidersIcon)
      .withNode(gptInputRight)
      .withNode(gptMicBtn)
      .withNode(gptMicIcon)
      .withNode(gptWaveBtn)
      .withNode(gptWaveIcon)
      .withNode(gptFooter)
      .withNode(gptHomeIndicator);
}
