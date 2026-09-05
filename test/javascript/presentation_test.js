const test = require("node:test");
const assert = require("node:assert/strict");
const runtime = require("../../assets/js/presentation.js");

class ClassList {
  constructor() { this.values = new Set(); }
  add(value) { if (value) this.values.add(value); }
  remove(value) { this.values.delete(value); }
  contains(value) { return this.values.has(value); }
}

class Element {
  constructor(tagName, attributes = {}) {
    this.tagName = tagName.toUpperCase();
    this.attributes = { ...attributes };
    this.dataset = {};
    Object.keys(attributes).forEach((key) => {
      if (key.startsWith("data-")) this.dataset[key.slice(5)] = attributes[key];
    });
    this.classList = new ClassList();
    (attributes.class || "").split(/\s+/).filter(Boolean).forEach((value) => this.classList.add(value));
    this.listeners = {};
    this.style = { values: {}, setProperty: (key, value) => { this.style.values[key] = value; } };
    this.children = [];
    this.textContent = "";
    this.hidden = false;
    this.focusCount = 0;
    this.motionCalls = 0;
    this.clientWidth = 0;
    this.clientHeight = 0;
  }
  setAttribute(name, value) {
    this.attributes[name] = String(value);
    if (name.startsWith("data-")) this.dataset[name.slice(5)] = String(value);
  }
  getAttribute(name) { return this.attributes[name] ?? null; }
  removeAttribute(name) { delete this.attributes[name]; if (name.startsWith("data-")) delete this.dataset[name.slice(5)]; }
  focus() { this.focusCount += 1; if (this.ownerDocument) this.ownerDocument.activeElement = this; }
  scroll() { this.motionCalls += 1; }
  animate() { this.motionCalls += 1; }
  scrollIntoView() { this.motionCalls += 1; }
  addEventListener(name, handler) { (this.listeners[name] ||= []).push(handler); }
  removeEventListener(name, handler) { this.listeners[name] = (this.listeners[name] || []).filter((item) => item !== handler); }
  dispatch(name, event = {}) {
    const payload = event;
    payload.target ||= this;
    payload.currentTarget = this;
    payload.defaultPrevented ||= false;
    payload.preventDefault ||= (() => { payload.defaultPrevented = true; });
    payload.stopPropagation ||= (() => { payload.propagationStopped = true; });
    (this.listeners[name] || []).slice().forEach((handler) => handler(payload));
    if (!payload.propagationStopped && this.parentNode) this.parentNode.dispatch(name, payload);
    return payload;
  }
  querySelector(selector) {
    if (selector === "[data-slide-deck]") return this.children.find((child) => child.attributes["data-slide-deck"] !== undefined) || null;
    if (selector === "[data-slide-counter]") return this.children.find((child) => child.attributes["data-slide-counter"] !== undefined) || null;
    if (selector === "[data-slide-progress]") return this.children.find((child) => child.attributes["data-slide-progress"] !== undefined) || null;
    if (selector === "[data-slide-overview]") return this.children.find((child) => child.attributes["data-slide-overview"] !== undefined) || null;
    if (selector === "[data-slide-fullscreen]") return this.children.find((child) => child.attributes["data-slide-fullscreen"] !== undefined) || null;
    if (selector === "[data-slide-previous]") return this.children.find((child) => child.attributes["data-slide-previous"] !== undefined) || null;
    if (selector === "[data-slide-next]") return this.children.find((child) => child.attributes["data-slide-next"] !== undefined) || null;
    if (selector === "[data-overview-hint]") return this.children.find((child) => child.attributes["data-overview-hint"] !== undefined) || null;
    return null;
  }
  querySelectorAll(selector) { return selector === "[data-slide]" ? this.children : []; }
}

class Document extends Element {
  constructor(root, slides) {
    super("document");
    this.root = root;
    this.slides = slides;
    this.fullscreenElement = null;
    this.documentElement = new Element("html");
    this.selection = { isCollapsed: true };
  }
  querySelector(selector) { return selector === "[data-presentation-root]" ? this.root : null; }
  getElementById(id) {
    const visit = (element) => {
      if (element.getAttribute && element.getAttribute("id") === id) return element;
      for (const child of element.children || []) {
        const match = visit(child);
        if (match) return match;
      }
      return null;
    };
    return visit(this.root);
  }
  getSelection() { return this.selection; }
}

