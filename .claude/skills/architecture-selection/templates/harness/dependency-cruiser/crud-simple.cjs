/**
 * L1 crud-simple の境界ルール。
 * 対象プロジェクトでは `.dependency-cruiser.cjs` として置く。
 * @type {import('dependency-cruiser').IConfiguration}
 */
module.exports = {
  forbidden: [
    {
      name: "no-circular",
      severity: "error",
      comment: "循環依存は禁止。",
      from: {},
      to: { circular: true },
    },
    {
      name: "no-cross-feature",
      severity: "error",
      comment:
        "feature 同士は import しない。共通化が必要なら src/lib/ へ移す。3 か所以上で必要になったら L2 への昇格を検討する。",
      from: { path: "^src/features/([^/]+)/" },
      to: { path: "^src/features/", pathNot: "^src/features/$1/" },
    },
    {
      name: "ui-not-to-db",
      severity: "error",
      comment: "画面・コンポーネントは DB を直接触らない。queries.ts / actions.ts を経由する。",
      from: { path: "^src/(app/|features/[^/]+/components/)" },
      to: { path: "^src/db/" },
    },
    {
      name: "lib-is-leaf",
      severity: "error",
      comment: "src/lib/ は業務を含まない。features / app / db に依存しない。",
      from: { path: "^src/lib/" },
      to: { path: "^src/(features|app|db)/" },
    },
    {
      name: "no-test-imports-in-prod",
      severity: "error",
      comment: "本番コードからテストコードを import しない。",
      from: { pathNot: "\\.(test|spec)\\.tsx?$" },
      to: { path: "\\.(test|spec)\\.tsx?$" },
    },
  ],
  options: {
    doNotFollow: { path: "node_modules" },
    tsConfig: { fileName: "tsconfig.json" },
    tsPreCompilationDeps: true,
    enhancedResolveOptions: { exportsFields: ["exports"], conditionNames: ["import", "require", "node", "default", "types"] },
  },
};
