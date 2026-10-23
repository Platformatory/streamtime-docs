---
permalink: /assets/js/tabs.js
---
/* Progressive enhancement for the interface tabs
   (_includes/tabs.html, _includes/code-tabs.html). Tabs switch with
   pure CSS; this only adds:

   - the chosen tab per set is remembered in sessionStorage and
     restored on the next visit (before paint, so there is no flash),
   - arrow keys move between tabs while a radio has focus,
   - panels of unchecked tabs are marked inert, so tab order and
     screen readers match the visible tab. Where CSS already hides
     them, inert is redundant but harmless; where it cannot (a panel
     shown by the stacked layout, or a stylesheet that failed to
     load), it keeps hidden content out of the way.

   Nothing here is required: without it the pages still work. */
(function () {
  "use strict";

  var STORE = "st-tabs:" + location.pathname;

  // One set per radio group name.
  var sets = {};
  document.querySelectorAll(".st-tabs__radio").forEach(function (r) {
    (sets[r.name] = sets[r.name] || []).push(r);
  });

  function applyInert(name) {
    (sets[name] || []).forEach(function (radio) {
      var panel = document.getElementById(radio.getAttribute("aria-controls"));
      if (!panel) return;
      if (radio.checked) panel.removeAttribute("inert");
      else panel.setAttribute("inert", "");
    });
  }

  function save(name, radio) {
    try { sessionStorage.setItem(STORE + ":" + name, radio.id); } catch (e) {}
  }

  // Restore stored choices before the browser paints, then sync inert
  // state for every set.
  Object.keys(sets).forEach(function (name) {
    var saved = null;
    try { saved = sessionStorage.getItem(STORE + ":" + name); } catch (e) {}
    if (saved) {
      var el = document.getElementById(saved);
      if (el && sets[name].indexOf(el) >= 0) el.checked = true;
    }
    applyInert(name);
  });

  document.addEventListener("change", function (e) {
    var r = e.target;
    if (!r.classList || !r.classList.contains("st-tabs__radio")) return;
    applyInert(r.name);
    save(r.name, r);
  });

  document.addEventListener("keydown", function (e) {
    if (e.key !== "ArrowRight" && e.key !== "ArrowLeft") return;
    var r = document.activeElement;
    if (!r.classList || !r.classList.contains("st-tabs__radio")) return;
    var group = sets[r.name];
    if (!group) return;
    e.preventDefault();
    var i = group.indexOf(r);
    var next = group[(i + (e.key === "ArrowRight" ? 1 : group.length - 1)) % group.length];
    next.checked = true;
    next.focus();
    applyInert(r.name);
    save(r.name, next);
  });
})();
