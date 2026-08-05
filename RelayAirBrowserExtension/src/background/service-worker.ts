/**
 * Headless detector service worker.
 * Caches per-tab field snapshots and answers GET_FIELDS.
 */

import type {
  DetectionSnapshot,
  ExtensionMessage,
  MessageResponse,
} from "../types";

/** Latest detection result keyed by tab id. */
const snapshotsByTab = new Map<number, DetectionSnapshot>();

chrome.runtime.onInstalled.addListener(() => {
  console.log("[RelayAir] Form detector ready");
});

chrome.tabs.onRemoved.addListener((tabId) => {
  snapshotsByTab.delete(tabId);
});

function isRestrictedUrl(url: string): boolean {
  return (
    url.startsWith("chrome://") ||
    url.startsWith("chrome-extension://") ||
    url.startsWith("edge://") ||
    url.startsWith("about:") ||
    url.startsWith("devtools://") ||
    url.startsWith("https://chrome.google.com/webstore")
  );
}

async function ensureContentScript(tabId: number): Promise<void> {
  try {
    await chrome.tabs.sendMessage(tabId, { type: "PING" });
  } catch {
    await chrome.scripting.executeScript({
      target: { tabId },
      files: ["content/content.js"],
    });
    await new Promise((r) => setTimeout(r, 50));
  }
}

async function updateBadge(tabId: number, count: number): Promise<void> {
  const text = count > 0 ? String(count) : "";
  try {
    await chrome.action.setBadgeText({ tabId, text });
    await chrome.action.setBadgeBackgroundColor({
      tabId,
      color: "#1d6feb",
    });
    await chrome.action.setTitle({
      tabId,
      title:
        count > 0
          ? `RelayAir: ${count} form field${count === 1 ? "" : "s"} detected`
          : "RelayAir Form Detector",
    });
  } catch {
    // Tab may have closed.
  }
}

async function fetchFieldsForTab(tabId: number): Promise<MessageResponse> {
  const tab = await chrome.tabs.get(tabId).catch(() => null);
  const url = tab?.url ?? "";
  if (!tab || isRestrictedUrl(url)) {
    return {
      ok: false,
      error: "Cannot access this page.",
    };
  }

  try {
    await ensureContentScript(tabId);
    const response = (await chrome.tabs.sendMessage(tabId, {
      type: "GET_FIELDS",
    })) as MessageResponse;

    if (response.ok && "data" in response) {
      const snapshot = { ...response.data, tabId };
      snapshotsByTab.set(tabId, snapshot);
      await updateBadge(tabId, snapshot.fields.length);
      return { ok: true, data: snapshot };
    }

    return response ?? { ok: false, error: "Empty response from content script" };
  } catch (error) {
    return {
      ok: false,
      error:
        error instanceof Error
          ? error.message
          : "Failed to communicate with the page. Try refreshing the tab.",
    };
  }
}

chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  const msg = message as ExtensionMessage;

  if (msg.type === "FIELDS_UPDATED") {
    const tabId = sender.tab?.id;
    if (tabId != null && msg.payload) {
      const snapshot = {
        ...(msg.payload as DetectionSnapshot),
        tabId,
      };
      snapshotsByTab.set(tabId, snapshot);
      void updateBadge(tabId, snapshot.fields.length);
    }
    return false;
  }

  if (msg.type === "GET_FIELDS") {
    // Prefer cached snapshot for the sender's tab or active tab
    const handle = async (): Promise<MessageResponse> => {
      const tabId =
        sender.tab?.id ??
        (await chrome.tabs.query({ active: true, currentWindow: true }))[0]?.id;

      if (tabId == null) {
        return { ok: false, error: "No active tab" };
      }

      const cached = snapshotsByTab.get(tabId);
      if (cached) {
        return { ok: true, data: cached };
      }

      return fetchFieldsForTab(tabId);
    };

    handle().then(sendResponse);
    return true;
  }

  if (msg.type === "PING") {
    sendResponse({ ok: true, pong: true });
    return false;
  }

  return false;
});

// Toolbar click: refresh detection for the active tab (no popup).
chrome.action.onClicked.addListener((tab) => {
  if (tab.id == null) return;
  void fetchFieldsForTab(tab.id);
});
