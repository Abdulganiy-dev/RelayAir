/** Semantic field categories produced by the rule-based classifier. */
export type SemanticFieldType =
  | "email"
  | "phone"
  | "first_name"
  | "last_name"
  | "full_name"
  | "address"
  | "city"
  | "state"
  | "zip"
  | "country"
  | "password"
  | "username"
  | "company"
  | "checkbox"
  | "radio"
  | "select"
  | "textarea"
  | "number"
  | "date"
  | "url"
  | "search"
  | "unknown";

/** Raw HTML control kind. */
export type ElementKind =
  | "input"
  | "textarea"
  | "select"
  | "checkbox"
  | "radio";

export interface FieldPosition {
  x: number;
  y: number;
  width: number;
  height: number;
}

export interface FieldClassification {
  fieldType: SemanticFieldType;
  confidence: number;
}

export interface DetectedField {
  /** Stable id assigned by the content script. */
  uid: string;
  /** HTML input type or element kind (email, text, checkbox, select, …). */
  type: string;
  elementKind: ElementKind;
  id: string | null;
  name: string | null;
  placeholder: string | null;
  label: string | null;
  nearbyText: string | null;
  ariaLabel: string | null;
  autocomplete: string | null;
  required: boolean;
  selector: string;
  position: FieldPosition;
  classification: FieldClassification;
  /** Human-readable label (prefer label / classification). */
  displayName: string;
  options?: string[];
}

export interface DetectionSnapshot {
  fields: DetectedField[];
  url: string;
  title: string;
  detectedAt: number;
  tabId?: number;
}

export type ExtensionMessageType = "PING" | "GET_FIELDS" | "FIELDS_UPDATED";

export interface ExtensionMessage {
  type: ExtensionMessageType;
  payload?: unknown;
}

export interface GetFieldsResponse {
  ok: true;
  data: DetectionSnapshot;
}

export interface ErrorResponse {
  ok: false;
  error: string;
}

export type MessageResponse =
  | GetFieldsResponse
  | { ok: true; pong: true }
  | ErrorResponse;