function fixture({ hash = "", overview = true, fullscreen = true, slideNumbers = true, progress = true, reducedMotion = false, request = "resolve", exit = "resolve", deckWidth = 1920, deckHeight = 1080, slideWidth = 960, viewportWidth = deckWidth, viewportHeight = deckHeight } = {}) {
  const root = new Element("div", {
    "data-presentation-root": "",
    "data-overview": String(overview),
    "data-fullscreen": String(fullscreen),
    "data-slide-numbers": String(slideNumbers),
    "data-progress": String(progress),
    "data-slide-count": "3"
  });
  const deck = new Element("main", { "data-slide-deck": "" });
  deck.clientWidth = deckWidth;
  deck.clientHeight = deckHeight;
  if (overview) deck.setAttribute("aria-describedby", "slides-overview-hint");
  const slides = [1, 2, 3].map((number) => new Element("section", { "data-slide": String(number), id: `slide-${number}` }));
  slides.forEach((slide) => { slide.clientWidth = slideWidth; });
  deck.children = slides;
  const previous = new Element("button", { "data-slide-previous": "" });
  const next = new Element("button", { "data-slide-next": "" });
  const overviewButton = overview ? new Element("button", { "data-slide-overview": "", "aria-describedby": "slides-overview-hint" }) : null;
  const fullscreenButton = fullscreen ? new Element("button", { "data-slide-fullscreen": "" }) : null;
  const counter = slideNumbers ? new Element("p", { "data-slide-counter": "" }) : null;
  const progressElement = progress ? new Element("progress", { "data-slide-progress": "" }) : null;
  const hint = overview ? new Element("p", { "data-overview-hint": "", id: "slides-overview-hint" }) : null;
  if (hint) hint.hidden = true;
  root.children = [deck, previous, next, overviewButton, fullscreenButton, counter, progressElement, hint].filter(Boolean);
  const document = new Document(root, slides);
  root.parentNode = document;
  root.children.forEach((child) => { child.parentNode = root; });
  deck.children.forEach((slide) => { slide.parentNode = deck; });
  [root, deck, previous, next, overviewButton, fullscreenButton, counter, progressElement, hint, ...slides].filter(Boolean).forEach((element) => {
    element.ownerDocument = document;
  });
  const history = { calls: [], replaceState(_state, _title, value) { this.calls.push(["replaceState", value]); window.location.hash = value; }, pushState(_state, _title, value) { this.calls.push(["pushState", value]); window.location.hash = value; } };
  const window = {
    location: { hash }, history, listeners: {}, innerWidth: viewportWidth, innerHeight: viewportHeight,
    addEventListener(name, handler) { (this.listeners[name] ||= []).push(handler); },
    removeEventListener(name, handler) { this.listeners[name] = (this.listeners[name] || []).filter((item) => item !== handler); },
    dispatch(name) { (this.listeners[name] || []).slice().forEach((handler) => handler()); },
    matchMedia() { return { matches: false }; }
  };
  document.documentElement.requestFullscreen = () => {
    if (request === "reject") return Promise.reject(new Error("permission denied"));
    document.fullscreenElement = document.documentElement; document.dispatch("fullscreenchange");
  };
  document.exitFullscreen = () => {
    if (exit === "reject") return Promise.reject(new Error("exit failed"));
    document.fullscreenElement = null; document.dispatch("fullscreenchange");
  };
  window.matchMedia = () => ({ matches: reducedMotion });
  return { root, deck, slides, previous, next, overviewButton, fullscreenButton, counter, progress: progressElement, hint, document, window, history };
}

function key(document, keyName, target, options = {}) {
  return document.dispatch("keydown", { ...options, key: keyName, target });
}

function addAnchor(view, slideIndex, id) {
  const anchor = new Element("span", { id });
  anchor.parentNode = view.slides[slideIndex];
  anchor.ownerDocument = view.document;
  view.slides[slideIndex].children.push(anchor);
  return anchor;
}

test("pure hash helpers clamp safely", () => {
  assert.equal(runtime.slideFromHash("#2", 3), 2);
  assert.equal(runtime.slideFromHash("#99", 3), 3);
  assert.equal(runtime.slideFromHash("#wat", 3), 1);
  assert.equal(runtime.hashForSlide(2), "#2");
});

test("each navigation key changes destination, pushes its hash, and prevents default", () => {
  for (const [keyName, start, expected] of [["ArrowRight", 1, 2], [" ", 1, 2], ["PageDown", 1, 2], ["ArrowLeft", 2, 1], ["PageUp", 2, 1], ["Home", 2, 1], ["End", 2, 3]]) {
    const view = fixture({ hash: `#${start}` });
    const controller = runtime.init(view.document, view.window);
    const event = key(view.document, keyName);
    assert.equal(controller.current, expected, `${keyName} destination`);
    assert.equal(event.defaultPrevented, true, `${keyName} is handled`);
    assert.deepEqual(view.history.calls.at(-1), ["pushState", `#${expected}`], `${keyName} history`);
  }
  const unhandledView = fixture({ hash: "#1" });
  const unhandledController = runtime.init(unhandledView.document, unhandledView.window);
  const unhandled = key(unhandledView.document, "x");
  assert.equal(unhandledController.current, 1);
  assert.equal(unhandled.defaultPrevented, false);
});

