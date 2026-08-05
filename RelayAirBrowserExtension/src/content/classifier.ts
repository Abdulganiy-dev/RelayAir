import type { FieldClassification, SemanticFieldType } from "../types";

interface ClassificationRule {
  fieldType: SemanticFieldType;
  patterns: RegExp[];
  /** Base confidence when a pattern matches. */
  confidence: number;
}

/**
 * Ordered from most specific to least specific.
 * First match wins (with confidence from the matching rule).
 */
const RULES: ClassificationRule[] = [
  {
    fieldType: "email",
    confidence: 0.95,
    patterns: [
      /\be-?mail\b/i,
      /\bmail\b/i,
      /emailaddress/i,
      /user\.?email/i,
    ],
  },
  {
    fieldType: "phone",
    confidence: 0.93,
    patterns: [
      /\bphone\b/i,
      /\bmobile\b/i,
      /\btelephone\b/i,
      /\btel\b/i,
      /\bcell\b/i,
      /phone.?number/i,
    ],
  },
  {
    fieldType: "first_name",
    confidence: 0.92,
    patterns: [
      /\bfirst.?name\b/i,
      /\bgiven.?name\b/i,
      /\bfname\b/i,
      /\bforename\b/i,
      /^first$/i,
    ],
  },
  {
    fieldType: "last_name",
    confidence: 0.92,
    patterns: [
      /\blast.?name\b/i,
      /\bsurname\b/i,
      /\bfamily.?name\b/i,
      /\blname\b/i,
      /^last$/i,
    ],
  },
  {
    fieldType: "full_name",
    confidence: 0.88,
    patterns: [
      /\bfull.?name\b/i,
      /\byour.?name\b/i,
      /\bdisplay.?name\b/i,
      /\bcontact.?name\b/i,
      /^name$/i,
      /\bname\b/i,
    ],
  },
  {
    fieldType: "address",
    confidence: 0.9,
    patterns: [
      /\bstreet.?address\b/i,
      /\baddress.?line\b/i,
      /\bstreet\b/i,
      /\blocation\b/i,
      /\baddress\b/i,
      /\baddr\b/i,
    ],
  },
  {
    fieldType: "city",
    confidence: 0.9,
    patterns: [/\bcity\b/i, /\btown\b/i],
  },
  {
    fieldType: "state",
    confidence: 0.88,
    patterns: [/\bstate\b/i, /\bprovince\b/i, /\bregion\b/i],
  },
  {
    fieldType: "zip",
    confidence: 0.9,
    patterns: [
      /\bzip.?code\b/i,
      /\bpostal\b/i,
      /\bpost.?code\b/i,
      /\bpostcode\b/i,
    ],
  },
  {
    fieldType: "country",
    confidence: 0.9,
    patterns: [/\bcountry\b/i, /\bnation\b/i],
  },
  {
    fieldType: "password",
    confidence: 0.97,
    patterns: [/\bpassword\b/i, /\bpasswd\b/i, /\bpwd\b/i],
  },
  {
    fieldType: "username",
    confidence: 0.9,
    patterns: [/\buser.?name\b/i, /\buserid\b/i, /\blogin\b/i, /\buser\b/i],
  },
  {
    fieldType: "company",
    confidence: 0.88,
    patterns: [/\bcompany\b/i, /\borganization\b/i, /\borg\b/i, /\bbusiness\b/i],
  },
];

/** Autocomplete attribute → semantic type (high confidence). */
const AUTOCOMPLETE_MAP: Record<string, SemanticFieldType> = {
  email: "email",
  tel: "phone",
  "tel-national": "phone",
  "tel-local": "phone",
  "given-name": "first_name",
  "family-name": "last_name",
  "additional-name": "full_name",
  name: "full_name",
  "street-address": "address",
  address: "address",
  "address-line1": "address",
  "address-line2": "address",
  "address-level2": "city",
  "address-level1": "state",
  "postal-code": "zip",
  country: "country",
  "country-name": "country",
  username: "username",
  "current-password": "password",
  "new-password": "password",
  organization: "company",
  "cc-name": "full_name",
};

