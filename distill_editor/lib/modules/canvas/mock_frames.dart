/// Original ChatGPT and iMessage clone demo frames
/// Clean, modern designs showcasing canvas capabilities

import 'dart:ui';
import '../../src/free_design/free_design.dart';

/// Create a demo document with sample frames and nodes.
/// Features minimalist, Apple-inspired design (2 sample frames for review).
EditorDocument createMinimalDemoFrames() {
  final now = DateTime.now();

  // =========================================================================
  // FRAME 1: ChatGPT Light Mode - Ultra-minimal AI chat interface
  // =========================================================================

  final chatGptLight = Frame(
    id: 'chatgpt_light',
    name: 'ChatGPT Light',
    rootNodeId: 'cgl_root',
    canvas: const CanvasPlacement(
      position: Offset(100, 100),
      size: Size(390, 844),
    ),
    createdAt: now,
    updatedAt: now,
  );

  // Root container
  final cglRoot = Node(
    id: 'cgl_root',
    name: 'Screen',
    type: NodeType.container,
    props: ContainerProps(),
    layout: NodeLayout(
      size: SizeMode.fixed(375, 812),
      autoLayout: AutoLayout(
        direction: LayoutDirection.vertical,
        mainAlign: MainAxisAlignment.start,
        crossAlign: CrossAxisAlignment.stretch,
      ),
    ),
    style: NodeStyle(
      fill: SolidFill(HexColor('#F8F9FA')),
    ),
    childIds: ['app_bar', 'content_scroll'],
  );

  // App Bar
  final appBar = Node(
    id: 'app_bar',
    name: 'App Bar',
    type: NodeType.container,
    props: ContainerProps(),
    layout: NodeLayout(
      size: SizeMode.fixed(375, 56),
      autoLayout: AutoLayout(
        direction: LayoutDirection.horizontal,
        padding: TokenEdgePadding.symmetric(horizontal: 16, vertical: 8),
        gap: FixedNumeric(16),
        mainAlign: MainAxisAlignment.spaceBetween,
        crossAlign: CrossAxisAlignment.center,
      ),
    ),
    style: NodeStyle(
      fill: SolidFill(HexColor('#FFFFFF')),
      stroke: Stroke(
        color: HexColor('#E0E0E0'),
        width: 1,
        position: StrokePosition.inside,
      ),
    ),
    childIds: ['back_button', 'app_bar_title', 'menu_button'],
  );

  final backButton = Node(
    id: 'back_button',
    name: 'Back Button',
    type: NodeType.icon,
    props: IconProps(
      icon: 'arrow_back',
      size: 24,
      color: '#212121',
    ),
    layout: NodeLayout(
      size: SizeMode.fixed(40, 40),
    ),
  );

  final appBarTitle = Node(
    id: 'app_bar_title',
    name: 'Profile Title',
    type: NodeType.text,
    props: TextProps(
      text: 'Profile',
      fontSize: 20,
      fontWeight: 600,
      color: '#212121',
    ),
    layout: NodeLayout(
      size: SizeMode.hug(),
    ),
  );

  final menuButton = Node(
    id: 'menu_button',
    name: 'Menu Button',
    type: NodeType.icon,
    props: IconProps(
      icon: 'more_vert',
      size: 24,
      color: '#212121',
    ),
    layout: NodeLayout(
      size: SizeMode.fixed(40, 40),
    ),
  );

  // Content scroll area
  final contentScroll = Node(
    id: 'content_scroll',
    name: 'Content',
    type: NodeType.container,
    props: ContainerProps(scrollDirection: 'vertical'),
    layout: NodeLayout(
      size: SizeMode.fill(),
      autoLayout: AutoLayout(
        direction: LayoutDirection.vertical,
        padding: TokenEdgePadding.allFixed(20),
        gap: FixedNumeric(24),
        mainAlign: MainAxisAlignment.start,
        crossAlign: CrossAxisAlignment.stretch,
      ),
    ),
    childIds: [
      'profile_header',
      'stats_section',
      'actions_section',
      'content_section',
    ],
  );

  // Profile Header Section
  final profileHeader = Node(
    id: 'profile_header',
    name: 'Profile Header',
    type: NodeType.container,
    props: ContainerProps(),
    layout: NodeLayout(
      size: SizeMode.hug(),
      autoLayout: AutoLayout(
        direction: LayoutDirection.vertical,
        gap: FixedNumeric(16),
        mainAlign: MainAxisAlignment.start,
        crossAlign: CrossAxisAlignment.center,
      ),
    ),
    childIds: ['avatar', 'profile_info'],
  );

  // Avatar
  final avatar = Node(
    id: 'avatar',
    name: 'Avatar',
    type: NodeType.container,
    props: ContainerProps(),
    layout: NodeLayout(
      size: SizeMode.fixed(96, 96),
    ),
    style: NodeStyle(
      fill: SolidFill(HexColor('#9C27B0')),
      cornerRadius: CornerRadius.circular(48),
      stroke: Stroke(
        color: HexColor('#FFFFFF'),
        width: 4,
        position: StrokePosition.outside,
      ),
    ),
  );

  // Profile Info
  final profileInfo = Node(
    id: 'profile_info',
    name: 'Profile Info',
    type: NodeType.container,
    props: ContainerProps(),
    layout: NodeLayout(
      size: SizeMode.hug(),
      autoLayout: AutoLayout(
        direction: LayoutDirection.vertical,
        gap: FixedNumeric(8),
        mainAlign: MainAxisAlignment.start,
        crossAlign: CrossAxisAlignment.center,
      ),
    ),
    childIds: ['name_text', 'username_text', 'bio_text'],
  );

  final nameText = Node(
    id: 'name_text',
    name: 'Name',
    type: NodeType.text,
    props: TextProps(
      text: 'Sarah Anderson',
      fontSize: 24,
      fontWeight: 700,
      color: '#212121',
    ),
    layout: NodeLayout(
      size: SizeMode.hug(),
    ),
  );

  final usernameText = Node(
    id: 'username_text',
    name: 'Username',
    type: NodeType.text,
    props: TextProps(
      text: '@sarah_designs',
      fontSize: 16,
      fontWeight: 400,
      color: '#757575',
    ),
    layout: NodeLayout(
      size: SizeMode.hug(),
    ),
  );

  final bioText = Node(
    id: 'bio_text',
    name: 'Bio',
    type: NodeType.text,
    props: TextProps(
      text:
          'Product designer crafting delightful experiences.\nLove coffee, design systems, and dogs.',
      fontSize: 14,
      fontWeight: 400,
      color: '#424242',
      textAlign: TextAlign.center,
      lineHeight: 1.5,
    ),
    layout: NodeLayout(
      size: SizeMode.hug(),
    ),
  );

  // Stats Section
  final statsSection = Node(
    id: 'stats_section',
    name: 'Stats',
    type: NodeType.container,
    props: ContainerProps(),
    layout: NodeLayout(
      size: SizeMode.hug(),
      autoLayout: AutoLayout(
        direction: LayoutDirection.horizontal,
        gap: FixedNumeric(8),
        mainAlign: MainAxisAlignment.start,
        crossAlign: CrossAxisAlignment.start,
      ),
    ),
    childIds: ['stat_followers', 'stat_following', 'stat_posts'],
  );

  final statFollowers = Node(
    id: 'stat_followers',
    name: 'Followers',
    type: NodeType.container,
    props: ContainerProps(),
    layout: NodeLayout(
      size: SizeMode.fixed(105, 80),
      autoLayout: AutoLayout(
        direction: LayoutDirection.vertical,
        padding: TokenEdgePadding.allFixed(12),
        gap: FixedNumeric(4),
        mainAlign: MainAxisAlignment.center,
        crossAlign: CrossAxisAlignment.center,
      ),
    ),
    style: NodeStyle(
      fill: SolidFill(HexColor('#FFFFFF')),
      cornerRadius: CornerRadius.circular(12),
      stroke: Stroke(
        color: HexColor('#E0E0E0'),
        width: 1,
        position: StrokePosition.inside,
      ),
    ),
    childIds: ['stat_followers_num', 'stat_followers_label'],
  );

  final statFollowersNum = Node(
    id: 'stat_followers_num',
    name: 'Followers Number',
    type: NodeType.text,
    props: TextProps(
      text: '2.5K',
      fontSize: 20,
      fontWeight: 700,
      color: '#212121',
    ),
    layout: NodeLayout(
      size: SizeMode.hug(),
    ),
  );

  final statFollowersLabel = Node(
    id: 'stat_followers_label',
    name: 'Followers Label',
    type: NodeType.text,
    props: TextProps(
      text: 'Followers',
      fontSize: 12,
      fontWeight: 400,
      color: '#757575',
    ),
    layout: NodeLayout(
      size: SizeMode.hug(),
    ),
  );

  final statFollowing = Node(
    id: 'stat_following',
    name: 'Following',
    type: NodeType.container,
    props: ContainerProps(),
    layout: NodeLayout(
      size: SizeMode.fixed(105, 80),
      autoLayout: AutoLayout(
        direction: LayoutDirection.vertical,
        padding: TokenEdgePadding.allFixed(12),
        gap: FixedNumeric(4),
        mainAlign: MainAxisAlignment.center,
        crossAlign: CrossAxisAlignment.center,
      ),
    ),
    style: NodeStyle(
      fill: SolidFill(HexColor('#FFFFFF')),
      cornerRadius: CornerRadius.circular(12),
      stroke: Stroke(
        color: HexColor('#E0E0E0'),
        width: 1,
        position: StrokePosition.inside,
      ),
    ),
    childIds: ['stat_following_num', 'stat_following_label'],
  );

  final statFollowingNum = Node(
    id: 'stat_following_num',
    name: 'Following Number',
    type: NodeType.text,
    props: TextProps(
      text: '342',
      fontSize: 20,
      fontWeight: 700,
      color: '#212121',
    ),
    layout: NodeLayout(
      size: SizeMode.hug(),
    ),
  );

  final statFollowingLabel = Node(
    id: 'stat_following_label',
    name: 'Following Label',
    type: NodeType.text,
    props: TextProps(
      text: 'Following',
      fontSize: 12,
      fontWeight: 400,
      color: '#757575',
    ),
    layout: NodeLayout(
      size: SizeMode.hug(),
    ),
  );

  final statPosts = Node(
    id: 'stat_posts',
    name: 'Posts',
    type: NodeType.container,
    props: ContainerProps(),
    layout: NodeLayout(
      size: SizeMode.fixed(105, 80),
      autoLayout: AutoLayout(
        direction: LayoutDirection.vertical,
        padding: TokenEdgePadding.allFixed(12),
        gap: FixedNumeric(4),
        mainAlign: MainAxisAlignment.center,
        crossAlign: CrossAxisAlignment.center,
      ),
    ),
    style: NodeStyle(
      fill: SolidFill(HexColor('#FFFFFF')),
      cornerRadius: CornerRadius.circular(12),
      stroke: Stroke(
        color: HexColor('#E0E0E0'),
        width: 1,
        position: StrokePosition.inside,
      ),
    ),
    childIds: ['stat_posts_num', 'stat_posts_label'],
  );

  final statPostsNum = Node(
    id: 'stat_posts_num',
    name: 'Posts Number',
    type: NodeType.text,
    props: TextProps(
      text: '128',
      fontSize: 20,
      fontWeight: 700,
      color: '#212121',
    ),
    layout: NodeLayout(
      size: SizeMode.hug(),
    ),
  );

  final statPostsLabel = Node(
    id: 'stat_posts_label',
    name: 'Posts Label',
    type: NodeType.text,
    props: TextProps(
      text: 'Posts',
      fontSize: 12,
      fontWeight: 400,
      color: '#757575',
    ),
    layout: NodeLayout(
      size: SizeMode.hug(),
    ),
  );

  // Actions Section
  final actionsSection = Node(
    id: 'actions_section',
    name: 'Actions',
    type: NodeType.container,
    props: ContainerProps(),
    layout: NodeLayout(
      size: SizeMode.hug(),
      autoLayout: AutoLayout(
        direction: LayoutDirection.horizontal,
        gap: FixedNumeric(8),
        mainAlign: MainAxisAlignment.start,
        crossAlign: CrossAxisAlignment.center,
      ),
    ),
    childIds: ['follow_button', 'message_button', 'share_button'],
  );

  final followButton = Node(
    id: 'follow_button',
    name: 'Follow Button',
    type: NodeType.container,
    props: ContainerProps(),
    layout: NodeLayout(
      size: SizeMode.fixed(105, 44),
      autoLayout: AutoLayout(
        direction: LayoutDirection.horizontal,
        padding: TokenEdgePadding.symmetric(horizontal: 20, vertical: 12),
        mainAlign: MainAxisAlignment.center,
        crossAlign: CrossAxisAlignment.center,
      ),
    ),
    style: NodeStyle(
      fill: SolidFill(HexColor('#9C27B0')),
      cornerRadius: CornerRadius.circular(22),
    ),
    childIds: ['follow_button_text'],
  );

  final followButtonText = Node(
    id: 'follow_button_text',
    name: 'Follow Text',
    type: NodeType.text,
    props: TextProps(
      text: 'Follow',
      fontSize: 15,
      fontWeight: 600,
      color: '#FFFFFF',
    ),
    layout: NodeLayout(
      size: SizeMode.hug(),
    ),
  );

  final messageButton = Node(
    id: 'message_button',
    name: 'Message Button',
    type: NodeType.container,
    props: ContainerProps(),
    layout: NodeLayout(
      size: SizeMode.fixed(105, 44),
      autoLayout: AutoLayout(
        direction: LayoutDirection.horizontal,
        padding: TokenEdgePadding.symmetric(horizontal: 20, vertical: 12),
        mainAlign: MainAxisAlignment.center,
        crossAlign: CrossAxisAlignment.center,
      ),
    ),
    style: NodeStyle(
      fill: SolidFill(HexColor('#FFFFFF')),
      cornerRadius: CornerRadius.circular(22),
      stroke: Stroke(
        color: HexColor('#9C27B0'),
        width: 2,
        position: StrokePosition.inside,
      ),
    ),
    childIds: ['message_button_text'],
  );

  final messageButtonText = Node(
    id: 'message_button_text',
    name: 'Message Text',
    type: NodeType.text,
    props: TextProps(
      text: 'Message',
      fontSize: 15,
      fontWeight: 600,
      color: '#9C27B0',
    ),
    layout: NodeLayout(
      size: SizeMode.hug(),
    ),
  );

  final shareButton = Node(
    id: 'share_button',
    name: 'Share Button',
    type: NodeType.container,
    props: ContainerProps(),
    layout: NodeLayout(
      size: SizeMode.fixed(44, 44),
      autoLayout: AutoLayout(
        direction: LayoutDirection.horizontal,
        padding: TokenEdgePadding.allFixed(10),
        mainAlign: MainAxisAlignment.center,
        crossAlign: CrossAxisAlignment.center,
      ),
    ),
    style: NodeStyle(
      fill: SolidFill(HexColor('#FFFFFF')),
      cornerRadius: CornerRadius.circular(22),
      stroke: Stroke(
        color: HexColor('#E0E0E0'),
        width: 1,
        position: StrokePosition.inside,
      ),
    ),
    childIds: ['share_icon'],
  );

  final shareIcon = Node(
    id: 'share_icon',
    name: 'Share Icon',
    type: NodeType.icon,
    props: IconProps(
      icon: 'share',
      size: 20,
      color: '#424242',
    ),
    layout: NodeLayout(
      size: SizeMode.fixed(20, 20),
    ),
  );

  // Content Section
  final contentSection = Node(
    id: 'content_section',
    name: 'Content Cards',
    type: NodeType.container,
    props: ContainerProps(),
    layout: NodeLayout(
      size: SizeMode.hug(),
      autoLayout: AutoLayout(
        direction: LayoutDirection.vertical,
        gap: FixedNumeric(16),
        mainAlign: MainAxisAlignment.start,
        crossAlign: CrossAxisAlignment.stretch,
      ),
    ),
    childIds: ['content_card_1', 'content_card_2'],
  );

  // Content Card 1
  final contentCard1 = Node(
    id: 'content_card_1',
    name: 'Recent Work',
    type: NodeType.container,
    props: ContainerProps(),
    layout: NodeLayout(
      size: SizeMode.hug(),
      autoLayout: AutoLayout(
        direction: LayoutDirection.vertical,
        padding: TokenEdgePadding.allFixed(16),
        gap: FixedNumeric(12),
        mainAlign: MainAxisAlignment.start,
        crossAlign: CrossAxisAlignment.start,
      ),
    ),
    style: NodeStyle(
      fill: SolidFill(HexColor('#FFFFFF')),
      cornerRadius: CornerRadius.circular(16),
      stroke: Stroke(
        color: HexColor('#E0E0E0'),
        width: 1,
        position: StrokePosition.inside,
      ),
    ),
    childIds: ['card1_header', 'card1_image', 'card1_footer'],
  );

  final card1Header = Node(
    id: 'card1_header',
    name: 'Card 1 Header',
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
    childIds: ['card1_title', 'card1_badge'],
  );

  final card1Title = Node(
    id: 'card1_title',
    name: 'Card 1 Title',
    type: NodeType.text,
    props: TextProps(
      text: 'UI Design System',
      fontSize: 18,
      fontWeight: 600,
      color: '#212121',
    ),
    layout: NodeLayout(
      size: SizeMode.hug(),
    ),
  );

  final card1Badge = Node(
    id: 'card1_badge',
    name: 'Featured Badge',
    type: NodeType.container,
    props: ContainerProps(),
    layout: NodeLayout(
      size: SizeMode.hug(),
      autoLayout: AutoLayout(
        direction: LayoutDirection.horizontal,
        padding: TokenEdgePadding.symmetric(horizontal: 8, vertical: 4),
        mainAlign: MainAxisAlignment.center,
        crossAlign: CrossAxisAlignment.center,
      ),
    ),
    style: NodeStyle(
      fill: SolidFill(HexColor('#E1BEE7')),
      cornerRadius: CornerRadius.circular(12),
    ),
    childIds: ['card1_badge_text'],
  );

  final card1BadgeText = Node(
    id: 'card1_badge_text',
    name: 'Badge Text',
    type: NodeType.text,
    props: TextProps(
      text: 'Featured',
      fontSize: 12,
      fontWeight: 600,
      color: '#6A1B9A',
    ),
    layout: NodeLayout(
      size: SizeMode.hug(),
    ),
  );

  final card1Image = Node(
    id: 'card1_image',
    name: 'Card 1 Image',
    type: NodeType.container,
    props: ContainerProps(),
    layout: NodeLayout(
      size: SizeMode.fixed(303, 180),
    ),
    style: NodeStyle(
      fill: SolidFill(HexColor('#E3F2FD')),
      cornerRadius: CornerRadius.circular(8),
    ),
  );

  final card1Footer = Node(
    id: 'card1_footer',
    name: 'Card 1 Footer',
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
    childIds: ['card1_likes', 'card1_views'],
  );

  final card1Likes = Node(
    id: 'card1_likes',
    name: 'Likes',
    type: NodeType.container,
    props: ContainerProps(),
    layout: NodeLayout(
      size: SizeMode.hug(),
      autoLayout: AutoLayout(
        direction: LayoutDirection.horizontal,
        gap: FixedNumeric(4),
        mainAlign: MainAxisAlignment.start,
        crossAlign: CrossAxisAlignment.center,
      ),
    ),
    childIds: ['card1_like_icon', 'card1_like_count'],
  );

  final card1LikeIcon = Node(
    id: 'card1_like_icon',
    name: 'Like Icon',
    type: NodeType.icon,
    props: IconProps(
      icon: 'favorite',
      size: 16,
      color: '#E91E63',
    ),
    layout: NodeLayout(
      size: SizeMode.fixed(16, 16),
    ),
  );

  final card1LikeCount = Node(
    id: 'card1_like_count',
    name: 'Like Count',
    type: NodeType.text,
    props: TextProps(
      text: '234',
      fontSize: 14,
      fontWeight: 500,
      color: '#757575',
    ),
    layout: NodeLayout(
      size: SizeMode.hug(),
    ),
  );

  final card1Views = Node(
    id: 'card1_views',
    name: 'Views',
    type: NodeType.container,
    props: ContainerProps(),
    layout: NodeLayout(
      size: SizeMode.hug(),
      autoLayout: AutoLayout(
        direction: LayoutDirection.horizontal,
        gap: FixedNumeric(4),
        mainAlign: MainAxisAlignment.start,
        crossAlign: CrossAxisAlignment.center,
      ),
    ),
    childIds: ['card1_view_icon', 'card1_view_count'],
  );

  final card1ViewIcon = Node(
    id: 'card1_view_icon',
    name: 'View Icon',
    type: NodeType.icon,
    props: IconProps(
      icon: 'visibility',
      size: 16,
      color: '#757575',
    ),
    layout: NodeLayout(
      size: SizeMode.fixed(16, 16),
    ),
  );

  final card1ViewCount = Node(
    id: 'card1_view_count',
    name: 'View Count',
    type: NodeType.text,
    props: TextProps(
      text: '1.2K',
      fontSize: 14,
      fontWeight: 500,
      color: '#757575',
    ),
    layout: NodeLayout(
      size: SizeMode.hug(),
    ),
  );

  // Content Card 2
  final contentCard2 = Node(
    id: 'content_card_2',
    name: 'Mobile App Design',
    type: NodeType.container,
    props: ContainerProps(),
    layout: NodeLayout(
      size: SizeMode.hug(),
      autoLayout: AutoLayout(
        direction: LayoutDirection.vertical,
        padding: TokenEdgePadding.allFixed(16),
        gap: FixedNumeric(12),
        mainAlign: MainAxisAlignment.start,
        crossAlign: CrossAxisAlignment.start,
      ),
    ),
    style: NodeStyle(
      fill: SolidFill(HexColor('#FFFFFF')),
      cornerRadius: CornerRadius.circular(16),
      stroke: Stroke(
        color: HexColor('#E0E0E0'),
        width: 1,
        position: StrokePosition.inside,
      ),
    ),
    childIds: ['card2_title', 'card2_image', 'card2_description'],
  );

  final card2Title = Node(
    id: 'card2_title',
    name: 'Card 2 Title',
    type: NodeType.text,
    props: TextProps(
      text: 'E-Commerce App',
      fontSize: 18,
      fontWeight: 600,
      color: '#212121',
    ),
    layout: NodeLayout(
      size: SizeMode.hug(),
    ),
  );

  final card2Image = Node(
    id: 'card2_image',
    name: 'Card 2 Image',
    type: NodeType.container,
    props: ContainerProps(),
    layout: NodeLayout(
      size: SizeMode.fixed(303, 180),
    ),
    style: NodeStyle(
      fill: SolidFill(HexColor('#FFF3E0')),
      cornerRadius: CornerRadius.circular(8),
    ),
  );

  final card2Description = Node(
    id: 'card2_description',
    name: 'Card 2 Description',
    type: NodeType.text,
    props: TextProps(
      text:
          'A modern shopping experience with smooth animations and intuitive navigation.',
      fontSize: 14,
      fontWeight: 400,
      color: '#616161',
      lineHeight: 1.4,
    ),
    layout: NodeLayout(
      size: SizeMode.hug(),
    ),
  );

  // Frame 2: Checkout
  final frame2 = Frame(
    id: 'frame_2',
    name: 'Checkout',
    rootNodeId: 'checkout_root',
    canvas: const CanvasPlacement(
      position: Offset(520, 140),
      size: Size(390, 844),
    ),
    createdAt: now,
    updatedAt: now,
  );

  final checkoutRoot = Node(
    id: 'checkout_root',
    name: 'Checkout Root',
    type: NodeType.container,
    props: ContainerProps(scrollDirection: 'vertical'),
    layout: NodeLayout(
      size: SizeMode.fixed(390, 844),
      autoLayout: AutoLayout(
        direction: LayoutDirection.vertical,
        padding: TokenEdgePadding.allFixed(20),
        gap: FixedNumeric(16),
        mainAlign: MainAxisAlignment.start,
        crossAlign: CrossAxisAlignment.stretch,
      ),
    ),
    style: NodeStyle(
      fill: SolidFill(HexColor('#F7F8FB')),
    ),
    childIds: [
      'checkout_header',
      'checkout_summary_card',
      'checkout_items',
      'checkout_payment',
      'checkout_cta',
    ],
  );

  final checkoutHeader = Node(
    id: 'checkout_header',
    name: 'Checkout Header',
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
    childIds: ['checkout_header_left', 'checkout_header_badge'],
  );

  final checkoutHeaderLeft = Node(
    id: 'checkout_header_left',
    name: 'Checkout Header Left',
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
    childIds: ['checkout_back_icon', 'checkout_title'],
  );

  final checkoutBackIcon = Node(
    id: 'checkout_back_icon',
    name: 'Checkout Back Icon',
    type: NodeType.icon,
    props: IconProps(
      icon: 'arrow_back',
      size: 20,
      color: '#1F2937',
    ),
    layout: NodeLayout(
      size: SizeMode.fixed(32, 32),
    ),
    style: NodeStyle(
      fill: SolidFill(HexColor('#FFFFFF')),
      cornerRadius: CornerRadius.circular(8),
      stroke: Stroke(
        color: HexColor('#E5E7EB'),
        width: 1,
        position: StrokePosition.inside,
      ),
    ),
  );

  final checkoutTitle = Node(
    id: 'checkout_title',
    name: 'Checkout Title',
    type: NodeType.text,
    props: TextProps(
      text: 'Checkout',
      fontSize: 20,
      fontWeight: 700,
      color: '#111827',
    ),
    layout: NodeLayout(
      size: SizeMode.hug(),
    ),
  );

  final checkoutHeaderBadge = Node(
    id: 'checkout_header_badge',
    name: 'Checkout Header Badge',
    type: NodeType.container,
    props: ContainerProps(),
    layout: NodeLayout(
      size: SizeMode.hug(),
      autoLayout: AutoLayout(
        direction: LayoutDirection.horizontal,
        gap: FixedNumeric(6),
        mainAlign: MainAxisAlignment.start,
        crossAlign: CrossAxisAlignment.center,
      ),
    ),
    style: NodeStyle(
      fill: SolidFill(HexColor('#EEF2FF')),
      cornerRadius: CornerRadius.circular(8),
    ),
    childIds: ['checkout_lock_icon', 'checkout_badge_text'],
  );

  final checkoutLockIcon = Node(
    id: 'checkout_lock_icon',
    name: 'Checkout Lock Icon',
    type: NodeType.icon,
    props: IconProps(
      icon: 'lock',
      size: 14,
      color: '#4338CA',
    ),
    layout: NodeLayout(
      size: SizeMode.fixed(16, 16),
    ),
  );

  final checkoutBadgeText = Node(
    id: 'checkout_badge_text',
    name: 'Checkout Badge Text',
    type: NodeType.text,
    props: TextProps(
      text: 'Secure Checkout',
      fontSize: 12,
      fontWeight: 600,
      color: '#4338CA',
    ),
    layout: NodeLayout(
      size: SizeMode.hug(),
    ),
  );

  final checkoutSummaryCard = Node(
    id: 'checkout_summary_card',
    name: 'Checkout Summary',
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
      fill: SolidFill(HexColor('#FFFFFF')),
      cornerRadius: CornerRadius.circular(14),
      stroke: Stroke(
        color: HexColor('#E5E7EB'),
        width: 1,
        position: StrokePosition.inside,
      ),
      shadow: Shadow(
        color: ColorValue.fromJson({'hex': '#0F172A', 'opacity': 0.05}),
        blur: 8,
        offsetX: 0,
        offsetY: 4,
        spread: 0,
      ),
    ),
    childIds: [
      'summary_title',
      'summary_subtotal_row',
      'summary_shipping_row',
      'summary_total_row',
    ],
  );

  final summaryTitle = Node(
    id: 'summary_title',
    name: 'Summary Title',
    type: NodeType.text,
    props: TextProps(
      text: 'Order Summary',
      fontSize: 16,
      fontWeight: 700,
      color: '#111827',
    ),
    layout: NodeLayout(
      size: SizeMode.hug(),
    ),
  );

  final summarySubtotalRow = Node(
    id: 'summary_subtotal_row',
    name: 'Subtotal Row',
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
    childIds: ['summary_subtotal_label', 'summary_subtotal_value'],
  );

  final summarySubtotalLabel = Node(
    id: 'summary_subtotal_label',
    name: 'Subtotal Label',
    type: NodeType.text,
    props: TextProps(
      text: 'Subtotal',
      fontSize: 14,
      fontWeight: 500,
      color: '#4B5563',
    ),
    layout: NodeLayout(
      size: SizeMode.hug(),
    ),
  );

  final summarySubtotalValue = Node(
    id: 'summary_subtotal_value',
    name: 'Subtotal Value',
    type: NodeType.text,
    props: TextProps(
      text: '\$128.00',
      fontSize: 14,
      fontWeight: 600,
      color: '#111827',
    ),
    layout: NodeLayout(
      size: SizeMode.hug(),
    ),
  );

  final summaryShippingRow = Node(
    id: 'summary_shipping_row',
    name: 'Shipping Row',
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
    childIds: ['summary_shipping_label', 'summary_shipping_value'],
  );

  final summaryShippingLabel = Node(
    id: 'summary_shipping_label',
    name: 'Shipping Label',
    type: NodeType.text,
    props: TextProps(
      text: 'Shipping',
      fontSize: 14,
      fontWeight: 500,
      color: '#4B5563',
    ),
    layout: NodeLayout(
      size: SizeMode.hug(),
    ),
  );

  final summaryShippingValue = Node(
    id: 'summary_shipping_value',
    name: 'Shipping Value',
    type: NodeType.text,
    props: TextProps(
      text: '\$6.40',
      fontSize: 14,
      fontWeight: 600,
      color: '#111827',
    ),
    layout: NodeLayout(
      size: SizeMode.hug(),
    ),
  );

  final summaryTotalRow = Node(
    id: 'summary_total_row',
    name: 'Total Row',
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
    childIds: ['summary_total_label', 'summary_total_value'],
  );

  final summaryTotalLabel = Node(
    id: 'summary_total_label',
    name: 'Total Label',
    type: NodeType.text,
    props: TextProps(
      text: 'Total',
      fontSize: 16,
      fontWeight: 700,
      color: '#111827',
    ),
    layout: NodeLayout(
      size: SizeMode.hug(),
    ),
  );

  final summaryTotalValue = Node(
    id: 'summary_total_value',
    name: 'Total Value',
    type: NodeType.text,
    props: TextProps(
      text: '\$134.40',
      fontSize: 16,
      fontWeight: 700,
      color: '#111827',
    ),
    layout: NodeLayout(
      size: SizeMode.hug(),
    ),
  );

  final checkoutItems = Node(
    id: 'checkout_items',
    name: 'Checkout Items',
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
      fill: SolidFill(HexColor('#FFFFFF')),
      cornerRadius: CornerRadius.circular(14),
      stroke: Stroke(
        color: HexColor('#E5E7EB'),
        width: 1,
        position: StrokePosition.inside,
      ),
    ),
    childIds: ['items_title', 'item_row_1', 'item_row_2'],
  );

  final itemsTitle = Node(
    id: 'items_title',
    name: 'Items Title',
    type: NodeType.text,
    props: TextProps(
      text: 'Items',
      fontSize: 16,
      fontWeight: 700,
      color: '#111827',
    ),
    layout: NodeLayout(
      size: SizeMode.hug(),
    ),
  );

  final itemRow1 = Node(
    id: 'item_row_1',
    name: 'Item Row 1',
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
    childIds: ['item1_thumb', 'item1_info', 'item1_price'],
  );

  final item1Thumb = Node(
    id: 'item1_thumb',
    name: 'Item 1 Thumb',
    type: NodeType.container,
    props: ContainerProps(),
    layout: NodeLayout(
      size: SizeMode.fixed(52, 52),
    ),
    style: NodeStyle(
      fill: SolidFill(HexColor('#F3F4F6')),
      cornerRadius: CornerRadius.circular(12),
    ),
  );

  final item1Info = Node(
    id: 'item1_info',
    name: 'Item 1 Info',
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
    childIds: ['item1_name', 'item1_meta'],
  );

  final item1Name = Node(
    id: 'item1_name',
    name: 'Item 1 Name',
    type: NodeType.text,
    props: TextProps(
      text: 'Noise Cancelling Headphones',
      fontSize: 14,
      fontWeight: 600,
      color: '#111827',
    ),
    layout: NodeLayout(
      size: SizeMode.hug(),
    ),
  );

  final item1Meta = Node(
    id: 'item1_meta',
    name: 'Item 1 Meta',
    type: NodeType.text,
    props: TextProps(
      text: 'Black · Qty 1',
      fontSize: 12,
      fontWeight: 500,
      color: '#6B7280',
    ),
    layout: NodeLayout(
      size: SizeMode.hug(),
    ),
  );

  final item1Price = Node(
    id: 'item1_price',
    name: 'Item 1 Price',
    type: NodeType.text,
    props: TextProps(
      text: '\$98.00',
      fontSize: 14,
      fontWeight: 700,
      color: '#111827',
    ),
    layout: NodeLayout(
      size: SizeMode.hug(),
    ),
  );

  final itemRow2 = Node(
    id: 'item_row_2',
    name: 'Item Row 2',
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
    childIds: ['item2_thumb', 'item2_info', 'item2_price'],
  );

  final item2Thumb = Node(
    id: 'item2_thumb',
    name: 'Item 2 Thumb',
    type: NodeType.container,
    props: ContainerProps(),
    layout: NodeLayout(
      size: SizeMode.fixed(52, 52),
    ),
    style: NodeStyle(
      fill: SolidFill(HexColor('#ECFEFF')),
      cornerRadius: CornerRadius.circular(12),
    ),
  );

  final item2Info = Node(
    id: 'item2_info',
    name: 'Item 2 Info',
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
    childIds: ['item2_name', 'item2_meta'],
  );

  final item2Name = Node(
    id: 'item2_name',
    name: 'Item 2 Name',
    type: NodeType.text,
    props: TextProps(
      text: 'Wireless Charger',
      fontSize: 14,
      fontWeight: 600,
      color: '#111827',
    ),
    layout: NodeLayout(
      size: SizeMode.hug(),
    ),
  );

  final item2Meta = Node(
    id: 'item2_meta',
    name: 'Item 2 Meta',
    type: NodeType.text,
    props: TextProps(
      text: 'White · Qty 1',
      fontSize: 12,
      fontWeight: 500,
      color: '#6B7280',
    ),
    layout: NodeLayout(
      size: SizeMode.hug(),
    ),
  );

  final item2Price = Node(
    id: 'item2_price',
    name: 'Item 2 Price',
    type: NodeType.text,
    props: TextProps(
      text: '\$30.00',
      fontSize: 14,
      fontWeight: 700,
      color: '#111827',
    ),
    layout: NodeLayout(
      size: SizeMode.hug(),
    ),
  );

  final checkoutPayment = Node(
    id: 'checkout_payment',
    name: 'Checkout Payment',
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
      fill: SolidFill(HexColor('#FFFFFF')),
      cornerRadius: CornerRadius.circular(14),
      stroke: Stroke(
        color: HexColor('#E5E7EB'),
        width: 1,
        position: StrokePosition.inside,
      ),
    ),
    childIds: ['payment_title', 'payment_card', 'delivery_row'],
  );

  final paymentTitle = Node(
    id: 'payment_title',
    name: 'Payment Title',
    type: NodeType.text,
    props: TextProps(
      text: 'Payment & Delivery',
      fontSize: 16,
      fontWeight: 700,
      color: '#111827',
    ),
    layout: NodeLayout(
      size: SizeMode.hug(),
    ),
  );

  final paymentCard = Node(
    id: 'payment_card',
    name: 'Payment Card',
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
    style: NodeStyle(
      fill: SolidFill(HexColor('#EEF2FF')),
      cornerRadius: CornerRadius.circular(12),
    ),
    childIds: ['payment_icon', 'payment_texts'],
  );

  final paymentIcon = Node(
    id: 'payment_icon',
    name: 'Payment Icon',
    type: NodeType.icon,
    props: IconProps(
      icon: 'credit_card',
      size: 18,
      color: '#4338CA',
    ),
    layout: NodeLayout(
      size: SizeMode.fixed(24, 24),
    ),
  );

  final paymentTexts = Node(
    id: 'payment_texts',
    name: 'Payment Texts',
    type: NodeType.container,
    props: ContainerProps(),
    layout: NodeLayout(
      size: SizeMode.hug(),
      autoLayout: AutoLayout(
        direction: LayoutDirection.vertical,
        gap: FixedNumeric(2),
        mainAlign: MainAxisAlignment.start,
        crossAlign: CrossAxisAlignment.start,
      ),
    ),
    childIds: ['payment_label', 'payment_value'],
  );

  final paymentLabel = Node(
    id: 'payment_label',
    name: 'Payment Label',
    type: NodeType.text,
    props: TextProps(
      text: 'Visa •••• 4242',
      fontSize: 14,
      fontWeight: 700,
      color: '#111827',
    ),
    layout: NodeLayout(
      size: SizeMode.hug(),
    ),
  );

  final paymentValue = Node(
    id: 'payment_value',
    name: 'Payment Value',
    type: NodeType.text,
    props: TextProps(
      text: 'Default payment method',
      fontSize: 12,
      fontWeight: 500,
      color: '#6B7280',
    ),
    layout: NodeLayout(
      size: SizeMode.hug(),
    ),
  );

  final deliveryRow = Node(
    id: 'delivery_row',
    name: 'Delivery Row',
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
    childIds: ['delivery_left', 'delivery_eta'],
  );

  final deliveryLeft = Node(
    id: 'delivery_left',
    name: 'Delivery Left',
    type: NodeType.container,
    props: ContainerProps(),
    layout: NodeLayout(
      size: SizeMode.hug(),
      autoLayout: AutoLayout(
        direction: LayoutDirection.horizontal,
        gap: FixedNumeric(8),
        mainAlign: MainAxisAlignment.start,
        crossAlign: CrossAxisAlignment.center,
      ),
    ),
    childIds: ['delivery_icon', 'delivery_label'],
  );

  final deliveryIcon = Node(
    id: 'delivery_icon',
    name: 'Delivery Icon',
    type: NodeType.icon,
    props: IconProps(
      icon: 'truck',
      size: 18,
      color: '#2563EB',
    ),
    layout: NodeLayout(
      size: SizeMode.fixed(24, 24),
    ),
    style: NodeStyle(
      fill: SolidFill(HexColor('#EFF6FF')),
      cornerRadius: CornerRadius.circular(8),
    ),
  );

  final deliveryLabel = Node(
    id: 'delivery_label',
    name: 'Delivery Label',
    type: NodeType.text,
    props: TextProps(
      text: 'Express delivery',
      fontSize: 14,
      fontWeight: 600,
      color: '#111827',
    ),
    layout: NodeLayout(
      size: SizeMode.hug(),
    ),
  );

  final deliveryEta = Node(
    id: 'delivery_eta',
    name: 'Delivery ETA',
    type: NodeType.text,
    props: TextProps(
      text: 'Arrives Tomorrow',
      fontSize: 13,
      fontWeight: 600,
      color: '#2563EB',
    ),
    layout: NodeLayout(
      size: SizeMode.hug(),
    ),
  );

  final checkoutCta = Node(
    id: 'checkout_cta',
    name: 'Checkout CTA',
    type: NodeType.container,
    props: ContainerProps(),
    layout: NodeLayout(
      size: SizeMode.fixed(350, 52),
      autoLayout: AutoLayout(
        direction: LayoutDirection.horizontal,
        mainAlign: MainAxisAlignment.center,
        crossAlign: CrossAxisAlignment.center,
      ),
    ),
    style: NodeStyle(
      fill: SolidFill(HexColor('#4F46E5')),
      cornerRadius: CornerRadius.circular(12),
      shadow: Shadow(
        color: ColorValue.fromJson({'hex': '#312E81', 'opacity': 0.15}),
        blur: 12,
        offsetX: 0,
        offsetY: 6,
        spread: 0,
      ),
    ),
    childIds: ['checkout_cta_text'],
  );

  final checkoutCtaText = Node(
    id: 'checkout_cta_text',
    name: 'Checkout CTA Text',
    type: NodeType.text,
    props: TextProps(
      text: 'Place Order',
      fontSize: 16,
      fontWeight: 700,
      color: '#FFFFFF',
    ),
    layout: NodeLayout(
      size: SizeMode.hug(),
    ),
  );

  // Frame 3: Messaging
  final frame3 = Frame(
    id: 'frame_3',
    name: 'Messages',
    rootNodeId: 'chat_root',
    canvas: const CanvasPlacement(
      position: Offset(960, 160),
      size: Size(390, 844),
    ),
    createdAt: now,
    updatedAt: now,
  );

  final chatRoot = Node(
    id: 'chat_root',
    name: 'Chat Root',
    type: NodeType.container,
    props: ContainerProps(),
    layout: NodeLayout(
      size: SizeMode.fixed(390, 844),
      autoLayout: AutoLayout(
        direction: LayoutDirection.vertical,
        padding: TokenEdgePadding.allFixed(16),
        gap: FixedNumeric(16),
        mainAlign: MainAxisAlignment.start,
        crossAlign: CrossAxisAlignment.stretch,
      ),
    ),
    style: NodeStyle(
      fill: SolidFill(HexColor('#FFFFFF')),
    ),
    childIds: ['chat_header', 'chat_list', 'chat_composer'],
  );

  final chatHeader = Node(
    id: 'chat_header',
    name: 'Chat Header',
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
    childIds: ['chat_identity', 'chat_header_actions'],
  );

  final chatIdentity = Node(
    id: 'chat_identity',
    name: 'Chat Identity',
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
    childIds: ['chat_avatar', 'chat_identity_texts'],
  );

  final chatAvatar = Node(
    id: 'chat_avatar',
    name: 'Chat Avatar',
    type: NodeType.container,
    props: ContainerProps(),
    layout: NodeLayout(
      size: SizeMode.fixed(40, 40),
    ),
    style: NodeStyle(
      fill: SolidFill(HexColor('#E0E7FF')),
      cornerRadius: CornerRadius.circular(20),
    ),
  );

  final chatIdentityTexts = Node(
    id: 'chat_identity_texts',
    name: 'Chat Identity Texts',
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
    childIds: ['chat_name', 'chat_status'],
  );

  final chatName = Node(
    id: 'chat_name',
    name: 'Chat Name',
    type: NodeType.text,
    props: TextProps(
      text: 'Sam Carter',
      fontSize: 16,
      fontWeight: 700,
      color: '#111827',
    ),
    layout: NodeLayout(
      size: SizeMode.hug(),
    ),
  );

  final chatStatus = Node(
    id: 'chat_status',
    name: 'Chat Status',
    type: NodeType.text,
    props: TextProps(
      text: 'Online · Mobile',
      fontSize: 12,
      fontWeight: 500,
      color: '#10B981',
    ),
    layout: NodeLayout(
      size: SizeMode.hug(),
    ),
  );

  final chatHeaderActions = Node(
    id: 'chat_header_actions',
    name: 'Chat Header Actions',
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
    childIds: ['chat_call_icon', 'chat_more_icon'],
  );

  final chatCallIcon = Node(
    id: 'chat_call_icon',
    name: 'Chat Call Icon',
    type: NodeType.icon,
    props: IconProps(
      icon: 'phone',
      size: 18,
      color: '#374151',
    ),
    layout: NodeLayout(
      size: SizeMode.fixed(32, 32),
    ),
    style: NodeStyle(
      fill: SolidFill(HexColor('#F3F4F6')),
      cornerRadius: CornerRadius.circular(10),
    ),
  );

  final chatMoreIcon = Node(
    id: 'chat_more_icon',
    name: 'Chat More Icon',
    type: NodeType.icon,
    props: IconProps(
      icon: 'more_horiz',
      size: 18,
      color: '#374151',
    ),
    layout: NodeLayout(
      size: SizeMode.fixed(32, 32),
    ),
    style: NodeStyle(
      fill: SolidFill(HexColor('#F3F4F6')),
      cornerRadius: CornerRadius.circular(10),
    ),
  );

  final chatList = Node(
    id: 'chat_list',
    name: 'Chat List',
    type: NodeType.container,
    props: ContainerProps(scrollDirection: 'vertical'),
    layout: NodeLayout(
      size: SizeMode.fill(),
      autoLayout: AutoLayout(
        direction: LayoutDirection.vertical,
        gap: FixedNumeric(12),
        mainAlign: MainAxisAlignment.start,
        crossAlign: CrossAxisAlignment.stretch,
      ),
    ),
    childIds: [
      'chat_date_label',
      'chat_message_1',
      'chat_message_2',
      'chat_message_3',
      'chat_message_4',
    ],
  );

  final chatDateLabel = Node(
    id: 'chat_date_label',
    name: 'Chat Date Label',
    type: NodeType.text,
    props: TextProps(
      text: 'Yesterday',
      fontSize: 12,
      fontWeight: 600,
      color: '#6B7280',
    ),
    layout: NodeLayout(
      size: SizeMode.hug(),
    ),
  );

  final chatMessage1 = Node(
    id: 'chat_message_1',
    name: 'Chat Message 1',
    type: NodeType.container,
    props: ContainerProps(),
    layout: NodeLayout(
      size: SizeMode.hug(),
      autoLayout: AutoLayout(
        direction: LayoutDirection.horizontal,
        mainAlign: MainAxisAlignment.start,
        crossAlign: CrossAxisAlignment.start,
      ),
    ),
    childIds: ['chat_message_1_bubble'],
  );

  final chatMessage1Bubble = Node(
    id: 'chat_message_1_bubble',
    name: 'Chat Message 1 Bubble',
    type: NodeType.container,
    props: ContainerProps(),
    layout: NodeLayout(
      size: SizeMode.hug(),
      autoLayout: AutoLayout(
        direction: LayoutDirection.vertical,
        padding: TokenEdgePadding.symmetric(horizontal: 14, vertical: 10),
        mainAlign: MainAxisAlignment.start,
        crossAlign: CrossAxisAlignment.start,
      ),
    ),
    style: NodeStyle(
      fill: SolidFill(HexColor('#F3F4F6')),
      cornerRadius: CornerRadius.circular(12),
    ),
    childIds: ['chat_message_1_text'],
  );

  final chatMessage1Text = Node(
    id: 'chat_message_1_text',
    name: 'Chat Message 1 Text',
    type: NodeType.text,
    props: TextProps(
      text:
          'Hey! I just pushed the latest build. Can you review the new onboarding?',
      fontSize: 14,
      fontWeight: 500,
      color: '#111827',
      lineHeight: 1.4,
    ),
    layout: NodeLayout(
      size: SizeMode.hug(),
    ),
  );

  final chatMessage2 = Node(
    id: 'chat_message_2',
    name: 'Chat Message 2',
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
    childIds: ['chat_message_2_bubble'],
  );

  final chatMessage2Bubble = Node(
    id: 'chat_message_2_bubble',
    name: 'Chat Message 2 Bubble',
    type: NodeType.container,
    props: ContainerProps(),
    layout: NodeLayout(
      size: SizeMode.hug(),
      autoLayout: AutoLayout(
        direction: LayoutDirection.vertical,
        padding: TokenEdgePadding.symmetric(horizontal: 14, vertical: 10),
        mainAlign: MainAxisAlignment.start,
        crossAlign: CrossAxisAlignment.start,
      ),
    ),
    style: NodeStyle(
      fill: SolidFill(HexColor('#4F46E5')),
      cornerRadius: CornerRadius.circular(12),
    ),
    childIds: ['chat_message_2_text'],
  );

  final chatMessage2Text = Node(
    id: 'chat_message_2_text',
    name: 'Chat Message 2 Text',
    type: NodeType.text,
    props: TextProps(
      text: 'Looks great! I like the new spacing on step 2.',
      fontSize: 14,
      fontWeight: 600,
      color: '#FFFFFF',
      lineHeight: 1.4,
    ),
    layout: NodeLayout(
      size: SizeMode.hug(),
    ),
  );

  final chatMessage3 = Node(
    id: 'chat_message_3',
    name: 'Chat Message 3',
    type: NodeType.container,
    props: ContainerProps(),
    layout: NodeLayout(
      size: SizeMode.hug(),
      autoLayout: AutoLayout(
        direction: LayoutDirection.horizontal,
        mainAlign: MainAxisAlignment.start,
        crossAlign: CrossAxisAlignment.start,
      ),
    ),
    childIds: ['chat_message_3_bubble'],
  );

  final chatMessage3Bubble = Node(
    id: 'chat_message_3_bubble',
    name: 'Chat Message 3 Bubble',
    type: NodeType.container,
    props: ContainerProps(),
    layout: NodeLayout(
      size: SizeMode.hug(),
      autoLayout: AutoLayout(
        direction: LayoutDirection.vertical,
        padding: TokenEdgePadding.symmetric(horizontal: 14, vertical: 10),
        mainAlign: MainAxisAlignment.start,
        crossAlign: CrossAxisAlignment.start,
      ),
    ),
    style: NodeStyle(
      fill: SolidFill(HexColor('#F3F4F6')),
      cornerRadius: CornerRadius.circular(12),
    ),
    childIds: ['chat_message_3_text'],
  );

  final chatMessage3Text = Node(
    id: 'chat_message_3_text',
    name: 'Chat Message 3 Text',
    type: NodeType.text,
    props: TextProps(
      text: 'Nice! I’ll merge it after QA gives the thumbs up.',
      fontSize: 14,
      fontWeight: 500,
      color: '#111827',
    ),
    layout: NodeLayout(
      size: SizeMode.hug(),
    ),
  );

  final chatMessage4 = Node(
    id: 'chat_message_4',
    name: 'Chat Message 4',
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
    childIds: ['chat_message_4_bubble'],
  );

  final chatMessage4Bubble = Node(
    id: 'chat_message_4_bubble',
    name: 'Chat Message 4 Bubble',
    type: NodeType.container,
    props: ContainerProps(),
    layout: NodeLayout(
      size: SizeMode.hug(),
      autoLayout: AutoLayout(
        direction: LayoutDirection.vertical,
        padding: TokenEdgePadding.symmetric(horizontal: 14, vertical: 10),
        mainAlign: MainAxisAlignment.start,
        crossAlign: CrossAxisAlignment.start,
      ),
    ),
    style: NodeStyle(
      fill: SolidFill(HexColor('#4F46E5')),
      cornerRadius: CornerRadius.circular(12),
    ),
    childIds: ['chat_message_4_text'],
  );

  final chatMessage4Text = Node(
    id: 'chat_message_4_text',
    name: 'Chat Message 4 Text',
    type: NodeType.text,
    props: TextProps(
      text: 'Thanks! Let’s also capture a quick video for the release notes.',
      fontSize: 14,
      fontWeight: 600,
      color: '#FFFFFF',
      lineHeight: 1.4,
    ),
    layout: NodeLayout(
      size: SizeMode.hug(),
    ),
  );

  final chatComposer = Node(
    id: 'chat_composer',
    name: 'Chat Composer',
    type: NodeType.container,
    props: ContainerProps(),
    layout: NodeLayout(
      size: SizeMode.hug(),
      autoLayout: AutoLayout(
        direction: LayoutDirection.horizontal,
        gap: FixedNumeric(12),
        padding: TokenEdgePadding.allFixed(12),
        mainAlign: MainAxisAlignment.start,
        crossAlign: CrossAxisAlignment.center,
      ),
    ),
    style: NodeStyle(
      fill: SolidFill(HexColor('#F9FAFB')),
      cornerRadius: CornerRadius.circular(14),
      stroke: Stroke(
        color: HexColor('#E5E7EB'),
        width: 1,
        position: StrokePosition.inside,
      ),
    ),
    childIds: ['composer_add', 'composer_input', 'composer_send'],
  );

  final composerAdd = Node(
    id: 'composer_add',
    name: 'Composer Add',
    type: NodeType.icon,
    props: IconProps(
      icon: 'add',
      size: 20,
      color: '#4B5563',
    ),
    layout: NodeLayout(
      size: SizeMode.fixed(28, 28),
    ),
  );

  final composerInput = Node(
    id: 'composer_input',
    name: 'Composer Input',
    type: NodeType.text,
    props: TextProps(
      text: 'Message Sam...',
      fontSize: 14,
      fontWeight: 500,
      color: '#9CA3AF',
    ),
    layout: NodeLayout(
      size: SizeMode.fill(),
    ),
  );

  final composerSend = Node(
    id: 'composer_send',
    name: 'Composer Send',
    type: NodeType.container,
    props: ContainerProps(),
    layout: NodeLayout(
      size: SizeMode.fixed(36, 36),
      autoLayout: AutoLayout(
        direction: LayoutDirection.horizontal,
        mainAlign: MainAxisAlignment.center,
        crossAlign: CrossAxisAlignment.center,
      ),
    ),
    style: NodeStyle(
      fill: SolidFill(HexColor('#4F46E5')),
      cornerRadius: CornerRadius.circular(10),
    ),
    childIds: ['composer_send_icon'],
  );

  final composerSendIcon = Node(
    id: 'composer_send_icon',
    name: 'Composer Send Icon',
    type: NodeType.icon,
    props: IconProps(
      icon: 'send',
      size: 16,
      color: '#FFFFFF',
    ),
    layout: NodeLayout(
      size: SizeMode.fixed(16, 16),
    ),
  );

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
    style: NodeStyle(
      fill: SolidFill(HexColor('#FFFFFF')),
    ),
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
    layout: NodeLayout(
      size: SizeMode.hug(),
    ),
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
    props: IconProps(
      icon: 'signal_cellular_alt',
      size: 16,
      color: '#000000',
    ),
    layout: NodeLayout(
      size: SizeMode.fixed(16, 16),
    ),
  );

  final gptWifi = Node(
    id: 'gpt_wifi',
    name: 'WiFi',
    type: NodeType.icon,
    props: IconProps(
      icon: 'wifi',
      size: 16,
      color: '#000000',
    ),
    layout: NodeLayout(
      size: SizeMode.fixed(16, 16),
    ),
  );

  final gptBattery = Node(
    id: 'gpt_battery',
    name: 'Battery',
    type: NodeType.container,
    props: ContainerProps(),
    layout: NodeLayout(
      size: SizeMode.fixed(27, 13),
    ),
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
    props: IconProps(
      icon: 'menu',
      size: 24,
      color: '#000000',
    ),
    layout: NodeLayout(
      size: SizeMode.fixed(24, 24),
    ),
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
    layout: NodeLayout(
      size: SizeMode.hug(),
    ),
  );

  final gptChevron = Node(
    id: 'gpt_chevron',
    name: 'Chevron',
    type: NodeType.icon,
    props: IconProps(
      icon: 'chevron_right',
      size: 20,
      color: '#000000',
    ),
    layout: NodeLayout(
      size: SizeMode.fixed(20, 20),
    ),
  );

  final gptEditIcon = Node(
    id: 'gpt_edit_icon',
    name: 'Edit',
    type: NodeType.icon,
    props: IconProps(
      icon: 'edit',
      size: 24,
      color: '#000000',
    ),
    layout: NodeLayout(
      size: SizeMode.fixed(24, 24),
    ),
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
    props: IconProps(
      icon: 'content_copy',
      size: 20,
      color: '#6B7280',
    ),
    layout: NodeLayout(
      size: SizeMode.fixed(20, 20),
    ),
  );

  final gptSpeakIcon = Node(
    id: 'gpt_speak_icon',
    name: 'Speak',
    type: NodeType.icon,
    props: IconProps(
      icon: 'volume_up',
      size: 20,
      color: '#6B7280',
    ),
    layout: NodeLayout(
      size: SizeMode.fixed(20, 20),
    ),
  );

  final gptLikeIcon = Node(
    id: 'gpt_like_icon',
    name: 'Like',
    type: NodeType.icon,
    props: IconProps(
      icon: 'thumb_up_outlined',
      size: 20,
      color: '#6B7280',
    ),
    layout: NodeLayout(
      size: SizeMode.fixed(20, 20),
    ),
  );

  final gptDislikeIcon = Node(
    id: 'gpt_dislike_icon',
    name: 'Dislike',
    type: NodeType.icon,
    props: IconProps(
      icon: 'thumb_down_outlined',
      size: 20,
      color: '#6B7280',
    ),
    layout: NodeLayout(
      size: SizeMode.fixed(20, 20),
    ),
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
    layout: NodeLayout(
      size: SizeMode.hug(),
    ),
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
    layout: NodeLayout(
      size: SizeMode.hug(),
    ),
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
    layout: NodeLayout(
      size: SizeMode.hug(),
    ),
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
    layout: NodeLayout(
      size: SizeMode.hug(),
    ),
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
    layout: NodeLayout(
      size: SizeMode.fixed(200, 6),
    ),
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
    layout: NodeLayout(
      size: SizeMode.fixed(60, 6),
    ),
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
    layout: NodeLayout(
      size: SizeMode.hug(),
    ),
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
    props: IconProps(
      icon: 'volume_up',
      size: 20,
      color: '#6B7280',
    ),
    layout: NodeLayout(
      size: SizeMode.fixed(20, 20),
    ),
  );

  final gptLikeIcon2 = Node(
    id: 'gpt_like_icon_2',
    name: 'Like',
    type: NodeType.icon,
    props: IconProps(
      icon: 'thumb_up_outlined',
      size: 20,
      color: '#6B7280',
    ),
    layout: NodeLayout(
      size: SizeMode.fixed(20, 20),
    ),
  );

  final gptDislikeIcon2 = Node(
    id: 'gpt_dislike_icon_2',
    name: 'Dislike',
    type: NodeType.icon,
    props: IconProps(
      icon: 'thumb_down_outlined',
      size: 20,
      color: '#6B7280',
    ),
    layout: NodeLayout(
      size: SizeMode.fixed(20, 20),
    ),
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
    layout: NodeLayout(
      size: SizeMode.hug(),
    ),
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
    props: IconProps(
      icon: 'add',
      size: 20,
      color: '#374151',
    ),
    layout: NodeLayout(
      size: SizeMode.fixed(20, 20),
    ),
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
    props: IconProps(
      icon: 'tune',
      size: 20,
      color: '#374151',
    ),
    layout: NodeLayout(
      size: SizeMode.fixed(20, 20),
    ),
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
    props: IconProps(
      icon: 'mic',
      size: 20,
      color: '#374151',
    ),
    layout: NodeLayout(
      size: SizeMode.fixed(20, 20),
    ),
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
    props: IconProps(
      icon: 'graphic_eq',
      size: 20,
      color: '#FFFFFF',
    ),
    layout: NodeLayout(
      size: SizeMode.fixed(20, 20),
    ),
  );

  // Footer with home indicator and ChatGPT branding
  final gptFooter = Node(
    id: 'gpt_footer',
    name: 'Footer',
    type: NodeType.container,
    props: ContainerProps(),
    layout: NodeLayout(
      size: SizeMode.fixed(393, 80),
      autoLayout: AutoLayout(
        direction: LayoutDirection.vertical,
        padding: TokenEdgePadding.symmetric(horizontal: 16, vertical: 8),
        gap: FixedNumeric(12),
        mainAlign: MainAxisAlignment.start,
        crossAlign: CrossAxisAlignment.center,
      ),
    ),
    style: NodeStyle(
      fill: SolidFill(HexColor('#F3F4F6')),
    ),
    childIds: ['gpt_home_indicator', 'gpt_branding'],
  );

  final gptHomeIndicator = Node(
    id: 'gpt_home_indicator',
    name: 'Home Indicator',
    type: NodeType.container,
    props: ContainerProps(),
    layout: NodeLayout(
      size: SizeMode.fixed(134, 5),
    ),
    style: NodeStyle(
      fill: SolidFill(HexColor('#000000')),
      cornerRadius: CornerRadius.circular(3),
    ),
  );

  final gptBranding = Node(
    id: 'gpt_branding',
    name: 'Branding',
    type: NodeType.container,
    props: ContainerProps(),
    layout: NodeLayout(
      size: SizeMode.hug(),
      autoLayout: AutoLayout(
        direction: LayoutDirection.horizontal,
        gap: FixedNumeric(8),
        mainAlign: MainAxisAlignment.center,
        crossAlign: CrossAxisAlignment.center,
      ),
    ),
    childIds: ['gpt_logo', 'gpt_brand_text', 'gpt_curated'],
  );

  final gptLogo = Node(
    id: 'gpt_logo',
    name: 'Logo',
    type: NodeType.container,
    props: ContainerProps(),
    layout: NodeLayout(
      size: SizeMode.fixed(20, 20),
    ),
    style: NodeStyle(
      fill: SolidFill(HexColor('#10A37F')),
      cornerRadius: CornerRadius.circular(4),
    ),
  );

  final gptBrandText = Node(
    id: 'gpt_brand_text',
    name: 'Brand Text',
    type: NodeType.text,
    props: TextProps(
      text: 'ChatGPT',
      fontSize: 14,
      fontWeight: 600,
      color: '#374151',
    ),
    layout: NodeLayout(
      size: SizeMode.hug(),
    ),
  );

  final gptCurated = Node(
    id: 'gpt_curated',
    name: 'Curated',
    type: NodeType.text,
    props: TextProps(
      text: 'curated by Mobbin',
      fontSize: 12,
      fontWeight: 400,
      color: '#9CA3AF',
    ),
    layout: NodeLayout(
      size: SizeMode.hug(),
    ),
  );

  return EditorDocument.empty(documentId: 'demo_doc')
      .withFrame(chatGptLight)
      .withNode(cglRoot)
      .withNode(appBar)
      .withNode(backButton)
      .withNode(appBarTitle)
      .withNode(menuButton)
      .withNode(contentScroll)
      .withNode(profileHeader)
      .withNode(avatar)
      .withNode(profileInfo)
      .withNode(nameText)
      .withNode(usernameText)
      .withNode(bioText)
      .withNode(statsSection)
      .withNode(statFollowers)
      .withNode(statFollowersNum)
      .withNode(statFollowersLabel)
      .withNode(statFollowing)
      .withNode(statFollowingNum)
      .withNode(statFollowingLabel)
      .withNode(statPosts)
      .withNode(statPostsNum)
      .withNode(statPostsLabel)
      .withNode(actionsSection)
      .withNode(followButton)
      .withNode(followButtonText)
      .withNode(messageButton)
      .withNode(messageButtonText)
      .withNode(shareButton)
      .withNode(shareIcon)
      .withNode(contentSection)
      .withNode(contentCard1)
      .withNode(card1Header)
      .withNode(card1Title)
      .withNode(card1Badge)
      .withNode(card1BadgeText)
      .withNode(card1Image)
      .withNode(card1Footer)
      .withNode(card1Likes)
      .withNode(card1LikeIcon)
      .withNode(card1LikeCount)
      .withNode(card1Views)
      .withNode(card1ViewIcon)
      .withNode(card1ViewCount)
      .withNode(contentCard2)
      .withNode(card2Title)
      .withNode(card2Image)
      .withNode(card2Description)
      .withFrame(frame2)
      .withNode(checkoutRoot)
      .withNode(checkoutHeader)
      .withNode(checkoutHeaderLeft)
      .withNode(checkoutBackIcon)
      .withNode(checkoutTitle)
      .withNode(checkoutHeaderBadge)
      .withNode(checkoutLockIcon)
      .withNode(checkoutBadgeText)
      .withNode(checkoutSummaryCard)
      .withNode(summaryTitle)
      .withNode(summarySubtotalRow)
      .withNode(summarySubtotalLabel)
      .withNode(summarySubtotalValue)
      .withNode(summaryShippingRow)
      .withNode(summaryShippingLabel)
      .withNode(summaryShippingValue)
      .withNode(summaryTotalRow)
      .withNode(summaryTotalLabel)
      .withNode(summaryTotalValue)
      .withNode(checkoutItems)
      .withNode(itemsTitle)
      .withNode(itemRow1)
      .withNode(item1Thumb)
      .withNode(item1Info)
      .withNode(item1Name)
      .withNode(item1Meta)
      .withNode(item1Price)
      .withNode(itemRow2)
      .withNode(item2Thumb)
      .withNode(item2Info)
      .withNode(item2Name)
      .withNode(item2Meta)
      .withNode(item2Price)
      .withNode(checkoutPayment)
      .withNode(paymentTitle)
      .withNode(paymentCard)
      .withNode(paymentIcon)
      .withNode(paymentTexts)
      .withNode(paymentLabel)
      .withNode(paymentValue)
      .withNode(deliveryRow)
      .withNode(deliveryLeft)
      .withNode(deliveryIcon)
      .withNode(deliveryLabel)
      .withNode(deliveryEta)
      .withNode(checkoutCta)
      .withNode(checkoutCtaText)
      .withFrame(frame3)
      .withNode(chatRoot)
      .withNode(chatHeader)
      .withNode(chatIdentity)
      .withNode(chatAvatar)
      .withNode(chatIdentityTexts)
      .withNode(chatName)
      .withNode(chatStatus)
      .withNode(chatHeaderActions)
      .withNode(chatCallIcon)
      .withNode(chatMoreIcon)
      .withNode(chatList)
      .withNode(chatDateLabel)
      .withNode(chatMessage1)
      .withNode(chatMessage1Bubble)
      .withNode(chatMessage1Text)
      .withNode(chatMessage2)
      .withNode(chatMessage2Bubble)
      .withNode(chatMessage2Text)
      .withNode(chatMessage3)
      .withNode(chatMessage3Bubble)
      .withNode(chatMessage3Text)
      .withNode(chatMessage4)
      .withNode(chatMessage4Bubble)
      .withNode(chatMessage4Text)
      .withNode(chatComposer)
      .withNode(composerAdd)
      .withNode(composerInput)
      .withNode(composerSend)
      .withNode(composerSendIcon)
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
      .withNode(gptHomeIndicator)
      .withNode(gptBranding)
      .withNode(gptLogo)
      .withNode(gptBrandText)
      .withNode(gptCurated);
}
