dsl:1
frame SimpleContainer
  container#root - w 100 h 100 bg #FFFFFF

---

dsl:1
frame TextOnly
  text#root "Hello World" - size 16 weight 400

---

dsl:1
frame IconOnly
  icon#root "home" - size 24

---

dsl:1
frame ImageOnly
  img#root "https://example.com/image.png" - w 200 h 150 fit cover

---

dsl:1
frame ColumnStack
  column#root - gap 16
    text#a "First"
    text#b "Second"
    text#c "Third"

---

dsl:1
frame RowStack
  row#root - gap 12 align center,center
    icon#icon "star"
    text#label "Rating"

---

dsl:1
frame PaddedContainer
  container#root - pad 24 bg #F5F5F5
    text#content "Padded content"

---

dsl:1
frame StyledContainer
  container#root - w 200 h 100 bg #007AFF r 8 border 1 #0055CC

---

dsl:1
frame SpacerLayout
  column#root - h fill
    text#top "Top"
    spacer#space
    text#bottom "Bottom"

---

dsl:1
frame AbsolutePosition
  container#root - w 300 h 200
    container#box - pos abs x 50 y 50 w 100 h 100 bg #FF5500
