---
name: accessibility
description: Use when building web UIs and need to ensure accessibility (a11y) compliance. Covers WCAG guidelines, ARIA patterns, semantic HTML, and testing for accessibility.
---

# Accessibility (a11y)

## Core Principles (WCAG — POUR)

- **Perceivable**: Users must be able to perceive the content (can't be invisible to all senses)
- **Operable**: Users must be able to operate the interface (keyboard, voice, switch)
- **Understandable**: Users must be able to understand the information and interface
- **Robust**: Content must be interpreted reliably by assistive technologies

## Semantic HTML (First Line of Defense)

### Use the Right Element
```html
<!-- Bad: div soup -->
<div class="button" onclick="submit()">Submit</div>
<div class="heading">Page Title</div>

<!-- Good: semantic -->
<button type="submit">Submit</button>
<h1>Page Title</h1>

<!-- Why: screen readers announce element type + content -->
<!-- <button> → "Submit, button" -->
<!-- <div> → "Submit" (user doesn't know it's clickable) -->
```

### Landmarks
```html
<header>    <!-- banner landmark -->
<nav>       <!-- navigation landmark -->
<main>      <!-- main landmark -->
<section>   <!-- region (needs aria-label) -->
<aside>     <!-- complementary landmark -->
<footer>    <!-- contentinfo landmark -->

<!-- Screen reader users can jump between landmarks -->
```

### Headings
```html
<!-- One <h1> per page -->
<h1>Products</h1>
  <h2>Electronics</h2>
    <h3>Phones</h3>
    <h3>Laptops</h3>
  <h2>Clothing</h2>

<!-- Never skip levels: h1 → h3 (missing h2) -->
<!-- Never use heading for styling: <h2 class="text-sm"> -->
```

## Keyboard Accessibility

### Focus Order
```html
<!-- Tab order should follow visual order -->
<!-- tabindex="0" → focusable in natural order -->
<!-- tabindex="-1" → focusable via JS only (modals, skip links) -->
<!-- NEVER: tabindex="1", "2", etc. → nightmare to maintain -->

<!-- Focusable by default: -->
<a>, <button>, <input>, <select>, <textarea>, <details>

<!-- Make custom controls focusable: -->
<div role="button" tabindex="0" onkeydown="handleKey(event)">Click me</div>
```

### Focus Management
```javascript
// After opening a modal: move focus inside
function openModal() {
  dialog.showModal()
  dialog.querySelector("input").focus()
}

// After closing a modal: return focus to trigger
function closeModal() {
  dialog.close()
  triggerButton.focus()
}

// Never: focus trap (user can't escape) without Escape key handler
```

### Skip Link
```html
<!-- First focusable element on page -->
<a href="#main-content" class="skip-link">Skip to main content</a>

<!-- CSS: visually hidden until focused -->
.skip-link:not(:focus) {
  position: absolute;
  width: 1px;
  height: 1px;
  overflow: hidden;
  clip: rect(0, 0, 0, 0);
}
```

## ARIA (When HTML Isn't Enough)

### The First Rule of ARIA
**Don't use ARIA if you can use native HTML.** A `<button>` is always better than `<div role="button">`.

### Common ARIA Patterns
```html
<!-- Live region: announce dynamic content -->
<div aria-live="polite" aria-atomic="true">
  <!-- Screen reader announces when content changes -->
  5 search results found
</div>

<!-- aria-live values:
  "off" — don't announce (default)
  "polite" — announce when user is idle
  "assertive" — announce immediately (use sparingly) -->

<!-- Accessible name: what the screen reader says -->
<button aria-label="Close dialog">X</button>
<nav aria-label="Main navigation">...</nav>

<!-- Described by: additional description -->
<input aria-describedby="password-help" type="password">
<p id="password-help">Password must be at least 8 characters.</p>

<!-- State: -->
<button aria-expanded="false" aria-controls="menu-1">Menu</button>
<div id="menu-1" hidden>...</div>

<!-- role="alert" = assertive live region for errors -->
<div role="alert">Form submission failed. Please try again.</div>
```

### ARIA Don'ts
```html
<!-- Don't: override native semantics -->
<a role="button" href="#">Submit</a>  <!-- Just use <button> -->

<!-- Don't: add role without implementing behavior -->
<div role="button" onclick="...">  <!-- Missing: keyboard handler, focusable -->
<div role="button" tabindex="0" onkeydown="...">  <!-- Good -->

<!-- Don't: orphan aria-controls -->
<button aria-controls="does-not-exist">  <!-- Points to nothing -->

<!-- Don't: aria-labelledby pointing to hidden content -->
<div style="display:none" id="label">...</div>
<input aria-labelledby="label">  <!-- Label is hidden → no accessible name -->
```

## Forms

```html
<!-- Every input needs a label -->
<label for="email">Email address</label>
<input id="email" type="email" required>

<!-- Error messages linked to input -->
<label for="email">Email</label>
<input id="email" aria-describedby="email-error" aria-invalid="true">
<span id="email-error" role="alert">Please enter a valid email.</span>

<!-- Fieldsets for groups -->
<fieldset>
  <legend>Shipping method</legend>
  <input type="radio" id="standard" name="shipping">
  <label for="standard">Standard (5-7 days)</label>
</fieldset>

<!-- Required fields: use required attribute + visual indicator -->
<label for="name">Name <span aria-hidden="true">*</span></label>
<input id="name" required aria-required="true">
```

## Images

```html
<!-- Informative image: describe the content -->
<img src="chart.png" alt="Sales increased 25% in Q3 compared to Q2">

<!-- Decorative image: empty alt -->
<img src="divider.png" alt="">

<!-- Complex image: brief alt + detailed description elsewhere -->
<img src="architecture-diagram.png" alt="System architecture diagram" aria-describedby="diagram-desc">
<div id="diagram-desc">Detailed text description of the diagram...</div>
```

## Color & Contrast

- **WCAG AA**: 4.5:1 for normal text, 3:1 for large text (18px+ bold or 24px+)
- **WCAG AAA**: 7:1 for normal text, 4.5:1 for large text
- Target AA for most projects. AAA for government/healthcare.

### Never Use Color Alone
```html
<!-- Bad: "Fields in red are required" — colorblind users can't see red -->
<!-- Good: "Fields marked with * are required" -->
<label>Name <span aria-hidden="true">*</span></label>

<!-- Bad: "Click the green button" -->
<!-- Good: "Click 'Submit'" -->
```

## Testing

### Automated (Catches ~30% of issues)
```bash
npx axe-core          # Axe: industry standard
npx pa11y-ci          # CI integration
npx lighthouse https://example.com --only-categories=accessibility
```

### Manual (Catches the rest)
- Tab through the page: can you reach everything? Is focus visible?
- Screen reader test: VoiceOver (macOS), NVDA (Windows), TalkBack (Android)
- Zoom to 200%: does everything still work?
- Turn off images: does content still make sense?
- Try with keyboard only (no mouse)

### Accessibility Checklist
- [ ] All images have appropriate alt text
- [ ] Page has a logical heading structure
- [ ] All form inputs have associated labels
- [ ] Color is not the only way to convey information
- [ ] Contrast ratio meets WCAG AA (4.5:1)
- [ ] Keyboard: all functionality available without mouse
- [ ] Skip link present
- [ ] Focus indicator is visible
- [ ] Error messages are announced to screen readers
- [ ] Page has a descriptive `<title>`
- [ ] Language is set: `<html lang="en">`