export interface ClassifierInput {
  type: string;
  elementKind: string;
  id: string | null;
  name: string | null;
  placeholder: string | null;
  label: string | null;
  nearbyText: string | null;
  ariaLabel: string | null;
  autocomplete: string | null;
}

function normalizeAutocomplete(value: string | null): string | null {
  if (!value) return null;
  return value.trim().toLowerCase().split(/\s+/).pop() ?? null;
}

function buildHaystack(input: ClassifierInput): string {
  return [
    input.id,
    input.name,
    input.placeholder,
    input.label,
    input.nearbyText,
    input.ariaLabel,
    input.type,
  ]
    .filter(Boolean)
    .join(" ");
}

/**
 * Rule-based classifier. No AI / network calls.
 */
export function classifyField(input: ClassifierInput): FieldClassification {
  // Element-kind shortcuts
  if (input.elementKind === "checkbox") {
    return { fieldType: "checkbox", confidence: 1 };
  }
  if (input.elementKind === "radio") {
    return { fieldType: "radio", confidence: 1 };
  }
  if (input.elementKind === "select") {
    // Still try semantic classification for address-related selects, etc.
    const selectClass = classifyFromText(input);
    if (selectClass.fieldType !== "unknown") return selectClass;
    return { fieldType: "select", confidence: 0.7 };
  }
  if (input.elementKind === "textarea") {
    const textClass = classifyFromText(input);
    if (textClass.fieldType !== "unknown") return textClass;
    return { fieldType: "textarea", confidence: 0.7 };
  }

  // HTML type attribute
  const htmlType = input.type.toLowerCase();
  if (htmlType === "email") return { fieldType: "email", confidence: 0.99 };
  if (htmlType === "tel") return { fieldType: "phone", confidence: 0.99 };
  if (htmlType === "password") return { fieldType: "password", confidence: 0.99 };
  if (htmlType === "url") return { fieldType: "url", confidence: 0.95 };
  if (htmlType === "number") return { fieldType: "number", confidence: 0.85 };
  if (htmlType === "date" || htmlType === "datetime-local") {
    return { fieldType: "date", confidence: 0.95 };
  }
  if (htmlType === "search") return { fieldType: "search", confidence: 0.9 };

  // Autocomplete attribute
  const ac = normalizeAutocomplete(input.autocomplete);
  if (ac && AUTOCOMPLETE_MAP[ac]) {
    return { fieldType: AUTOCOMPLETE_MAP[ac], confidence: 0.96 };
  }

  return classifyFromText(input);
}

function classifyFromText(input: ClassifierInput): FieldClassification {
  const haystack = buildHaystack(input);
  if (!haystack.trim()) {
    return { fieldType: "unknown", confidence: 0.1 };
  }

  for (const rule of RULES) {
    for (const pattern of rule.patterns) {
      if (pattern.test(haystack)) {
        return { fieldType: rule.fieldType, confidence: rule.confidence };
      }
    }
  }

  return { fieldType: "unknown", confidence: 0.2 };
}

/** Friendly label for popup display. */
export function displayNameFor(
  classification: FieldClassification,
  fallbackLabel: string | null,
  type: string
): string {
  if (fallbackLabel && fallbackLabel.trim()) {
    return fallbackLabel.trim();
  }

  const names: Record<SemanticFieldType, string> = {
    email: "Email",
    phone: "Phone",
    first_name: "First Name",
    last_name: "Last Name",
    full_name: "Full Name",
    address: "Address",
    city: "City",
    state: "State",
    zip: "ZIP / Postal Code",
    country: "Country",
    password: "Password",
    username: "Username",
    company: "Company",
    checkbox: "Checkbox",
    radio: "Radio",
    select: "Select",
    textarea: "Text Area",
    number: "Number",
    date: "Date",
    url: "URL",
    search: "Search",
    unknown: type ? type.charAt(0).toUpperCase() + type.slice(1) : "Field",
  };

  return names[classification.fieldType] ?? "Field";
}
