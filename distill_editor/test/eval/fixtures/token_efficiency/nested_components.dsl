dsl:1
frame ProductCard - w 320
  container#card - bg #FFFFFF r 16 shadow 0,4,20,0 #0000001A clip
    column#content
      img#image "product.jpg" - w fill h 200 fit cover
      column#details - gap 12 pad 16
        row#header - align spaceBetween,start
          column#title_group - gap 4 w fill
            text#name "Premium Headphones" - size 18 weight 600 color #1A1A1A
            text#brand "Sony" - size 14 color #666666
          container#badge - pad 6,10 bg #DCFCE7 r 20
            text#badge_text "New" - size 12 weight 500 color #16A34A
        row#rating - gap 4 align start,center
          icon#star1 "star" - size 16 color #FBBF24
          icon#star2 "star" - size 16 color #FBBF24
          icon#star3 "star" - size 16 color #FBBF24
          icon#star4 "star" - size 16 color #FBBF24
          icon#star5 "star" - size 16 color #E5E7EB
          text#reviews "(128)" - size 14 color #666666
        text#description "Experience crystal-clear sound with active noise cancellation" - size 14 color #666666
        row#price_row - align spaceBetween,center
          column#price_group - gap 2
            text#price "$299" - size 24 weight 700 color #1A1A1A
            text#original "$349" - size 14 color #999999
          container#cart_btn - pad 12,20 bg #2563EB r 8
            row#btn_content - gap 8 align center,center
              icon#cart "shopping-cart" - size 18 color #FFFFFF
              text#btn_text "Add to Cart" - size 14 weight 600 color #FFFFFF

---

