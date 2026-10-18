/**
 * 構造 M: modular の依存ルール。references/principles.md の「依存の向き」の表をそのまま設定にしたもの。
 * 対象リポジトリでは `.dependency-cruiser.cjs` として置く。
 * @type {import('dependency-cruiser').IConfiguration}
 */
const U = "^src/modules/";

module.exports = {
  forbidden: [
    {
      name: "no-circular",
      severity: "error",
      comment: "循環依存を作らない。",
      from: {},
      to: { circular: true },
    },
    {
      name: "public-api-only",
      severity: "error",
      comment: "他の modules は index.ts からだけ使う。内部のファイルやテーブル定義を import しない。",
      from: { path: `${U}([^/]+)/` },
      to: { path: `${U}[^/]+/`, pathNot: [`${U}$1/`, `${U}[^/]+/index\\.ts$`] },
    },
    {
      name: "outside-public-api-only",
      severity: "error",
      comment: "modules の外（app/ を除く）からは index.ts だけを使う。",
      from: { pathNot: [U, "^src/app/"] },
      to: { path: `${U}[^/]+/`, pathNot: `${U}[^/]+/index\\.ts$` },
    },
    {
      name: "app-entry-points",
      severity: "error",
      comment: "app/ が使えるのは index.ts、commands/、ui/ だけ。",
      from: { path: "^src/app/" },
      to: { path: `${U}[^/]+/`, pathNot: `${U}[^/]+/(index\\.ts$|commands/|ui/)` },
    },
    {
      name: "index-does-not-export-commands",
      severity: "error",
      comment: "index.ts は command を公開しない。command は app/ からだけ呼ぶ。",
      from: { path: `${U}[^/]+/index\\.ts$` },
      to: { path: `${U}[^/]+/commands/` },
    },
    {
      name: "command-query-scope",
      severity: "error",
      comment: "commands/ と queries/ が同じ単位の中で使えるのは services/ と tables.ts と、自分と同じディレクトリだけ。",
      from: { path: `${U}([^/]+)/(commands|queries)/` },
      to: { path: `${U}$1/`, pathNot: [`${U}$1/$2/`, `${U}$1/services/`, `${U}$1/tables\\.ts$`] },
    },
    {
      name: "service-scope",
      severity: "error",
      comment: "services/ が同じ単位の中で使えるのは services/ と tables.ts だけ。",
      from: { path: `${U}([^/]+)/services/` },
      to: { path: `${U}$1/`, pathNot: [`${U}$1/services/`, `${U}$1/tables\\.ts$`] },
    },
    {
      name: "shared-is-leaf",
      severity: "error",
      comment: "shared/ は技術的な共通処理だけ。app/ と modules を import しない。",
      from: { path: "^src/shared/" },
      to: { path: "^src/(app|features|modules)/" },
    },
    {
      name: "no-test-imports-in-prod",
      severity: "error",
      comment: "本番コードからテストコードを import しない。",
      from: { pathNot: "\\.test\\.tsx?$" },
      to: { path: "\\.test\\.tsx?$" },
    },
  ],
  options: {
    doNotFollow: { path: "node_modules" },
    tsConfig: { fileName: "tsconfig.json" },
    tsPreCompilationDeps: true,
    enhancedResolveOptions: {
      exportsFields: ["exports"],
      conditionNames: ["import", "require", "node", "default", "types"],
    },
  },
};
