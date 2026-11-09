<?php
/**
 * Title: Wasl Live Tracking Demo
 * Slug: wasl/tracking
 * Categories: wasl
 * Keywords: tracking, demo, pickup code, live
 * Inserter: yes
 */
?>
<!-- wp:group {"align":"full","className":"wasl-section-dark","style":{"spacing":{"padding":{"top":"var(--wp--preset--spacing--3xl)","bottom":"var(--wp--preset--spacing--3xl)"}},"color":{"background":"var(--wp--preset--color--midnight)","text":"var(--wp--preset--color--canvas)"}},"layout":{"type":"constrained"}} -->
<div id="tracking" class="wp-block-group alignfull wasl-section-dark has-canvas-color has-midnight-background-color has-text-color has-background" style="padding-top:var(--wp--preset--spacing--3xl);padding-bottom:var(--wp--preset--spacing--3xl)">
<!-- wp:columns {"verticalAlignment":"center","style":{"spacing":{"blockGap":"4rem"}}} -->
<div class="wp-block-columns are-vertically-aligned-center">
<!-- wp:column {"verticalAlignment":"center"} -->
<div class="wp-block-column is-vertically-aligned-center">
<!-- wp:paragraph {"className":"wasl-eyebrow","style":{"typography":{"fontWeight":"700","letterSpacing":"0.08em","textTransform":"uppercase"},"color":{"text":"var(--wp--preset--color--amber)"}},"fontSize":"sm"} -->
<p class="wasl-eyebrow has-amber-color has-text-color has-sm-font-size" style="font-weight:700;letter-spacing:0.08em;text-transform:uppercase">Try it live</p>
<!-- /wp:paragraph -->
<!-- wp:heading {"fontSize":"4xl","textColor":"canvas"} -->
<h2 class="wp-block-heading has-canvas-color has-text-color has-4-xl-font-size">The pickup code.<br>Try it yourself.</h2>
<!-- /wp:heading -->
<!-- wp:paragraph {"fontSize":"lg","style":{"color":{"text":"#d4d4d4"}}} -->
<p class="has-lg-font-size" style="color:#d4d4d4">Every Wasl order carries a 4-character code on its label. The driver types it to confirm pickup — the code never shows on driver screens before pickup. Type the code from the card and see it work.</p>
<!-- /wp:paragraph -->
<!-- wp:group {"className":"wasl-code-try","layout":{"type":"constrained"}} -->
<div class="wp-block-group wasl-code-try">
<!-- wp:paragraph {"fontSize":"sm","style":{"color":{"text":"#d4d4d4"}}} -->
<p class="has-sm-font-size" style="color:#d4d4d4">Delivery #1044 · Mira's Coffee · 2 teas · $30 cash</p>
<!-- /wp:paragraph -->
</div>
<!-- /wp:group -->
</div>
<!-- /wp:column -->
<!-- wp:column {"verticalAlignment":"center"} -->
<div class="wp-block-column is-vertically-aligned-center">
<!-- wp:group {"className":"wasl-code-card","style":{"spacing":{"padding":{"top":"2rem","bottom":"2rem","left":"2rem","right":"2rem"}},"border":{"radius":"1.25rem"},"color":{"background":"#1a1a1a"}},"layout":{"type":"constrained"}} -->
<div class="wp-block-group wasl-code-card has-background" style="background-color:#1a1a1a;border-radius:1.25rem;padding-top:2rem;padding-bottom:2rem;padding-left:2rem;padding-right:2rem">
<!-- wp:paragraph {"fontSize":"sm","style":{"color":{"text":"#a3a3a3"}}} -->
<p class="has-sm-font-size" style="color:#a3a3a3">ENTER PICKUP CODE</p>
<!-- /wp:paragraph -->
<!-- wp:html -->
<div class="wasl-code-input-row">
<input id="wasl-code-input" class="wasl-code-input" type="text" maxlength="4" placeholder="••••" autocomplete="off" autocapitalize="characters" spellcheck="false" aria-label="Pickup code">
<button id="wasl-code-btn" class="wasl-code-btn" type="button">Confirm pickup</button>
</div>
<p id="wasl-code-msg" class="wasl-code-msg" role="status">Hint: the code is on the card above — K7M2</p>
<!-- /wp:html -->
<!-- wp:paragraph {"fontSize":"sm","style":{"color":{"text":"#a3a3a3"}}} -->
<p class="has-sm-font-size" style="color:#a3a3a3">Wrong code? The pickup stays locked. Right code? The driver is on the road.</p>
<!-- /wp:paragraph -->
</div>
<!-- /wp:group -->
</div>
<!-- /wp:column -->
</div>
<!-- /wp:columns -->
</div>
<!-- /wp:group -->
