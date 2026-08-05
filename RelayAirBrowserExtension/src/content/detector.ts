import { classifyField, displayNameFor } from "./classifier";
import type {
  DetectedField,
  DetectionSnapshot,
  ElementKind,
  FieldPosition,
} from "../types";

const FORM_SELECTOR =
  'input:not([type="hidden"]):not([type="submit"]):not([type="button"]):not([type="reset"]):not([type="image"]):not([type="file"]), textarea, select';

const UID_ATTR = "data-relayair-uid";

let uidCounter = 0;

function nextUid(): string {
  uidCounter += 1;
  return `ra-field-${uidCounter}`;
}

function cssEscape(value: string): string {
  if (typeof CSS !== "undefined" && typeof CSS.escape === "function") {
    return CSS.escape(value);
  }
  return value.replace(/([ !"#$%&'()*+,./:;<=>?@[\\\]^`{|}~])/g, "\\$1");
}

/**
 * Build a reasonably stable CSS selector for an element.
 */
export function buildSelector(el: Element): string {
  if (el.id) {
    return `#${cssEscape(el.id)}`;
  }

  const name = el.getAttribute("name");
  const tag = el.tagName.toLowerCase();
  if (name) {
    const byName = `${tag}[name="${cssEscape(name)}"]`;
    try {
      if (document.querySelectorAll(byName).length === 1) {
        return byName;
      }
    } catch {
      // fall through
    }
  }

  const parts: string[] = [];
  let current: Element | null = el;

  while (current && current.nodeType === Node.ELEMENT_NODE && parts.length < 5) {
    let part = current.tagName.toLowerCase();
    if (current.id) {
      parts.unshift(`#${cssEscape(current.id)}`);
      break;
    }

    const parent: Element | null = current.parentElement;
    if (parent) {
      const siblings = Array.from(parent.children).filter(
        (c) => c.tagName === current!.tagName
      );
      if (siblings.length > 1) {
        const index = siblings.indexOf(current) + 1;
        part += `:nth-of-type(${index})`;
      }
    }

    parts.unshift(part);
    current = parent;
    if (current && current.tagName.toLowerCase() === "body") {
      parts.unshift("body");
      break;
    }
  }

  return parts.join(" > ");
}

function getAssociatedLabel(el: Element): string | null {
  if (el instanceof HTMLInputElement || el instanceof HTMLTextAreaElement || el instanceof HTMLSelectElement) {
    if (el.labels && el.labels.length > 0) {
      const text = Array.from(el.labels)
        .map((l) => l.innerText.trim())
        .filter(Boolean)
        .join(" ");
      if (text) return truncate(text, 120);
    }
  }

  const id = el.getAttribute("id");
  if (id) {
    const label = document.querySelector(`label[for="${cssEscape(id)}"]`);
    if (label?.textContent?.trim()) {
      return truncate(label.textContent.trim(), 120);
    }
  }

  const wrapping = el.closest("label");
  if (wrapping?.textContent?.trim()) {
    // Avoid including the control's own value in the label text dump
    const clone = wrapping.cloneNode(true) as HTMLElement;
    clone.querySelectorAll("input, textarea, select").forEach((n) => n.remove());
    const text = clone.textContent?.trim();
    if (text) return truncate(text, 120);
  }

  return null;
}

function getNearbyText(el: Element): string | null {
  const parent = el.parentElement;
  if (!parent) return null;

  // Previous sibling text / label-like nodes
  let sibling: ChildNode | null = el.previousSibling;
  while (sibling) {
    if (sibling.nodeType === Node.TEXT_NODE) {
      const text = sibling.textContent?.trim();
      if (text) return truncate(text, 80);
    }
    if (sibling.nodeType === Node.ELEMENT_NODE) {
      const element = sibling as Element;
      if (!["SCRIPT", "STYLE", "INPUT", "TEXTAREA", "SELECT", "BUTTON"].includes(element.tagName)) {
        const text = element.textContent?.trim();
        if (text) return truncate(text, 80);
      }
    }
    sibling = sibling.previousSibling;
  }

  // aria-describedby
  const describedBy = el.getAttribute("aria-describedby");
  if (describedBy) {
    const parts = describedBy
      .split(/\s+/)
      .map((id) => document.getElementById(id)?.textContent?.trim())
      .filter(Boolean);
    if (parts.length) return truncate(parts.join(" "), 80);
  }

  return null;
}

function truncate(value: string, max: number): string {
  const cleaned = value.replace(/\s+/g, " ").trim();
  if (cleaned.length <= max) return cleaned;
  return `${cleaned.slice(0, max - 1)}…`;
}

function getPosition(el: Element): FieldPosition {
  const rect = el.getBoundingClientRect();
  return {
    x: Math.round(rect.left + window.scrollX),
    y: Math.round(rect.top + window.scrollY),
    width: Math.round(rect.width),
    height: Math.round(rect.height),
  };
}

function resolveElementKind(el: Element): ElementKind {
  if (el instanceof HTMLTextAreaElement) return "textarea";
  if (el instanceof HTMLSelectElement) return "select";
  if (el instanceof HTMLInputElement) {
    const t = (el.type || "text").toLowerCase();
    if (t === "checkbox") return "checkbox";
    if (t === "radio") return "radio";
    return "input";
  }
  return "input";
}

function resolveType(el: Element, kind: ElementKind): string {
  if (kind === "textarea") return "textarea";
  if (kind === "select") return "select";
  if (kind === "checkbox") return "checkbox";
  if (kind === "radio") return "radio";
  if (el instanceof HTMLInputElement) {
    return (el.type || "text").toLowerCase();
  }
  return "text";
}

function isVisible(el: Element): boolean {
  if (!(el instanceof HTMLElement)) return false;
  const style = window.getComputedStyle(el);
  if (style.display === "none" || style.visibility === "hidden" || style.opacity === "0") {
    return false;
  }
  const rect = el.getBoundingClientRect();
  if (rect.width === 0 && rect.height === 0) return false;
  if (el.hasAttribute("hidden") || el.getAttribute("aria-hidden") === "true") {
    return false;
  }
  return true;
}

function ensureUid(el: Element): string {
  const existing = el.getAttribute(UID_ATTR);
  if (existing) return existing;
  const uid = nextUid();
  el.setAttribute(UID_ATTR, uid);
  return uid;
}

function collectField(el: Element): DetectedField | null {
  if (!isVisible(el)) return null;

  const elementKind = resolveElementKind(el);
  const type = resolveType(el, elementKind);
  const id = el.getAttribute("id");
  const name = el.getAttribute("name");
  const placeholder = el.getAttribute("placeholder");
  const ariaLabel = el.getAttribute("aria-label");
  const autocomplete = el.getAttribute("autocomplete");
  const required =
    el.hasAttribute("required") || el.getAttribute("aria-required") === "true";
  const label = getAssociatedLabel(el);
  const nearbyText = getNearbyText(el);
  const selector = buildSelector(el);
  const position = getPosition(el);
  const uid = ensureUid(el);

  const classification = classifyField({
    type,
    elementKind,
    id,
    name,
    placeholder,
    label,
    nearbyText,
    ariaLabel,
    autocomplete,
  });

  const displayName = displayNameFor(classification, label ?? ariaLabel, type);

  const field: DetectedField = {
    uid,
    type,
    elementKind,
    id,
    name,
    placeholder,
    label,
    nearbyText,
    ariaLabel,
    autocomplete,
    required,
    selector,
    position,
    classification,
    displayName,
  };

  if (el instanceof HTMLSelectElement) {
    field.options = Array.from(el.options)
      .map((o) => o.textContent?.trim() || o.value)
      .filter(Boolean)
      .slice(0, 20);
  }

  return field;
}

/**
 * Scan the document for fillable form controls.
 */
export function detectFormFields(root: ParentNode = document): DetectedField[] {
  const nodes = root.querySelectorAll(FORM_SELECTOR);
  const fields: DetectedField[] = [];
  const seen = new Set<Element>();

  nodes.forEach((node) => {
    if (seen.has(node)) return;
    seen.add(node);
    try {
      const field = collectField(node);
      if (field) fields.push(field);
    } catch (error) {
      console.warn("[RelayAir] Failed to collect field", error);
    }
  });

  // Stable order: top-to-bottom, left-to-right
  fields.sort((a, b) => {
    if (a.position.y !== b.position.y) return a.position.y - b.position.y;
    return a.position.x - b.position.x;
  });

  return fields;
}

export function createSnapshot(fields: DetectedField[]): DetectionSnapshot {
  return {
    fields,
    url: location.href,
    title: document.title,
    detectedAt: Date.now(),
  };
}

export { FORM_SELECTOR, UID_ATTR };
