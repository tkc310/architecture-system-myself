/**
 * L3 domain-centric の境界ルール。
 * L2 のルール(modular-monolith.cjs と同じ)に、モジュール内の層ルールを加える。
 * 単体でコピーして使えるよう、L2 のルールも重複して含めている。
 * 層ルールは domain/ などのディレクトリを持つモジュールにだけ効くので、
 * 軽いモジュールは L2 の形のままでよい。
 * 対象プロジェクトでは `.dependency-cruiser.cjs` として置く。
 * @type {import('dependency-cruiser').IConfiguration}
 */
const LAYER = "^src/modules/[^/]+/";

module.exports = {
  forbidden: [
    // ---- L2 と同じルール ----
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
    // ---- L3 の層ルール ----
    {
      name: "domain-is-pure",
      severity: "error",
      comment: "domain は application / infrastructure / presentation に依存しない。",
      from: { path: `${LAYER}domain/` },
      to: { path: `${LAYER}(application|infrastructure|presentation)/` },
    },
    {
      name: "domain-no-io-libraries",
      severity: "error",
      comment:
        "domain はフレームワーク・DB・Node.js の組み込みモジュールを使わない。許可するのは effect と shared-kernel のみ。",
      from: { path: `${LAYER}domain/` },
      to: {
        dependencyTypes: ["npm", "npm-dev", "npm-peer", "npm-optional", "core"],
        pathNot: "node_modules/effect/",
      },
    },
    {
      name: "application-depends-on-domain-only",
      severity: "error",
      comment: "application は infrastructure / presentation に依存しない。外部依存は ports.ts で宣言する。",
      from: { path: `${LAYER}application/` },
      to: { path: `${LAYER}(infrastructure|presentation)/` },
    },
    {
      name: "infrastructure-not-to-presentation",
      severity: "error",
      comment: "infrastructure は presentation に依存しない。",
      from: { path: `${LAYER}infrastructure/` },
      to: { path: `${LAYER}presentation/` },
    },
    {
      name: "presentation-via-application",
      severity: "error",
      comment:
        "presentation は application を呼ぶ。infrastructure へは依存の組み立て(infrastructure/layers.ts)だけ参照してよい。",
      from: { path: `${LAYER}presentation/` },
      to: {
        path: `${LAYER}infrastructure/`,
        pathNot: `${LAYER}infrastructure/layers\\.ts$`,
      },
    },
  ],
  options: {
    doNotFollow: { path: "node_modules" },
    tsConfig: { fileName: "tsconfig.json" },
    tsPreCompilationDeps: true,
    enhancedResolveOptions: { exportsFields: ["exports"], conditionNames: ["import", "require", "node", "default", "types"] },
  },
};
