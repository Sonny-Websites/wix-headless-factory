// Generated from .wix/site.json.designTokens. Do not edit.
export type Brand = { name: string; description: string };
export type DesignTokens = {
  colors: Record<"background" | "surface" | "text" | "muted" | "accent" | "border", string>;
  fonts: Record<"display" | "body", string>;
  radii: Record<"card" | "pill", string>;
  spacing: Record<"section" | "gutter", string>;
  containers: Record<"page" | "reading", string>;
};
export type Product = { id: string; name: string; slug: string; price: number; variantId: string };
export declare const site: {
  brand: Brand;
  designTokens: DesignTokens;
  seeded: { products?: Product[]; posts?: unknown[]; collections?: Record<string, unknown[]> };
};
