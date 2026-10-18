/**
 * L2 modular-monolith の境界ルール。
 * 対象プロジェクトでは `.dependency-cruiser.cjs` として置く。
 * @type {import('dependency-cruiser').IConfiguration}
 */
module.exports = {
  forbidden: [
    {
      name: "no-circular",
      severity: "error",
      comment: "循環依存は禁止(モジュール間・モジュール内とも)。",
      from: {},
      to: { circular: true },
    },
    {
      name: "module-public-api-only",
      severity: "error",
      comment:
        "他モジュールは modules/<name>/index.ts 経由でのみ使う。内部ファイル・テーブルを直接 import しない。",
      from: { path: "^src/modules/([^/]+)/" },
      to: {
        path: "^src/modules/[^/]+/",
        pathNot: ["^src/modules/$1/", "^src/modules/[^/]+/index\\.ts$"],
      },
    },
    {
      name: "outside-uses-public-api-only",
      severity: "error",
      comment:
        "modules の外(app, routes, jobs など)からも index.ts 経由でのみ使う。例外は各モジュールのテーブルを集約する src/db/schema.ts だけ。",
      from: { pathNot: ["^src/modules/", "^src/db/schema\\.ts$"] },
      to: {
        path: "^src/modules/[^/]+/",
        pathNot: "^src/modules/[^/]+/index\\.ts$",
      },
    },
    {
      name: "shared-is-leaf",
      severity: "error",
      comment: "src/shared/ に業務ロジックを置かない。modules / app に依存しない。",
      from: { path: "^src/shared/" },
      to: { path: "^src/(modules|app|routes)/" },
    },
    {
      name: "no-test-imports-in-prod",
      severity: "error",
      comment: "本番コードからテストコードを import しない。",
      from: { pathNot: "(\\.(test|spec)\\.tsx?$|/__tests__/)" },
      to: { path: "(\\.(test|spec)\\.tsx?$|/__tests__/)" },
    },
  ],
  options: {
    doNotFollow: { path: "node_modules" },
    tsConfig: { fileName: "tsconfig.json" },
    tsPreCompilationDeps: true,
    enhancedResolveOptions: { exportsFields: ["exports"], conditionNames: ["import", "require", "node", "default", "types"] },
  },
};