dsl:1
frame Dashboard - w 1200 h 800
  row#root - bg #F5F7FA h fill
    column#sidebar - w 240 bg #1F2937 pad 24 gap 32
      row#logo - gap 12 align start,center
        container#logo_icon - w 40 h 40 bg #3B82F6 r 8 align center,center
          text#logo_letter "D" - size 20 weight 700 color #FFFFFF
        text#logo_text "Dashboard" - size 18 weight 600 color #FFFFFF
      column#nav - gap 8
        container#nav_item1 - pad 12,16 bg #374151 r 8
          row#nav1_content - gap 12 align start,center
            icon#nav1_icon "home" - size 20 color #FFFFFF
            text#nav1_text "Overview" - size 14 weight 500 color #FFFFFF
        container#nav_item2 - pad 12,16
          row#nav2_content - gap 12 align start,center
            icon#nav2_icon "bar-chart" - size 20 color #9CA3AF
            text#nav2_text "Analytics" - size 14 color #9CA3AF
        container#nav_item3 - pad 12,16
          row#nav3_content - gap 12 align start,center
            icon#nav3_icon "users" - size 20 color #9CA3AF
            text#nav3_text "Customers" - size 14 color #9CA3AF
        container#nav_item4 - pad 12,16
          row#nav4_content - gap 12 align start,center
            icon#nav4_icon "settings" - size 20 color #9CA3AF
            text#nav4_text "Settings" - size 14 color #9CA3AF
      spacer#nav_spacer
      container#user - pad 12 bg #374151 r 12
        row#user_content - gap 12 align start,center
          container#avatar - w 40 h 40 bg #3B82F6 r 20 align center,center
            text#avatar_text "JD" - size 14 weight 600 color #FFFFFF
          column#user_info - gap 2
            text#user_name "John Doe" - size 14 weight 500 color #FFFFFF
            text#user_role "Admin" - size 12 color #9CA3AF
    column#main - w fill pad 32 gap 32
      row#header - align spaceBetween,center
        column#page_title - gap 4
          text#greeting "Good morning, John" - size 24 weight 600 color #1F2937
          text#date "Monday, January 20, 2025" - size 14 color #6B7280
        row#actions - gap 12
          container#search - w 300 h 44 pad 12,16 bg #FFFFFF r 8 border 1 #E5E7EB
            row#search_content - gap 8 align start,center
              icon#search_icon "search" - size 18 color #9CA3AF
              text#search_placeholder "Search..." - size 14 color #9CA3AF
          container#notif - w 44 h 44 bg #FFFFFF r 8 border 1 #E5E7EB align center,center
            icon#bell "bell" - size 20 color #6B7280
      row#stats - gap 24
        container#stat1 - w fill pad 24 bg #FFFFFF r 12 shadow 0,1,3,0 #0000001A
          column#stat1_content - gap 12
            row#stat1_header - align spaceBetween,center
              container#stat1_icon - w 48 h 48 bg #DBEAFE r 10 align center,center
                icon#s1_icon "dollar-sign" - size 24 color #2563EB
              text#stat1_change "+12.5%" - size 14 weight 500 color #16A34A
            text#stat1_value "$45,231" - size 28 weight 700 color #1F2937
            text#stat1_label "Total Revenue" - size 14 color #6B7280
        container#stat2 - w fill pad 24 bg #FFFFFF r 12 shadow 0,1,3,0 #0000001A
          column#stat2_content - gap 12
            row#stat2_header - align spaceBetween,center
              container#stat2_icon - w 48 h 48 bg #FEF3C7 r 10 align center,center
                icon#s2_icon "users" - size 24 color #D97706
              text#stat2_change "+8.2%" - size 14 weight 500 color #16A34A
            text#stat2_value "2,345" - size 28 weight 700 color #1F2937
            text#stat2_label "Total Customers" - size 14 color #6B7280
        container#stat3 - w fill pad 24 bg #FFFFFF r 12 shadow 0,1,3,0 #0000001A
          column#stat3_content - gap 12
            row#stat3_header - align spaceBetween,center
              container#stat3_icon - w 48 h 48 bg #DCFCE7 r 10 align center,center
                icon#s3_icon "package" - size 24 color #16A34A
              text#stat3_change "+23.1%" - size 14 weight 500 color #16A34A
            text#stat3_value "1,892" - size 28 weight 700 color #1F2937
            text#stat3_label "Total Orders" - size 14 color #6B7280
        container#stat4 - w fill pad 24 bg #FFFFFF r 12 shadow 0,1,3,0 #0000001A
          column#stat4_content - gap 12
            row#stat4_header - align spaceBetween,center
              container#stat4_icon - w 48 h 48 bg #FEE2E2 r 10 align center,center
                icon#s4_icon "trending-up" - size 24 color #DC2626
              text#stat4_change "-2.4%" - size 14 weight 500 color #DC2626
            text#stat4_value "3.2%" - size 28 weight 700 color #1F2937
            text#stat4_label "Conversion Rate" - size 14 color #6B7280

---

dsl:1
frame NavigationBar - w 375 h 80
  container#root - bg #FFFFFF shadow 0,-2,10,0 #0000001A
    row#nav - pad 8,24 align spaceAround,center h fill
      column#tab1 - gap 4 align center,center
        icon#t1_icon "home" - size 24 color #2563EB
        text#t1_text "Home" - size 12 weight 500 color #2563EB
      column#tab2 - gap 4 align center,center
        icon#t2_icon "search" - size 24 color #9CA3AF
        text#t2_text "Search" - size 12 color #9CA3AF
      container#fab - w 56 h 56 bg #2563EB r 28 shadow 0,4,12,0 #2563EB40 align center,center
        icon#fab_icon "plus" - size 28 color #FFFFFF
      column#tab3 - gap 4 align center,center
        icon#t3_icon "heart" - size 24 color #9CA3AF
        text#t3_text "Saved" - size 12 color #9CA3AF
      column#tab4 - gap 4 align center,center
        icon#t4_icon "user" - size 24 color #9CA3AF
        text#t4_text "Profile" - size 12 color #9CA3AF
