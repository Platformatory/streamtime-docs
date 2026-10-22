---
permalink: /assets/js/mermaid.js
---
/* Mermaid diagrams for the architecture pages.

   Pages write diagrams as fenced code blocks:

       ```mermaid
       flowchart LR
         a --> b
       ```

   Kramdown renders those as <pre class="language-mermaid"> (rouge marks fenced blocks; the loader matches both). This script loads the
   mermaid library on demand (first mermaid block on the page), themes it
   from the site's colour scheme, and renders the blocks in place. Pages
   without diagrams never download anything.

   The library comes from a CDN pinned to one version, like the site's
   other optional assets. mermaid's strict security level strips scripts
   from diagram text. */
(function () {
  "use strict";
  var MERMAID_SRC = "https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.esm.min.mjs";
  var blocks = document.querySelectorAll(
    'pre.language-mermaid, pre.mermaid, code.language-mermaid, code.mermaid');
  if (!blocks.length) return;

  function theme() {
    var dark = document.documentElement.getAttribute("data-color-mode") === "dark" ||
      matchMedia("(prefers-color-scheme: dark)").matches &&
      !document.querySelector('link[href*="just-the-docs-light"]');
    return dark ? "dark" : "default";
  }

  function render(mermaid) {
    mermaid.initialize({
      startOnLoad: false,
      securityLevel: "strict",
      theme: theme(),
      flowchart: { useMaxWidth: true },
    });
    var i, n = 0;
    var run = function () {
      var el = blocks[i];
      var src = el.textContent;
      var holder = document.createElement("div");
      holder.className = "st-mermaid";
      holder.setAttribute("role", "img");
      holder.setAttribute("aria-label", "Diagram");
      el.replaceWith(holder);
      var id = "st-mermaid-" + n++;
      mermaid.render(id, src).then(function (out) {
        holder.innerHTML = out.svg;
        var svg = holder.querySelector("svg");
        if (svg) { svg.removeAttribute("height"); svg.style.maxWidth = "100%"; }
        if (out.bindFunctions) out.bindFunctions(holder);
      }).catch(function (e) {
        holder.replaceWith(el);
        console.warn("mermaid render failed:", e);
      });
    };
    for (i = 0; i < blocks.length; i++) run();
  }

  import(MERMAID_SRC)
    .then(function (m) { render(m.default || m); })
    .catch(function (e) {
      // Offline/blocked CDN: leave the plain code blocks readable.
      console.warn("mermaid library unavailable:", e);
    });
})();
