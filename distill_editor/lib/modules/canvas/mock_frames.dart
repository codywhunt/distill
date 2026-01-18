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
      position: Offset(1400, 100),
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

  return EditorDocument.empty(documentId: 'demo_doc')
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