test("previous and next buttons navigate with pushed history entries", () => {
  const previousView = fixture({ hash: "#2" });
  const previousController = runtime.init(previousView.document, previousView.window);
  const previousEvent = previousView.previous.dispatch("click");
  assert.equal(previousController.current, 1);
  assert.deepEqual(previousView.history.calls.at(-1), ["pushState", "#1"]);
  assert.equal(previousEvent.defaultPrevented, false);

  const nextView = fixture({ hash: "#1" });
  const nextController = runtime.init(nextView.document, nextView.window);
  nextView.next.dispatch("click");
  assert.equal(nextController.current, 2);
  assert.deepEqual(nextView.history.calls.at(-1), ["pushState", "#2"]);
});

test("previous and next buttons expose disabled state at the deck boundaries", () => {
  const view = fixture({ hash: "#1" });
  const controller = runtime.init(view.document, view.window);

  assert.equal(view.previous.disabled, true);
  assert.equal(view.previous.getAttribute("aria-disabled"), "true");
  assert.equal(view.next.disabled, false);
  assert.equal(view.next.getAttribute("aria-disabled"), "false");

  controller.goTo(2);
  assert.equal(view.previous.disabled, false);
  assert.equal(view.next.disabled, false);

  controller.goTo(3);
  assert.equal(view.previous.disabled, false);
  assert.equal(view.next.disabled, true);
  assert.equal(view.next.getAttribute("aria-disabled"), "true");
});

test("invalid, zero, and out-of-range initial hashes clamp and normalize with replaceState", () => {
  for (const [hash, expected] of [["#0", 1], ["#99", 3], ["#invalid", 1], ["", 1]]) {
    const view = fixture({ hash });
    const controller = runtime.init(view.document, view.window);
    assert.equal(controller.current, expected, hash || "empty hash");
    assert.deepEqual(view.history.calls, [["replaceState", `#${expected}`]]);
    assert.equal(view.window.location.hash, `#${expected}`);
  }
});

test("navigation writes history and popstate synchronizes without writing", () => {
  const view = fixture();
  const controller = runtime.init(view.document, view.window);
  const initialCalls = view.history.calls.length;
  controller.next();
  assert.deepEqual(view.history.calls.at(-1), ["pushState", "#2"]);
  view.window.location.hash = "#1";
  view.window.dispatch("popstate");
  assert.equal(controller.current, 1);
  assert.equal(view.history.calls.length, initialCalls + 1);
  view.window.location.hash = "#2";
  view.window.dispatch("popstate");
  assert.equal(controller.current, 2);
  assert.equal(view.history.calls.length, initialCalls + 1);
});

test("hashchange synchronizes direct URL edits without creating history", () => {
  const view = fixture({ hash: "#1" });
  const controller = runtime.init(view.document, view.window);
  const calls = view.history.calls.length;
  view.window.location.hash = "#3";
  view.window.dispatch("hashchange");
  assert.equal(controller.current, 3);
  assert.equal(view.history.calls.length, calls);
});

test("hashchange ignores nonnumeric internal anchors and keeps the current slide state", () => {
  const view = fixture({ hash: "#3" });
  const controller = runtime.init(view.document, view.window);
  const calls = view.history.calls.length;

  for (const hash of ["#fn:x", "#section"]) {
    view.window.location.hash = hash;
    view.window.dispatch("hashchange");
    assert.equal(controller.current, 3, `${hash} keeps the active slide`);
    assert.equal(view.previous.disabled, false, `${hash} keeps previous enabled`);
    assert.equal(view.next.disabled, true, `${hash} keeps next disabled`);
    assert.equal(view.history.calls.length, calls, `${hash} does not write history`);
  }
});

test("valid internal anchors activate their containing slide without replacing the fragment", () => {
  const initial = fixture({ hash: "#fn:detail" });
  addAnchor(initial, 1, "fn:detail");

  const initialController = runtime.init(initial.document, initial.window);

  assert.equal(initialController.current, 2);
  assert.equal(initial.window.location.hash, "#fn:detail");
  assert.deepEqual(initial.history.calls, []);

  initialController.goTo(3);
  const calls = initial.history.calls.length;
  initial.window.location.hash = "#fn:detail";
  initial.window.dispatch("popstate");
  assert.equal(initialController.current, 2);
  assert.equal(initial.history.calls.length, calls);
  assert.equal(initial.window.location.hash, "#fn:detail");
});

