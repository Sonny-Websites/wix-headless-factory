// Generated from .wix/site.json.designTokens. Do not edit.
export type Brand = { name: string; description: string };
export type DesignTokens = {
  colors: Record<"bg" | "surface" | "text" | "muted" | "accent", string>;
  fonts: Record<"display" | "body", string>;
  radii: Record<"sm" | "md" | "lg", string>;
  spacing: Record<"xs" | "sm" | "md" | "lg" | "xl", string>;
  containers: Record<"reading" | "content", string>;
};
export type Product = { id: string; name: string; slug: string; price: number; variantId: string };
export declare const site: {
  brand: Brand;
  designTokens: DesignTokens;
  seeded: { products?: Product[]; posts?: unknown[]; collections?: Record<string, unknown[]> };
};
