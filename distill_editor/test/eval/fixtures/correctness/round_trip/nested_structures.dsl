dsl:1
frame SingleChild
  column#root
    text#child "Hello"

---

dsl:1
frame MultipleChildren
  column#root - gap 16
    text#a "First"
    text#b "Second"
    text#c "Third"

---

dsl:1
frame NestedContainers
  container#root - pad 24
    container#inner - pad 16 bg #F5F5F5 r 8
      text#text "Nested"

---

dsl:1
frame MixedLayout
  column#root - gap 24
    row#header - gap 8 align spaceBetween,center
      text#title "Title"
      icon#action "more-horizontal"
    column#body - gap 16
      text#paragraph "Content paragraph"
      text#caption "Caption text" - size 12 color #666666

---

dsl:1
frame DeeplyNested
  column#root - pad 16
    container#level1 - pad 12 bg #F0F0F0
      row#level2 - gap 8
        container#level3a - pad 8 bg #E0E0E0
          text#text1 "A"
        container#level3b - pad 8 bg #E0E0E0
          column#level4 - gap 4
            text#text2 "B1"
            text#text3 "B2"

---

dsl:1
frame CardWithImage
  container#card - bg #FFFFFF r 12 shadow 0,4,12,0 #00000020 clip
    column#content
      img#image "card.jpg" - w fill h 180 fit cover
      column#details - gap 8 pad 16
        text#title "Card Title" - size 18 weight 600
        text#description "Description text" - size 14 color #666666

---

dsl:1
frame ListItem
  row#root - pad 16 gap 12 align start,center
    container#avatar - w 48 h 48 bg #3B82F6 r 24 align center,center
      text#initial "JD" - size 16 weight 600 color #FFFFFF
    column#info - gap 4 w fill
      text#name "John Doe" - size 16 weight 500
      text#email "john@example.com" - size 14 color #666666
    icon#chevron "chevron-right" - size 20 color #CCCCCC

---

dsl:1
frame SpacerBetweenItems
  column#root - h fill pad 24
    text#header "Header"
    spacer#space
    container#footer - h 60 bg #F5F5F5
      text#footer_text "Footer"

---

dsl:1
frame AbsoluteOverlay
  container#root - w 300 h 200
    img#background "bg.jpg" - w fill h fill fit cover
    container#overlay - pos abs x 0 y 0 w fill h fill bg #00000080
    text#label "Overlay Text" - pos abs x 16 y 16 color #FFFFFF

---

dsl:1
frame GridLikeLayout
  column#root - gap 16 pad 16
    row#row1 - gap 16
      container#cell1 - w fill h 100 bg #FFE4E4 r 8
      container#cell2 - w fill h 100 bg #E4FFE4 r 8
    row#row2 - gap 16
      container#cell3 - w fill h 100 bg #E4E4FF r 8
      container#cell4 - w fill h 100 bg #FFFFE4 r 8

---

dsl:1
frame FormField
  column#root - gap 8
    text#label "Email Address" - size 14 weight 500 color #333333
    container#input - h 48 pad 14 bg #FAFAFA r 8 border 1 #E5E5E5
      row#content - align spaceBetween,center
        text#placeholder "Enter email" - size 15 color #999999
        icon#clear "x" - size 18 color #999999

---

dsl:1
frame NavigationItem
  container#root - pad 12,16 bg #EFF6FF r 8
    row#content - gap 12 align start,center
      container#icon_bg - w 36 h 36 bg #3B82F6 r 8 align center,center
        icon#icon "home" - size 18 color #FFFFFF
      text#label "Dashboard" - size 14 weight 500 color #1E40AF

---

dsl:1
frame TabBar
  row#root - bg #FFFFFF border 1 #E5E5E5 r 8
    container#tab1 - w fill pad 12,16 bg #EFF6FF align center,center
      text#t1 "Tab 1" - size 14 weight 500 color #2563EB
    container#tab2 - w fill pad 12,16 align center,center
      text#t2 "Tab 2" - size 14 color #666666
    container#tab3 - w fill pad 12,16 align center,center
      text#t3 "Tab 3" - size 14 color #666666