test("keyboard navigation ignores editable, modified, and selected interactions", () => {
  const view = fixture();
  const controller = runtime.init(view.document, view.window);
  for (const tag of ["input", "textarea", "select", "button", "a"]) {
    const event = key(view.document, "ArrowRight", new Element(tag));
    assert.equal(controller.current, 1, `${tag} guard`);
    assert.equal(event.defaultPrevented, false, `${tag} does not prevent default`);
  }
  const editable = new Element("div", { contenteditable: "true" });
  const editableDescendant = new Element("span"); editableDescendant.parentNode = editable;
  const editableEvent = key(view.document, "ArrowRight", editableDescendant);
  assert.equal(controller.current, 1, "contenteditable descendant guard");
  assert.equal(editableEvent.defaultPrevented, false);
  for (const modifier of ["metaKey", "ctrlKey", "altKey", "shiftKey"]) {
    const event = key(view.document, "ArrowRight", new Element("div"), { [modifier]: true });
    assert.equal(controller.current, 1, `${modifier} guard`);
    assert.equal(event.defaultPrevented, false, `${modifier} does not prevent default`);
  }
  view.document.selection.isCollapsed = false;
  const selectionEvent = key(view.document, "ArrowRight");
  assert.equal(controller.current, 1);
  assert.equal(selectionEvent.defaultPrevented, false, "selection does not prevent default");
  view.document.selection.isCollapsed = true;
  const handled = key(view.document, "ArrowRight");
  assert.equal(controller.current, 2); assert.equal(handled.defaultPrevented, true);
});

test("runtime marks root, maintains one active slide, and never moves focus during navigation", () => {
  const view = fixture();
  const controller = runtime.init(view.document, view.window);
  assert.equal(view.root.classList.contains("js"), true);
  assert.equal(view.slides.filter((slide) => slide.classList.contains("is-active")).length, 1);
  assert.equal(view.slides.filter((slide) => slide.getAttribute("aria-hidden") === "false").length, 1);
  assert.equal(view.slides.every((slide) => slide.hidden === false && slide.getAttribute("hidden") === null), true);
  assert.equal(view.slides.filter((slide) => slide.getAttribute("aria-hidden") === "false").length, 1);
  view.document.activeElement = view.root;
  const focusTargets = [view.root, view.deck, view.previous, view.next, view.overviewButton, view.fullscreenButton, ...view.slides].filter(Boolean);
  const focusBefore = focusTargets.map((element) => element.focusCount);
  controller.next();
  assert.equal(view.slides.filter((slide) => slide.classList.contains("is-active")).length, 1);
  assert.equal(view.slides.filter((slide) => slide.getAttribute("aria-hidden") === "false").length, 1);
  assert.equal(view.slides.every((slide) => slide.getAttribute("hidden") === null), true);
  controller.toggleOverview();
  controller.previous();
  assert.equal(view.document.activeElement, view.root);
  assert.deepEqual(focusTargets.map((element) => element.focusCount), focusBefore);
  assert.equal(focusTargets.reduce((sum, element) => sum + element.motionCalls, 0), 0);
});

test("F toggles supported fullscreen and O/Escape toggle overview", () => {
  const view = fixture();
  const controller = runtime.init(view.document, view.window);
  key(view.document, "f"); assert.equal(view.document.fullscreenElement, view.document.documentElement);
  assert.equal(view.fullscreenButton.getAttribute("aria-pressed"), "true");
  assert.equal(view.fullscreenButton.getAttribute("aria-label"), "Exit fullscreen");
  view.document.dispatch("fullscreenchange");
  view.document.exitFullscreen(); assert.equal(view.fullscreenButton.getAttribute("aria-pressed"), "false");
  assert.equal(view.fullscreenButton.getAttribute("aria-label"), "Enter fullscreen");
  key(view.document, "o"); assert.equal(controller.overview, true);
  assert.equal(view.overviewButton.getAttribute("aria-pressed"), "true");
  assert.equal(view.overviewButton.getAttribute("aria-label"), "Close slide overview");
  assert.equal(view.slides.every((slide) => slide.getAttribute("aria-hidden") === "false" && slide.getAttribute("hidden") === null), true);
  key(view.document, "Escape"); assert.equal(controller.overview, false);
  assert.equal(view.overviewButton.getAttribute("aria-pressed"), "false");
});

