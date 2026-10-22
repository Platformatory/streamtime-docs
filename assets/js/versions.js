---
permalink: /assets/js/versions.js
---
/* Progressive enhancement for the version switcher
   (_includes/versions.html). The dropdown opens and closes with plain
   <details>; this only adds close-on-outside-click and Escape, which
   <details> does not do natively. */
(function () {
  "use strict";

  document.querySelectorAll("details[data-versions], details.st-versions").forEach(function (box) {
    document.addEventListener("click", function (e) {
      if (box.open && !box.contains(e.target)) box.open = false;
    });
    box.addEventListener("keydown", function (e) {
      if (e.key === "Escape" && box.open) {
        box.open = false;
        var summary = box.querySelector("summary");
        if (summary) summary.focus();
      }
    });
  });
})();
