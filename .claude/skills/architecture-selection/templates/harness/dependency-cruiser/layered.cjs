/**
 * 構造 L: layered の依存ルール。references/principles.md の「依存の向き」の表をそのまま設定にしたもの。
 * L の形(domain/ application/ infrastructure/)にしたモジュールと、M の形のまま残した薄いモジュールの
 * 両方に効く。層ごとのルールは、そのディレクトリを持つモジュールにだけ当たる。
 * 対象リポジトリでは `.dependency-cruiser.cjs` として置く。
 * @type {import('dependency-cruiser').IConfiguration}
 */
const U = "^src/modules/";
const ROOT = "^src/app/composition-root\\.ts$";

/** domain/ が import してよい npm パッケージ(I/O を行わないもの)。必要に応じて足す。 */
const PURE_PACKAGES = ["zod", "neverthrow"];

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
      comment: "他のモジュールは index.ts からだけ使う。内部のファイルやテーブル定義を import しない。",
      from: { path: `${U}([^/]+)/` },
      to: { path: `${U}[^/]+/`, pathNot: [`${U}$1/`, `${U}[^/]+/index\\.ts$`] },
    },
    {
      name: "outside-public-api-only",
      severity: "error",
      comment: "modules/ の外(app/ を除く)からは index.ts だけを使う。",
      from: { pathNot: [U, "^src/app/"] },
      to: { path: `${U}[^/]+/`, pathNot: `${U}[^/]+/index\\.ts$` },
    },
    {
      name: "app-entry-points",
      severity: "error",
      comment:
        "app/ が使えるのは index.ts と ui/(薄いモジュールでは commands/ も)。infrastructure/ はコンポジションルートからだけ。",
      from: { path: "^src/app/", pathNot: ROOT },
      to: { path: `${U}[^/]+/`, pathNot: `${U}[^/]+/(index\\.ts$|ui/|commands/)` },
    },
    {
      name: "composition-root-scope",
      severity: "error",
      comment: "コンポジションルートは、app/ が使える先に加えて infrastructure/ だけを使える。",
      from: { path: ROOT },
      to: { path: `${U}[^/]+/`, pathNot: `${U}[^/]+/(index\\.ts$|ui/|commands/|infrastructure/)` },
    },
    {
      name: "domain-is-pure",
      severity: "error",
      comment: "domain/ は同じモジュールの domain/ だけを import する。",
      from: { path: `${U}([^/]+)/domain/` },
      to: { path: "^src/", pathNot: `${U}$1/domain/` },
    },
    {
      name: "domain-no-io-libraries",
      severity: "error",
      comment: "domain/ は I/O を行うライブラリと Node.js の組み込みモジュールを使わない。",
      from: { path: `${U}[^/]+/domain/` },
      to: {
        dependencyTypes: ["npm", "npm-dev", "npm-peer", "npm-optional", "npm-no-pkg", "npm-unknown", "core"],
        pathNot: `node_modules/(${PURE_PACKAGES.join("|")})/`,
      },
    },
    {
      name: "application-scope",
      severity: "error",
      comment:
        "application/ が使えるのは、同じモジュールの domain/ と application/、他モジュールの index.ts、shared/。",
      from: { path: `${U}([^/]+)/application/` },
      to: {
        path: "^src/",
        pathNot: [`${U}$1/(domain|application)/`, `${U}[^/]+/index\\.ts$`, "^src/(shared|generated)/"],
      },
    },
    {
      name: "infrastructure-scope",
      severity: "error",
      comment:
        "infrastructure/ が使えるのは、同じモジュールの application/ports.ts、domain/、infrastructure/ と shared/。",
      from: { path: `${U}([^/]+)/infrastructure/` },
      to: {
        path: "^src/",
        pathNot: [
          `${U}$1/application/ports\\.ts$`,
          `${U}$1/(domain|infrastructure)/`,
          "^src/(shared|generated)/",
        ],
      },
    },
    // ---- M の形のまま残した薄いモジュール向け(slice / modular と同じ) ----
    {
      name: "index-does-not-export-commands",
      severity: "error",
      comment: "薄いモジュールの index.ts は commands/ の command を公開しない。command は app/ からだけ呼ぶ。",
      from: { path: `${U}[^/]+/index\\.ts$` },
      to: { path: `${U}[^/]+/commands/` },
    },
    {
      name: "command-query-scope",
      severity: "error",
      comment: "薄いモジュールの commands/ と queries/ が同じモジュールの中で使えるのは services/ と tables.ts だけ。",
      from: { path: `${U}([^/]+)/(commands|queries)/` },
      to: { path: `${U}$1/`, pathNot: [`${U}$1/$2/`, `${U}$1/services/`, `${U}$1/tables\\.ts$`] },
    },
    {
      name: "service-scope",
      severity: "error",
      comment: "薄いモジュールの services/ が同じモジュールの中で使えるのは services/ と tables.ts だけ。",
      from: { path: `${U}([^/]+)/services/` },
      to: { path: `${U}$1/`, pathNot: [`${U}$1/services/`, `${U}$1/tables\\.ts$`] },
    },
    {
      name: "ui-scope",
      severity: "error",
      comment: "ui/ が同じモジュールの中で使えるのは ui/ と index.ts だけ。データは app/ から props で受け取る(component-structure.md)。",
      from: { path: `${U}([^/]+)/ui/` },
      to: { path: `${U}$1/`, pathNot: [`${U}$1/ui/`, `${U}$1/index\\.ts$`] },
    },
    {
      name: "ui-no-server",
      severity: "error",
      comment: "ui/ は DB や認証などのサーバーの処理を import しない。",
      from: { path: `${U}[^/]+/ui/` },
      to: { path: "^src/shared/(db|auth)/" },
    },
    {
      name: "shared-ui-scope",
      severity: "error",
      comment: "shared/ui/ は共通の部品だけ。shared/ui/ と shared/lib/ 以外を import しない。",
      from: { path: "^src/shared/ui/" },
      to: { path: "^src/", pathNot: "^src/shared/(ui|lib)/" },
    },
    {
      name: "shared-is-leaf",
      severity: "error",
      comment: "shared/ は技術的な共通処理だけ。app/ と modules/ を import しない。",
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