test("overview Escape closes from the focused toolbar button while Space and Enter remain native", () => {
  const view = fixture({ hash: "#1" });
  const controller = runtime.init(view.document, view.window);
  controller.toggleOverview();
  view.document.activeElement = view.overviewButton;
  const escape = key(view.document, "Escape", view.overviewButton);
  assert.equal(controller.overview, false);
  assert.equal(escape.defaultPrevented, true);

  controller.toggleOverview();
  const space = key(view.document, " ", view.overviewButton);
  assert.equal(controller.overview, true);
  assert.equal(space.defaultPrevented, false);
  const enter = key(view.document, "Enter", view.overviewButton);
  assert.equal(controller.overview, true);
  assert.equal(enter.defaultPrevented, false);
});

test("toolbar retains global navigation shortcuts without unguarding modifiers or slide-content links", () => {
  const view = fixture({ hash: "#2" });
  const controller = runtime.init(view.document, view.window);
  const toolbarArrow = key(view.document, "ArrowRight", view.next);
  assert.equal(controller.current, 3);
  assert.equal(toolbarArrow.defaultPrevented, true);
  controller.goTo(2);
  const toolbarHome = key(view.document, "Home", view.previous);
  assert.equal(controller.current, 1);
  assert.equal(toolbarHome.defaultPrevented, true);
  controller.goTo(2);
  const toolbarEnd = key(view.document, "End", view.next);
  assert.equal(controller.current, 3);
  const modified = key(view.document, "ArrowLeft", view.next, { ctrlKey: true });
  assert.equal(controller.current, 3);
  assert.equal(modified.defaultPrevented, false);

  controller.goTo(1);
  key(view.document, "PageDown", view.next);
  assert.equal(controller.current, 2);
  key(view.document, "PageUp", view.previous);
  assert.equal(controller.current, 1);
  key(view.document, "o", view.overviewButton);
  assert.equal(controller.overview, true);
  key(view.document, "o", view.overviewButton);
  assert.equal(controller.overview, false);
  key(view.document, "o", view.next);
  assert.equal(controller.overview, true);
  const toolbarEscape = key(view.document, "Escape", view.next);
  assert.equal(controller.overview, false);
  assert.equal(toolbarEscape.defaultPrevented, true);
  key(view.document, "f", view.fullscreenButton);
  assert.equal(view.document.fullscreenElement, view.document.documentElement);

  view.document.selection.isCollapsed = false;
  const selected = key(view.document, "ArrowRight", view.next);
  assert.equal(controller.current, 1);
  assert.equal(selected.defaultPrevented, false);
  view.document.selection.isCollapsed = true;

  const link = new Element("a");
  const linkInSlide = new Element("span"); linkInSlide.parentNode = view.slides[2]; link.parentNode = linkInSlide;
  const linkEvent = key(view.document, "ArrowLeft", link);
  assert.equal(controller.current, 1);
  assert.equal(linkEvent.defaultPrevented, false);
});

test("fullscreen is disabled or unsupported without throwing", async () => {
  const disabled = fixture({ fullscreen: false });
  const disabledController = runtime.init(disabled.document, disabled.window);
  assert.equal(disabledController.toggleFullscreen(), false);
  assert.equal(disabled.fullscreenButton, null);

  const unsupported = fixture();
  delete unsupported.document.documentElement.requestFullscreen;
  const unsupportedController = runtime.init(unsupported.document, unsupported.window);
  assert.equal(unsupportedController.toggleFullscreen(), false);

  const rejectedRequest = fixture({ request: "reject" });
  const rejectedController = runtime.init(rejectedRequest.document, rejectedRequest.window);
  assert.equal(rejectedController.toggleFullscreen(), true);
  await new Promise((resolve) => setImmediate(resolve));
  assert.equal(rejectedRequest.fullscreenButton.getAttribute("aria-pressed"), "false");

  const rejectedExit = fixture({ exit: "reject" });
  const rejectedExitController = runtime.init(rejectedExit.document, rejectedExit.window);
  rejectedExit.document.fullscreenElement = rejectedExit.document.documentElement;
  rejectedExit.document.dispatch("fullscreenchange");
  assert.equal(rejectedExitController.toggleFullscreen(), true);
  await new Promise((resolve) => setImmediate(resolve));
  assert.equal(rejectedExit.fullscreenButton.getAttribute("aria-pressed"), "true");
});

