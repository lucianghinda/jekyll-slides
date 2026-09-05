(function (global, factory) {
  var runtime = factory();
  if (typeof module === "object" && module.exports) {
    module.exports = runtime;
  } else {
    global.PresentationRuntime = runtime;
    if (global.document) {
      var start = function () { runtime.init(global.document, global); };
      if (global.document.readyState === "loading") global.document.addEventListener("DOMContentLoaded", start, { once: true });
      else start();
    }
  }
}(typeof globalThis === "object" ? globalThis : this, function () {
  "use strict";

  var controllers = new WeakMap();

  function clamp(value, minimum, maximum) { return Math.min(Math.max(value, minimum), maximum); }
  function requestedSlideFromHash(hash) {
    var match = /^#(\d+)$/.exec(String(hash || ""));
    return match ? Number(match[1]) : null;
  }
  function slideFromHash(hash, total) {
    var requested = requestedSlideFromHash(hash);
    if (requested === null) requested = 1;
    return clamp(Number.isFinite(requested) ? requested : 1, 1, Math.max(total, 1));
  }
  function hashForSlide(number) { return "#" + number; }
  function asArray(collection) { return Array.prototype.slice.call(collection || []); }
  function dataValue(element, name) {
    if (!element) return "";
    if (element.dataset && element.dataset[name] !== undefined) return element.dataset[name];
    return element.getAttribute ? (element.getAttribute("data-" + name) || "") : "";
  }
  function enabled(element, name) { return dataValue(element, name).toLowerCase() === "true"; }
  function addClass(element, name) { if (element && element.classList && name) element.classList.add(name); }
  function removeClass(element, name) { if (element && element.classList && name) element.classList.remove(name); }
  function setAttribute(element, name, value) { if (element && element.setAttribute) element.setAttribute(name, String(value)); }
  function isEditableTarget(target) {
    if (!target) return false;
    var element = target;
    var tag = String(element.tagName || element.nodeName || "").toLowerCase();
    if (["input", "textarea", "select", "button", "a"].indexOf(tag) !== -1 || element.isContentEditable) return true;
    while (element) {
      if (element.getAttribute && element.getAttribute("contenteditable") !== null) return true;
      element = element.parentNode;
    }
    return false;
  }
  function hasNonCollapsedSelection(document) {
    if (!document || !document.getSelection) return false;
    var selection = document.getSelection();
    return Boolean(selection && !selection.isCollapsed);
  }
  function guarded(event, document) {
    return Boolean(event && (event.ctrlKey || event.metaKey || event.altKey || event.shiftKey)) ||
      isEditableTarget(event && event.target) || hasNonCollapsedSelection(document);
  }
  function keyName(event) { return event.key === "Spacebar" ? " " : event.key; }
  function contains(ancestor, element) {
    while (element) {
      if (element === ancestor) return true;
      element = element.parentNode;
    }
    return false;
  }
  function interactiveDescendant(target, boundary) {
    var element = target;
    while (element && element !== boundary) {
      var tag = String(element.tagName || element.nodeName || "").toLowerCase();
      if (["input", "textarea", "select", "button", "a"].indexOf(tag) !== -1 || element.isContentEditable ||
        (element.getAttribute && element.getAttribute("contenteditable") !== null)) return true;
      element = element.parentNode;
    }
    return false;
  }
  function hasModifier(event) {
    return Boolean(event && (event.ctrlKey || event.metaKey || event.altKey || event.shiftKey));
  }
  function toolbarTarget(target, root) {
    var element = target;
    while (element && element !== root) {
      if (element.getAttribute && element.getAttribute("data-presentation-chrome") !== null) return true;
      if (element.getAttribute && ["data-slide-previous", "data-slide-next", "data-slide-overview", "data-slide-fullscreen"].some(function (name) {
        return element.getAttribute(name) !== null;
      })) return true;
      element = element.parentNode;
    }
    return false;
  }

  function createPresentationController(document, window) {
    document = document || (window && window.document);
    window = window || (typeof globalThis === "object" ? globalThis : {});
    if (!document || !document.querySelector) return null;
    var root = document.querySelector("[data-presentation-root]");
    if (!root) return null;
    var existing = controllers.get(root);
    if (existing) return existing;
    var deck = root.querySelector("[data-slide-deck]") || document.querySelector("[data-slide-deck]");
    var slides = asArray(deck && deck.querySelectorAll ? deck.querySelectorAll("[data-slide]") : []);
    var slideSemantics = slides.map(function (slide) {
      return {
        role: slide.getAttribute && slide.getAttribute("role"),
        label: slide.getAttribute && slide.getAttribute("aria-label"),
        tabindex: slide.getAttribute && slide.getAttribute("tabindex")
      };
    });
    var total = slides.length || Number(dataValue(root, "slide-count")) || 1;
    var counter = root.querySelector("[data-slide-counter]");
    var progress = root.querySelector("[data-slide-progress]");
    var previousButton = root.querySelector("[data-slide-previous]");
    var nextButton = root.querySelector("[data-slide-next]");
    var overviewButton = root.querySelector("[data-slide-overview]");
    var fullscreenButton = root.querySelector("[data-slide-fullscreen]");
    var overviewHint = root.querySelector("[data-overview-hint]");
    var overviewEnabled = enabled(root, "overview");
    var fullscreenEnabled = enabled(root, "fullscreen");
    var state = { current: 1, overview: false, printing: false };
    var listeners = [];

    function on(element, eventName, handler, options) {
      if (!element || !element.addEventListener) return;
      element.addEventListener(eventName, handler, options);
      listeners.push(function () { element.removeEventListener(eventName, handler, options); });
    }
    function locationHash() { return window.location && typeof window.location.hash === "string" ? window.location.hash : ""; }
    function fragmentTarget(hash) {
      if (!hash || hash.charAt(0) !== "#" || !document.getElementById) return null;
      try {
        return document.getElementById(decodeURIComponent(hash.slice(1)));
      } catch (error) {
        return null;
      }
    }
    function containingSlideNumber(element) {
      while (element && element !== root) {
        var index = slides.indexOf(element);
        if (index !== -1) return index + 1;
        element = element.parentNode;
      }
      return null;
    }
    function updateHistory(method, number) {
      var history = window.history;
      if (history && typeof history[method] === "function") history[method]({ slide: number }, "", hashForSlide(number));
    }
    function updateOverviewButton() {
      if (!overviewButton) return;
      setAttribute(overviewButton, "aria-pressed", state.overview ? "true" : "false");
      setAttribute(overviewButton, "aria-label", state.overview ? "Close slide overview" : "Show slide overview");
    }
    function updateOverviewHint() {
      if (!overviewHint) return;
      overviewHint.hidden = !state.overview;
      if (state.overview) {
        if (overviewHint.removeAttribute) overviewHint.removeAttribute("hidden");
      } else setAttribute(overviewHint, "hidden", "");
    }
    function updateOverviewDescription() {
      var descriptionId = overviewHint && (overviewHint.id || (overviewHint.getAttribute && overviewHint.getAttribute("id")));
      if (!descriptionId) return;
      if (state.overview) {
        setAttribute(deck, "aria-describedby", descriptionId);
        setAttribute(overviewButton, "aria-describedby", descriptionId);
      } else {
        if (deck && deck.removeAttribute) deck.removeAttribute("aria-describedby");
        if (overviewButton && overviewButton.removeAttribute) overviewButton.removeAttribute("aria-describedby");
      }
    }
    function updateFullscreenButton() {
      if (!fullscreenButton) return;
      var active = Boolean(document.fullscreenElement);
      setAttribute(fullscreenButton, "aria-pressed", active ? "true" : "false");
      setAttribute(fullscreenButton, "aria-label", active ? "Exit fullscreen" : "Enter fullscreen");
      if (active) { addClass(root, "is-fullscreen"); setAttribute(root, "data-fullscreen-active", "true"); }
      else { removeClass(root, "is-fullscreen"); setAttribute(root, "data-fullscreen-active", "false"); }
    }
    function updateSlideVisibility() {
      slides.forEach(function (slide, index) {
        var active = index + 1 === state.current;
        if (active) addClass(slide, "is-active"); else removeClass(slide, "is-active");
        if (state.printing) addClass(slide, "is-printing"); else removeClass(slide, "is-printing");
        var visible = state.printing || state.overview || active;
        slide.hidden = false;
        setAttribute(slide, "aria-hidden", visible ? "false" : "true");
        if (active) setAttribute(slide, "aria-current", "true"); else if (slide.removeAttribute) slide.removeAttribute("aria-current");
        if (state.overview) {
          setAttribute(slide, "role", "button");
          setAttribute(slide, "aria-label", "Open slide " + (index + 1));
          setAttribute(slide, "tabindex", "0");
        } else {
          var semantics = slideSemantics[index];
          if (semantics.role === null) slide.removeAttribute("role"); else setAttribute(slide, "role", semantics.role);
          if (semantics.label === null) slide.removeAttribute("aria-label"); else setAttribute(slide, "aria-label", semantics.label);
          if (semantics.tabindex === null) slide.removeAttribute("tabindex"); else setAttribute(slide, "tabindex", semantics.tabindex);
        }
        if (slide.removeAttribute) slide.removeAttribute("hidden");
      });
    }
    function setPrinting(value) {
      state.printing = Boolean(value);
      if (state.printing) {
        addClass(root, "is-printing");
        setAttribute(root, "data-printing", "true");
      } else {
        removeClass(root, "is-printing");
        if (root.removeAttribute) root.removeAttribute("data-printing");
      }
      render();
    }
    function updateIndicators() {
      if (previousButton) {
        previousButton.disabled = state.current === 1;
        setAttribute(previousButton, "aria-disabled", previousButton.disabled ? "true" : "false");
      }
      if (nextButton) {
        nextButton.disabled = state.current === total;
        setAttribute(nextButton, "aria-disabled", nextButton.disabled ? "true" : "false");
      }
      if (counter) counter.textContent = state.current + " / " + total;
      if (!progress) return;
      progress.max = total; progress.value = state.current;
      setAttribute(progress, "max", total); setAttribute(progress, "value", state.current);
      if (progress.style && progress.style.setProperty) {
        progress.style.setProperty("--progress", String(state.current / total));
        progress.style.setProperty("--progress-percent", (state.current / total * 100) + "%");
      }
    }
    function render() { updateSlideVisibility(); updateIndicators(); updateOverviewButton(); updateOverviewHint(); updateOverviewDescription(); updateFullscreenButton(); }
    function goTo(number, options) {
      var previous = state.current;
      var validNumber = typeof number === "number" && Number.isFinite(number) && Number.isInteger(number);
      state.current = validNumber ? clamp(number, 1, total) : previous;
      render();
      if ((!options || options.history !== false) && state.current !== previous) updateHistory("pushState", state.current);
      return state.current;
    }
    function syncFromLocation(replace) {
      var hash = locationHash();
      var requested = requestedSlideFromHash(hash);
      if (requested === null) {
        var target = fragmentTarget(hash);
        if (target) {
          var containingSlide = containingSlideNumber(target);
          if (containingSlide !== null) state.current = containingSlide;
          render();
          return state.current;
        }
        if (replace) {
          state.current = slideFromHash(hash, total);
          render();
          updateHistory("replaceState", state.current);
        }
        return state.current;
      }
      state.current = clamp(requested, 1, total);
      render();
      if (replace) updateHistory("replaceState", state.current);
      return state.current;
    }
    function setOverview(value) {
      if (!overviewEnabled) return false;
      var wasOverview = state.overview;
      var focused = document.activeElement;
      state.overview = Boolean(value);
      if (state.overview) { addClass(root, "is-overview"); setAttribute(root, "data-overview-active", "true"); }
      else { removeClass(root, "is-overview"); if (root.removeAttribute) root.removeAttribute("data-overview-active"); }
      render();
      if (wasOverview && !state.overview && !state.printing && focused && slides.some(function (slide, index) {
        return index + 1 !== state.current && slide.getAttribute("aria-hidden") === "true" && contains(slide, focused);
      })) {
        var focusTarget = overviewButton || slides[state.current - 1];
        if (focusTarget && typeof focusTarget.focus === "function") focusTarget.focus();
      }
      return state.overview;
    }
    function toggleOverview() { return setOverview(!state.overview); }
    function toggleFullscreen() {
      if (!fullscreenEnabled) return false;
      try {
        if (document.fullscreenElement) {
          if (typeof document.exitFullscreen === "function") {
            var exitResult = document.exitFullscreen();
            if (exitResult && typeof exitResult.catch === "function") exitResult.catch(function () {});
          }
        } else {
          var target = document.documentElement || root;
          if (!target || typeof target.requestFullscreen !== "function") return false;
          var requestResult = target.requestFullscreen();
          if (requestResult && typeof requestResult.catch === "function") requestResult.catch(function () {});
        }
      } catch (error) { /* Fullscreen permissions and support are browser-dependent. */ }
      return true;
    }
    function handleKeydown(event) {
      if (event.defaultPrevented) return;
      var key = keyName(event);
      var toolbar = toolbarTarget(event.target, root);
      var toolbarEscape = toolbar && key === "Escape" && state.overview;
      var toolbarShortcut = toolbarEscape || (toolbar && ["ArrowRight", "ArrowLeft", "PageDown", "PageUp", "Home", "End", "o", "O", "f", "F"].indexOf(key) !== -1);
      if ((!toolbarShortcut && guarded(event, document)) || (toolbarShortcut && (hasModifier(event) || hasNonCollapsedSelection(document)))) return;
      if (key === "Escape" && state.overview) { setOverview(false); if (event.preventDefault) event.preventDefault(); return; }
      if ((key === "o" || key === "O") && overviewEnabled) { toggleOverview(); return; }
      if ((key === "f" || key === "F") && fullscreenEnabled) { toggleFullscreen(); return; }
      var destination;
      if (key === "ArrowRight" || key === " " || key === "PageDown") destination = state.current + 1;
      else if (key === "ArrowLeft" || key === "PageUp") destination = state.current - 1;
      else if (key === "Home") destination = 1;
      else if (key === "End") destination = total;
      if (destination === undefined) return;
      goTo(destination);
      if (event.preventDefault) event.preventDefault();
    }
    function selectOverviewSlide(number) { goTo(number); setOverview(false); }
    function bindSlide(slide, index) {
      on(slide, "click", function (event) {
        if (state.overview && !interactiveDescendant(event.target, slide)) selectOverviewSlide(index + 1);
      });
      on(slide, "keydown", function (event) {
        if (!state.overview || event.target !== slide || (keyName(event) !== "Enter" && keyName(event) !== " ")) return;
        selectOverviewSlide(index + 1); if (event.preventDefault) event.preventDefault();
        if (event.stopPropagation) event.stopPropagation();
      });
    }

    addClass(root, "js");
    var motionQuery = window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)");
    if (motionQuery && motionQuery.matches) { addClass(root, "is-reduced-motion"); setAttribute(root, "data-reduced-motion", "true"); }
    else setAttribute(root, "data-reduced-motion", "false");
    slides.forEach(bindSlide);
    on(document, "keydown", handleKeydown);
    on(window, "popstate", function () { syncFromLocation(false); });
    on(window, "hashchange", function () { syncFromLocation(false); });
    on(window, "beforeprint", function () { setPrinting(true); });
    on(window, "afterprint", function () { setPrinting(false); });
    on(document, "fullscreenchange", updateFullscreenButton);
    on(previousButton, "click", function () { goTo(state.current - 1); });
    on(nextButton, "click", function () { goTo(state.current + 1); });
    on(overviewButton, "click", toggleOverview);
    on(fullscreenButton, "click", toggleFullscreen);
    syncFromLocation(true);
    var controller = {
      goTo: goTo,
      next: function () { return goTo(state.current + 1); },
      previous: function () { return goTo(state.current - 1); },
      toggleOverview: toggleOverview,
      toggleFullscreen: toggleFullscreen,
      get current() { return state.current; },
      get overview() { return state.overview; },
      destroy: function () {
        state.overview = false;
        state.printing = false;
        removeClass(root, "is-overview");
        removeClass(root, "is-printing");
        if (root.removeAttribute) root.removeAttribute("data-overview-active");
        if (root.removeAttribute) root.removeAttribute("data-printing");
        render();
        listeners.splice(0).forEach(function (remove) { remove(); });
        if (controllers.get(root) === controller) controllers.delete(root);
      }
    };
    controllers.set(root, controller);
    return controller;
  }

  return { clamp: clamp, slideFromHash: slideFromHash, hashForSlide: hashForSlide,
    createPresentationController: createPresentationController,
    init: function (document, window) { return createPresentationController(document, window); } };
}));
