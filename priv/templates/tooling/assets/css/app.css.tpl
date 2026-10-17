/* See the Tailwind configuration guide for advanced usage
   https://tailwindcss.com/docs/configuration */

@import "tailwindcss" source(none);
@import "phoenix-colocated/__APP__/colocated.css";
@source "../css";
@source "../js";
@source "../../lib/__APP___web";
/* Required for Tailwind to automatically pick up changes in colocated CSS files in dev */
@source "../../_build/dev/phoenix-colocated/__APP__/*/";

/* Add variants based on LiveView classes */
@custom-variant phx-click-loading (.phx-click-loading&, .phx-click-loading &);
@custom-variant phx-submit-loading (.phx-submit-loading&, .phx-submit-loading &);
@custom-variant phx-change-loading (.phx-change-loading&, .phx-change-loading &);

/* Colours are named by role, not by hue, so markup never picks a shade.
   Neutral greys carry the interface; ink marks actions; the brand colour is the signal.
   The brand palette is named only here. Dark mode redefines the same tokens below. */
@theme {
  --color-ground: var(--color-neutral-50);
  --color-surface: var(--color-white);
  --color-ink: var(--color-neutral-950);
  /* neutral-500 is below 4.5:1 contrast for small text on the selection colour. */
  --color-muted: var(--color-neutral-600);
  --color-line: var(--color-neutral-200);
  /* Borders of inputs and secondary buttons, darker than dividers. */
  --color-edge: var(--color-neutral-300);
  --color-accent: var(--color-neutral-950);
  --color-on-accent: var(--color-white);
  --color-selection: var(--color-neutral-100);
  --color-signal: var(--color-__BRAND__-500);
  /* For text, where the 500 shade has too little contrast on white. */
  --color-signal-strong: var(--color-__BRAND__-700);
  --color-danger: var(--color-red-700);
  --color-danger-surface: var(--color-red-50);

  /* A small type scale for dense interfaces. */
  --text-meta: 12px;
  --text-meta--line-height: 1.4;
  --text-label: 13px;
  --text-label--line-height: 1.4;
  --text-body: 15px;
  --text-body--line-height: 1.45;
  --text-title: 22px;
  --text-title--line-height: 1.25;

  --radius-control: 6px;
}

@media (prefers-color-scheme: dark) {
  :root {
    --color-ground: var(--color-neutral-950);
    --color-surface: var(--color-neutral-900);
    --color-ink: var(--color-neutral-100);
    --color-muted: var(--color-neutral-400);
    --color-line: var(--color-neutral-800);
    --color-edge: var(--color-neutral-700);
    --color-accent: var(--color-neutral-100);
    --color-on-accent: var(--color-neutral-950);
    --color-selection: var(--color-neutral-800);
    --color-signal: var(--color-__BRAND__-400);
    --color-signal-strong: var(--color-__BRAND__-400);
    --color-danger: var(--color-red-300);
    --color-danger-surface: var(--color-red-950);
  }
}

/* Links in running text get a brand-coloured underline; ink alone does not read as a link.
   On hover the underline takes the text colour. */
@utility text-link {
  color: var(--color-ink);
  text-decoration-line: underline;
  text-decoration-color: var(--color-signal);
  text-decoration-thickness: 1.5px;
  text-underline-offset: 3px;
  /* Skip-ink would break the coloured underline at every descender. */
  text-decoration-skip-ink: none;
  &:hover { text-decoration-color: currentColor; }
}

/* Make LiveView wrapper divs transparent for layout */
[data-phx-session], [data-phx-teleported-src] { display: contents }

/* This file is for your main application CSS */