test("overview click and keyboard selection navigate and exit", () => {
  const view = fixture();
  const controller = runtime.init(view.document, view.window);
  controller.toggleOverview();
  view.slides[1].dispatch("click");
  assert.equal(controller.current, 2); assert.equal(controller.overview, false);
  controller.toggleOverview();
  view.slides[2].dispatch("keydown", { key: "Enter" });
  assert.equal(controller.current, 3); assert.equal(controller.overview, false);
});

test("overview click, Enter, and Space preserve the same deck children and slide objects", () => {
  for (const [method, target, eventName, keyName] of [
    ["click", 0, "click"], ["keyboard", 1, "keydown", "Enter"], ["keyboard", 2, "keydown", " "]
  ]) {
    const view = fixture();
    const originalChildren = view.deck.children.slice();
    const originalSlides = view.slides.slice();
    const controller = runtime.init(view.document, view.window);
    view.document.activeElement = view.root;
    controller.toggleOverview();
    if (method === "click") view.slides[target].dispatch(eventName);
    else view.slides[target].dispatch(eventName, { key: keyName });
    assert.equal(controller.overview, false, `${method} exits overview`);
    assert.equal(view.deck.children.length, originalChildren.length, `${method} child count`);
    assert.deepEqual(view.deck.children, originalChildren, `${method} child identity`);
    assert.deepEqual(view.slides, originalSlides, `${method} slide identity`);
  }
});

test("keyboard selection activates the intended slide before closing and preserves its focus", () => {
  const view = fixture({ hash: "#1" });
  const controller = runtime.init(view.document, view.window);
  controller.toggleOverview();
  view.document.activeElement = view.slides[1];
  const focusBefore = view.slides[1].focusCount;
  view.slides[1].dispatch("keydown", { key: "Enter" });
  assert.equal(controller.current, 2);
  assert.equal(controller.overview, false);
  assert.equal(view.document.activeElement, view.slides[1]);
  assert.equal(view.slides[1].focusCount, focusBefore);
});

test("bubbling Space activation exits on the selected slide and never advances again", () => {
  const view = fixture({ hash: "#1" });
  const controller = runtime.init(view.document, view.window);
  controller.toggleOverview();
  const callsBefore = view.history.calls.length;
  const event = view.slides[1].dispatch("keydown", { key: " " });
  assert.equal(controller.current, 2);
  assert.equal(controller.overview, false);
  assert.equal(view.history.calls.length, callsBefore + 1);
  assert.deepEqual(view.history.calls.at(-1), ["pushState", "#2"]);
  assert.equal(event.defaultPrevented, true);
});

test("overview exit repairs focus only when the focused slide will become hidden", () => {
  const view = fixture({ hash: "#1" });
  const controller = runtime.init(view.document, view.window);
  controller.toggleOverview();
  view.document.activeElement = view.slides[1];
  view.slides[0].dispatch("click");
  assert.equal(controller.current, 1);
  assert.equal(controller.overview, false);
  assert.equal(view.document.activeElement, view.overviewButton);
  assert.equal(view.overviewButton.focusCount, 1);

  view.document.activeElement = view.root;
  const focusBefore = view.overviewButton.focusCount;
  controller.next();
  assert.equal(view.document.activeElement, view.root);
  assert.equal(view.overviewButton.focusCount, focusBefore);
});

test("overview ignores interactive descendants but selects noninteractive descendants", () => {
  for (const tag of ["a", "button", "input", "textarea", "select"]) {
    const view = fixture();
    const controller = runtime.init(view.document, view.window);
    controller.toggleOverview();
    const child = new Element(tag); child.parentNode = view.slides[1];
    const event = child.dispatch("click");
    assert.equal(controller.current, 1, `${tag} click is ignored`);
    assert.equal(controller.overview, true, `${tag} keeps overview open`);
    assert.equal(event.defaultPrevented, false);
    const keyboardEvent = child.dispatch("keydown", { key: "Enter" });
    assert.equal(controller.current, 1, `${tag} keyboard is ignored`);
    assert.equal(controller.overview, true, `${tag} keyboard keeps overview open`);
    assert.equal(keyboardEvent.defaultPrevented, false);
  }
  const editableView = fixture();
  const editableController = runtime.init(editableView.document, editableView.window);
  editableController.toggleOverview();
  const editable = new Element("span", { contenteditable: "true" }); editable.parentNode = editableView.slides[1];
  editable.dispatch("click");
  assert.equal(editableController.current, 1);
  assert.equal(editableController.overview, true);

  const plainView = fixture();
  const plainController = runtime.init(plainView.document, plainView.window);
  plainController.toggleOverview();
  const plain = new Element("span"); plain.parentNode = plainView.slides[1];
  plain.dispatch("click");
  assert.equal(plainController.current, 2);
  assert.equal(plainController.overview, false);

  const plainKeyboardView = fixture();
  const plainKeyboardController = runtime.init(plainKeyboardView.document, plainKeyboardView.window);
  plainKeyboardController.toggleOverview();
  const plainKeyboard = new Element("span"); plainKeyboard.parentNode = plainKeyboardView.slides[1];
  plainKeyboard.dispatch("keydown", { key: "Enter" });
  assert.equal(plainKeyboardController.current, 1);
  assert.equal(plainKeyboardController.overview, true);
});

