dsl:1
frame LoginForm - w 375 h 812
  column#root - gap 24 pad 24 bg #FFFFFF w fill h fill
    text#title "Welcome Back" - size 28 weight 700 color #000000
    text#subtitle "Sign in to continue" - size 16 color #666666
    column#fields - gap 20
      column#email_group - gap 8
        text#email_label "Email Address" - size 14 weight 500 color #333333
        container#email_input - h 52 pad 16 bg #F5F5F5 r 10 border 1 #E0E0E0
          text#email_placeholder "Enter your email" - size 16 color #999999
      column#password_group - gap 8
        row#password_header - align spaceBetween,center
          text#password_label "Password" - size 14 weight 500 color #333333
          text#forgot_link "Forgot Password?" - size 14 color #007AFF
        container#password_input - h 52 pad 16 bg #F5F5F5 r 10 border 1 #E0E0E0
          text#password_placeholder "Enter your password" - size 16 color #999999
    container#submit_btn - h 52 bg #007AFF r 10 align center,center
      text#submit_text "Sign In" - size 16 weight 600 color #FFFFFF
    row#divider - gap 16 align center,center
      container#line1 - h 1 w fill bg #E0E0E0
      text#or_text "OR" - size 12 color #999999
      container#line2 - h 1 w fill bg #E0E0E0
    row#social - gap 12
      container#google_btn - h 52 w fill bg #FFFFFF r 10 border 1 #E0E0E0 align center,center
        row#google_content - gap 8 align center,center
          icon#google_icon "google" - iconSet lucide size 20
          text#google_text "Google" - size 14 weight 500
      container#apple_btn - h 52 w fill bg #000000 r 10 align center,center
        row#apple_content - gap 8 align center,center
          icon#apple_icon "apple" - iconSet lucide size 20 color #FFFFFF
          text#apple_text "Apple" - size 14 weight 500 color #FFFFFF
    spacer#bottom_space
    row#signup_row - align center,center gap 4
      text#no_account "Don't have an account?" - size 14 color #666666
      text#signup_link "Sign Up" - size 14 weight 600 color #007AFF

---

dsl:1
frame ContactForm - w 600 h 800
  column#root - gap 32 pad 32 bg #FFFFFF
    column#header - gap 8
      text#title "Contact Us" - size 32 weight 700 color #1A1A1A
      text#subtitle "We'd love to hear from you. Send us a message!" - size 16 color #666666
    column#form - gap 24
      row#name_row - gap 16
        column#first_name - gap 6 w fill
          text#first_label "First Name" - size 14 weight 500 color #333333
          container#first_input - h 48 pad 14 bg #FAFAFA r 8 border 1 #E5E5E5
            text#first_placeholder "John" - size 15 color #999999
        column#last_name - gap 6 w fill
          text#last_label "Last Name" - size 14 weight 500 color #333333
          container#last_input - h 48 pad 14 bg #FAFAFA r 8 border 1 #E5E5E5
            text#last_placeholder "Doe" - size 15 color #999999
      column#email_field - gap 6
        text#email_label "Email" - size 14 weight 500 color #333333
        container#email_input - h 48 pad 14 bg #FAFAFA r 8 border 1 #E5E5E5
          text#email_placeholder "john@example.com" - size 15 color #999999
      column#subject_field - gap 6
        text#subject_label "Subject" - size 14 weight 500 color #333333
        container#subject_input - h 48 pad 14 bg #FAFAFA r 8 border 1 #E5E5E5
          text#subject_placeholder "How can we help?" - size 15 color #999999
      column#message_field - gap 6
        text#message_label "Message" - size 14 weight 500 color #333333
        container#message_input - h 160 pad 14 bg #FAFAFA r 8 border 1 #E5E5E5 align start,start
          text#message_placeholder "Tell us more about your inquiry..." - size 15 color #999999
      container#submit - h 52 bg #2563EB r 8 align center,center
        text#submit_text "Send Message" - size 16 weight 600 color #FFFFFF

---

dsl:1
frame CheckoutForm - w 400 h 700
  column#root - gap 24 pad 24 bg #FFFFFF
    text#title "Payment Details" - size 24 weight 700
    column#card_section - gap 16
      text#card_label "Card Information" - size 14 weight 500 color #333333
      container#card_number - h 52 pad 16 bg #F9F9F9 r 8,8,0,0 border 1 #DEDEDE
        text#card_placeholder "1234 5678 9012 3456" - size 16 color #999999
      row#card_details
        container#expiry - h 52 w fill pad 16 bg #F9F9F9 r 0,0,0,8 border 1 #DEDEDE
          text#expiry_placeholder "MM/YY" - size 16 color #999999
        container#cvc - h 52 w fill pad 16 bg #F9F9F9 r 0,0,8,0 border 1 #DEDEDE
          text#cvc_placeholder "CVC" - size 16 color #999999
    column#billing - gap 12
      text#billing_label "Billing Address" - size 14 weight 500 color #333333
      container#country - h 52 pad 16 bg #F9F9F9 r 8 border 1 #DEDEDE
        row#country_content - align spaceBetween,center
          text#country_text "United States" - size 16
          icon#dropdown "chevron-down" - size 16 color #666666
      container#zip - h 52 pad 16 bg #F9F9F9 r 8 border 1 #DEDEDE
        text#zip_placeholder "ZIP Code" - size 16 color #999999
    container#pay_btn - h 56 bg #5469D4 r 8 align center,center
      row#pay_content - gap 8
        icon#lock "lock" - size 16 color #FFFFFF
        text#pay_text "Pay $99.00" - size 16 weight 600 color #FFFFFF
    row#secure - gap 6 align center,center
      icon#shield "shield-check" - size 14 color #666666
      text#secure_text "Secure payment powered by Stripe" - size 12 color #666666
