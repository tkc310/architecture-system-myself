# [モジュール名] モジュール

<!-- 短く保つ。README と重複することは書かない。機械で強制できることは書かない -->

## どこに何を書くか

| 書くもの | 置き場所 |
| --- | --- |
| 状態を変える操作 | `commands/<verb>-<noun>.command.ts`(L では `application/commands/`) |
| 読み取り | `queries/get-<noun>.query.ts`(L では `application/queries/`) |
| 共通の計算・ルール | `services/<noun>.service.ts`(L では `domain/`) |
| テーブル定義 | `tables.ts`(L では `infrastructure/tables.ts`) |

## 用語集

| 用語 | 意味 | コード上の名前 |
| --- | --- | --- |
| | | |

## 禁止事項

- [このモジュールに固有の禁止事項。例: 金額は `Money` 型で扱い、number で計算しない]

## 参照実装

- 新しい command を書くときは [`commands/place-order.command.ts`] を手本にする
- 新しい query を書くときは [`queries/get-order.query.ts`] を手本にする