test("init is idempotent per root and destroy permits a fresh controller", () => {
  const view = fixture();
  const first = runtime.init(view.document, view.window);
  const second = runtime.init(view.document, view.window);
  assert.equal(second, first);
  const callsBefore = view.history.calls.length;
  key(view.document, "ArrowRight");
  assert.equal(view.history.calls.length, callsBefore + 1);
  first.destroy();
  const fresh = runtime.init(view.document, view.window);
  assert.notEqual(fresh, first);
  const freshCalls = view.history.calls.length;
  key(view.document, "ArrowLeft");
  assert.equal(view.history.calls.length, freshCalls + 1);
});

test("destroy normalizes open overview state and preserves immutable configuration across reinit", () => {
  for (const open of [false, true]) {
    const view = fixture({ overview: true });
    const controller = runtime.init(view.document, view.window);
    if (open) controller.toggleOverview();
    controller.destroy();
    assert.equal(view.root.dataset.overview, "true");
    assert.equal(view.root.getAttribute("data-overview-active"), null);
    assert.equal(view.root.classList.contains("is-overview"), false);
    assert.equal(view.hint.hidden, true);
    assert.equal(view.slides.filter((slide) => slide.getAttribute("aria-hidden") === "false").length, 1);
    assert.equal(view.slides.every((slide) => slide.getAttribute("hidden") === null), true);
    const fresh = runtime.init(view.document, view.window);
    assert.notEqual(fresh, controller);
    assert.equal(fresh.toggleOverview(), true, `${open ? "open" : "closed"} reinit remains enabled`);
    assert.equal(view.root.dataset.overview, "true");
  }
});

test("overview instructions are hidden outside overview and shown while active", () => {
  const view = fixture();
  const controller = runtime.init(view.document, view.window);
  assert.equal(view.hint.hidden, true);
  assert.equal(view.overviewButton.getAttribute("aria-describedby"), null);
  assert.equal(view.deck.getAttribute("aria-describedby"), null);
  controller.toggleOverview();
  assert.equal(view.hint.hidden, false);
  assert.equal(view.overviewButton.getAttribute("aria-describedby"), "slides-overview-hint");
  assert.equal(view.deck.getAttribute("aria-describedby"), "slides-overview-hint");
  controller.toggleOverview();
  assert.equal(view.hint.hidden, true);
  assert.equal(view.overviewButton.getAttribute("aria-describedby"), null);
  assert.equal(view.deck.getAttribute("aria-describedby"), null);
});

test("overview thumbnails expose actionable semantics and restore section semantics on close/destroy", () => {
  const view = fixture();
  const controller = runtime.init(view.document, view.window);
  assert.equal(view.slides.every((slide) => slide.getAttribute("role") === null), true);
  assert.equal(view.slides.every((slide) => slide.getAttribute("tabindex") === null), true);
  controller.toggleOverview();
  view.slides.forEach((slide, index) => {
    assert.equal(slide.getAttribute("role"), "button");
    assert.equal(slide.getAttribute("aria-label"), `Open slide ${index + 1}`);
    assert.equal(slide.getAttribute("tabindex"), "0");
  });
  controller.toggleOverview();
  assert.equal(view.slides.every((slide) => slide.getAttribute("role") === null), true);
  assert.equal(view.slides.every((slide) => slide.getAttribute("aria-label") === null), true);
  assert.equal(view.slides.every((slide) => slide.getAttribute("tabindex") === null), true);
  controller.toggleOverview();
  controller.destroy();
  assert.equal(view.slides.every((slide) => slide.getAttribute("role") === null), true);
  assert.equal(view.slides.every((slide) => slide.getAttribute("tabindex") === null), true);
});

