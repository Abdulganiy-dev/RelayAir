import { createSnapshot, detectFormFields } from "./detector";
import type {
  DetectedField,
  ExtensionMessage,
  MessageResponse,
} from "../types";

const DEBOUNCE_MS = 300;

let cachedFields: DetectedField[] = [];
let debounceTimer: ReturnType<typeof setTimeout> | null = null;
let observer: MutationObserver | null = null;

function logDetection(fields: DetectedField[]): void {
  const snapshot = createSnapshot(fields);
  const rows = fields.map((field) => ({
    type: field.classification.fieldType,
    label: field.displayName,
    selector: field.selector,
    x: field.position.x,
    y: field.position.y,
    w: field.position.width,
    h: field.position.height,
    confidence: field.classification.confidence,
  }));

  console.groupCollapsed(
    `[RelayAir] Found ${fields.length} form field${fields.length === 1 ? "" : "s"} on ${snapshot.url}`
  );
  if (rows.length > 0) {
    console.table(rows);
  } else {
    console.log("No fillable form fields detected.");
  }
  console.log("Full snapshot:", snapshot);
  console.groupEnd();
}

function refreshFields(notify = true): void {
  try {
    cachedFields = detectFormFields();
    logDetection(cachedFields);

    if (notify) {
      chrome.runtime
        .sendMessage({
          type: "FIELDS_UPDATED",
          payload: createSnapshot(cachedFields),
        })
        .catch(() => {
          // Background may be asleep — ignore.
        });
    }
  } catch (error) {
    console.error("[RelayAir] Detection failed", error);
  }
}

function scheduleRefresh(): void {
  if (debounceTimer) clearTimeout(debounceTimer);
  debounceTimer = setTimeout(() => {
    debounceTimer = null;
    refreshFields(true);
  }, DEBOUNCE_MS);
}

function startObserver(): void {
  if (observer) return;

  observer = new MutationObserver((mutations) => {
    for (const mutation of mutations) {
      if (
        mutation.type === "childList" &&
        (mutation.addedNodes.length || mutation.removedNodes.length)
      ) {
        scheduleRefresh();
        return;
      }
      if (mutation.type === "attributes") {
        const name = mutation.attributeName;
        if (
          name === "type" ||
          name === "name" ||
          name === "id" ||
          name === "placeholder" ||
          name === "aria-label" ||
          name === "required" ||
          name === "disabled" ||
          name === "hidden"
        ) {
          scheduleRefresh();
          return;
        }
      }
    }
  });

  observer.observe(document.documentElement, {
    childList: true,
    subtree: true,
    attributes: true,
    attributeFilter: [
      "type",
      "name",
      "id",
      "placeholder",
      "aria-label",
      "required",
      "disabled",
      "hidden",
    ],
  });
}

function handleMessage(
  message: ExtensionMessage,
  _sender: chrome.runtime.MessageSender,
  sendResponse: (response: MessageResponse) => void
): boolean {
  try {
    switch (message.type) {
      case "PING": {
        sendResponse({ ok: true, pong: true });
        return false;
      }
      case "GET_FIELDS": {
        refreshFields(false);
        sendResponse({ ok: true, data: createSnapshot(cachedFields) });
        return false;
      }
      default: {
        sendResponse({
          ok: false,
          error: `Unknown message type: ${String(message.type)}`,
        });
        return false;
      }
    }
  } catch (error) {
    sendResponse({
      ok: false,
      error: error instanceof Error ? error.message : "Content script error",
    });
    return false;
  }
}

function init(): void {
  chrome.runtime.onMessage.addListener(handleMessage);
  startObserver();

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", () => refreshFields(true));
  } else {
    refreshFields(true);
  }
  window.addEventListener("load", () => scheduleRefresh());
}

init();
