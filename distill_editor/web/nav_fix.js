// Prevent browser default horizontal swipes which interfere with navigating
// the app (especially on trackpads triggering Chrome's back/forward).
document.body.style.overscrollBehavior = "none";
document.documentElement.style.overscrollBehavior = "none";

// Apply CSS that helps with some browsers
const style = document.createElement("style");
style.textContent = `
  * {
    overscroll-behavior: none !important;
    -webkit-overflow-scrolling: auto !important;
  }

  body, html {
    touch-action: pan-y !important;
  }
`;
document.head.appendChild(style);