test("public goTo accepts finite integers only and preserves valid slide state for invalid inputs", () => {
  const view = fixture({ hash: "#2" });
  const controller = runtime.init(view.document, view.window);
  for (const invalid of [NaN, Infinity, -Infinity, 1.5, "3", null, undefined]) {
    controller.goTo(invalid);
    assert.equal(controller.current, 2, `${String(invalid)} leaves current slide intact`);
    assert.equal(view.slides.filter((slide) => slide.classList.contains("is-active")).length, 1);
    assert.equal(view.slides.filter((slide) => slide.getAttribute("aria-hidden") === "false").length, 1);
    assert.equal(view.slides.every((slide) => slide.getAttribute("hidden") === null), true);
  }
  controller.goTo(3);
  assert.equal(controller.current, 3);
});

test("overview is disabled when configured off and never clones slide content", () => {
  const view = fixture({ overview: false });
  const originalSlides = view.slides.slice();
  const controller = runtime.init(view.document, view.window);
  assert.equal(view.hint, null);
  assert.equal(view.deck.getAttribute("aria-describedby"), null);
  assert.equal(controller.toggleOverview(), false);
  key(view.document, "o");
  assert.equal(controller.overview, false);
  view.slides[1].dispatch("click");
  assert.equal(controller.current, 1);
  assert.deepEqual(view.slides, originalSlides);
});

test("overview accepts Enter and Space selection and exposes reduced-motion state", () => {
  const view = fixture({ reducedMotion: true });
  const controller = runtime.init(view.document, view.window);
  assert.equal(view.root.classList.contains("is-reduced-motion"), true);
  assert.equal(view.root.getAttribute("data-reduced-motion"), "true");
  controller.toggleOverview();
  const enter = view.slides[1].dispatch("keydown", { key: "Enter" });
  assert.equal(enter.defaultPrevented, true);
  assert.equal(controller.current, 2);
  controller.toggleOverview();
  const space = view.slides[2].dispatch("keydown", { key: " " });
  assert.equal(space.defaultPrevented, true);
  assert.equal(controller.current, 3);
  const elements = [view.root, view.deck, view.previous, view.next, view.overviewButton, view.fullscreenButton, view.counter, view.progress, ...view.slides].filter(Boolean);
  assert.equal(elements.reduce((sum, element) => sum + element.motionCalls, 0), 0);
});

test("active slide, aria-hidden, counter, and progress stay synchronized", () => {
  const view = fixture({ hash: "#2" });
  const controller = runtime.init(view.document, view.window);
  assert.equal(view.slides[1].classList.contains("is-active"), true);
  assert.equal(view.slides[0].getAttribute("aria-hidden"), "true");
  assert.equal(view.counter.textContent, "2 / 3");
  assert.equal(view.progress.value, 2);
  assert.equal(view.progress.style.values["--progress"], String(2 / 3));
  controller.next();
  assert.equal(view.slides[1].getAttribute("aria-hidden"), "true");
  assert.equal(view.slides[2].getAttribute("aria-hidden"), "false");
  assert.equal(view.counter.textContent, "3 / 3");
});

test("leaves canvas and overview scaling to CSS", () => {
  const view = fixture({ deckWidth: 960, deckHeight: 540, slideWidth: 480, reducedMotion: true });
  const controller = runtime.init(view.document, view.window);
  assert.equal(view.root.style.values["--slide-scale"], undefined);
  controller.toggleOverview();
  assert.equal(view.slides[0].style.values["--overview-slide-scale"], undefined);
  assert.equal(view.window.listeners.resize, undefined);
});

test("print lifecycle temporarily exposes every slide without native hidden and restores active state", () => {
  const view = fixture({ hash: "#2" });
  const controller = runtime.init(view.document, view.window);
  assert.equal(view.slides[0].getAttribute("hidden"), null);
  assert.equal(view.slides[1].getAttribute("hidden"), null);
  assert.equal(view.slides[0].getAttribute("aria-hidden"), "true");
  assert.equal(view.slides[1].getAttribute("aria-hidden"), "false");
  view.window.dispatch("beforeprint");
  assert.equal(controller.current, 2);
  assert.equal(view.root.classList.contains("is-printing"), true);
  assert.equal(view.slides.every((slide) => !slide.hidden && slide.getAttribute("hidden") === null), true);
  assert.equal(view.slides.every((slide) => slide.getAttribute("aria-hidden") === "false"), true);
  view.window.dispatch("afterprint");
  assert.equal(view.root.classList.contains("is-printing"), false);
  assert.equal(view.slides[0].getAttribute("hidden"), null);
  assert.equal(view.slides[1].getAttribute("hidden"), null);
  assert.equal(view.slides[0].getAttribute("aria-hidden"), "true");
  assert.equal(view.slides[1].getAttribute("aria-hidden"), "false");
});
