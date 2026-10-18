import { defineConfig } from "vitest/config";

// カバレッジの閾値は業務ロジックを含む層にだけ掛ける(references/quality-gates.md)。
// include は採った構造の段階に合わせて 1 つ残す。値は ARCHITECTURE.md に書いた閾値に合わせる。
const BUSINESS_LOGIC = {
  slice: ["src/features/*/{commands,queries,services}/**/*.ts"],
  modular: ["src/modules/*/{commands,queries,services}/**/*.ts"],
  layered: [
    "src/modules/*/{domain,application}/**/*.ts",
    "src/modules/*/{commands,queries,services}/**/*.ts",
  ],
} as const;

export default defineConfig({
  test: {
    environment: "happy-dom",
    include: ["src/**/*.test.{ts,tsx}"],
    coverage: {
      provider: "v8",
      include: [...BUSINESS_LOGIC.slice],
      exclude: ["**/*.test.{ts,tsx}", "src/generated/**"],
      thresholds: { lines: 80 },
    },
  },
});
