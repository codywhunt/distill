dsl:1
frame BasicContainer
  container#root

---

dsl:1
frame ContainerWithSize
  container#root - w 200 h 100

---

dsl:1
frame ContainerFill
  container#root - w fill h fill

---

dsl:1
frame BasicColumn
  column#root - gap 16

---

dsl:1
frame BasicRow
  row#root - gap 12

---

dsl:1
frame BasicText
  text#root "Hello World"

---

dsl:1
frame TextWithProps
  text#root "Styled Text" - size 24 weight 700 color #FF0000

---

dsl:1
frame BasicIcon
  icon#root "home"

---

dsl:1
frame IconWithProps
  icon#root "star" - size 32 color #FFCC00 iconSet lucide

---

dsl:1
frame BasicImage
  img#root "https://example.com/image.png"

---

dsl:1
frame ImageWithProps
  img#root "https://example.com/image.png" - w 200 h 150 fit contain alt "Example image"

---

dsl:1
frame BasicSpacer
  spacer#root

---

dsl:1
frame SpacerWithFlex
  spacer#root - flex 2

---

dsl:1
frame AbsolutePosition
  container#root - pos abs x 100 y 50

---

dsl:1
frame WithPadding
  container#root - pad 24

---

dsl:1
frame SymmetricPadding
  container#root - pad 12,24

---

dsl:1
frame AllSidePadding
  container#root - pad 8,16,24,32

---

dsl:1
frame WithBackground
  container#root - bg #FF5500

---

dsl:1
frame WithTokenBackground
  container#root - bg {color.primary}

---

dsl:1
frame WithRadius
  container#root - r 8

---

dsl:1
frame PerCornerRadius
  container#root - r 8,8,0,0

---

dsl:1
frame WithTokenRadius
  container#root - r {radius.md}

---

dsl:1
frame WithBorder
  container#root - border 1 #CCCCCC

---

dsl:1
frame WithTokenBorder
  container#root - border 2 {color.border}

---

dsl:1
frame WithOpacity
  container#root - opacity 0.5

---

dsl:1
frame WithVisibility
  container#root - visible false

---

dsl:1
frame WithAlignment
  row#root - align center,stretch

---

dsl:1
frame WithGapToken
  column#root - gap {spacing.md}

---

dsl:1
frame WithClip
  container#root - clip

---

dsl:1
frame WithScroll
  column#root - scroll vertical

---

dsl:1
frame TextAlignment
  text#root "Centered" - textAlign center

---

dsl:1
frame TextFamily
  text#root "Custom Font" - family "Inter"

---

dsl:1
frame FrameNameWithSpaces
  container#root

---

dsl:1
frame CustomDimensions - w 1920 h 1080
  container#root
