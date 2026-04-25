# Lambda Source Path 絶対パス変換エラー修正（第2版）

**日付**: 2026年4月25日  
**対象**: Lambda 関数の source_path の二重相対パス解決エラー  
**種別**: バグ修正（追加修正）

## 問題の説明

### エラーメッセージ（第2回目のエラー）
```
Error: External Program Execution Failed

Error Message: Could not locate source_path "./../../lambda/s3-file-validator".
Paths are relative to directory where `terraform plan` is being run
("C:\Users\user\AppData\Local\app\ecs-sample\terraform")
```

### 根本原因

前回の修正 `source_path = "${path.root}/../${config.source_path}"` では、相対パスを結合していたため、terraform-aws-modules モジュール内部で再度相対化され、二重相対パス `./../../` が生じていた。

**パス解決フロー（修正前）**:
```
Input:
  path.root = C:\Users\user\AppData\Local\app\ecs-sample\terraform
  config.source_path = lambda/s3-file-validator

Step 1: 相対パスを結合
  ${path.root}/../${config.source_path}
  = C:\Users\user\AppData\Local\app\ecs-sample\terraform/../lambda/s3-file-validator

Step 2: terraform-aws-modules が相対パスとして再処理
  相対パスの可能性あり → ./../../ のような形式に

Result: エラー
```

## 修正内容

### 修正ファイル
**terraform/main.tf** (行 426)

### 変更前
```hcl
source_path = "${path.root}/../${config.source_path}"
```

### 変更後
```hcl
source_path = abspath("${path.root}/../${config.source_path}")
```

### 修正のポイント

Terraform の `abspath()` 関数を使用して、相対パス文字列を**完全な絶対パス**に正規化します：

- `abspath()` は、相対パスを現在の working directory に基づいて絶対パスに変換
- `${path.root}/../` で一度相対パスを作成し、`abspath()` で確実に絶対化
- 絶対パスであれば、terraform-aws-modules は相対化処理をしない

### パス解決ロジック（修正後）

```
Input:
  path.root = C:\Users\user\AppData\Local\app\ecs-sample\terraform
  config.source_path = lambda/s3-file-validator

Step 1: 相対パスを結合
  ${path.root}/../${config.source_path}
  = C:\Users\user\AppData\Local\app\ecs-sample\terraform/../lambda/s3-file-validator

Step 2: abspath() で絶対パスに正規化
  abspath(...)
  = C:\Users\user\AppData\Local\app\ecs-sample\lambda\s3-file-validator

Step 3: terraform-aws-modules に絶対パスを渡す
  → 相対化処理をしない
  → パスが確実に解決される ✅

Result: success
```

## なぜ abspath() が必要なのか

terraform-aws-modules/lambda/aws モジュール の `source_path` パラメータは、相対パスか絶対パスか自動検出します：

- **相対パス** → モジュール内で再度相対化処理
- **絶対パス** → そのまま使用（相対化しない）

前回の修正では相対パス文字列のままだったため、モジュール内で再度相対化され、二重相対パス `./../../` となってしまいました。

`abspath()` を使用することで、文字列的に相対パス形式でも、完全な絶対パスとして評価されるようになります。

## 検証方法

```bash
cd terraform
terraform plan
```

エラー メッセージ「Could not locate source_path」が出現しなくなることを確認。

## 関連ファイル

- `terraform/main.tf` (行 415-475) - Lambda 関数設定
- `terraform/lambda_functions.json` - Lambda 関数定義
- `terraform/modules/lambda/main.tf` - Lambda モジュール

## 技術的背景

Terraform 関数の使用：
- `path.root`: ルートモジュール（terraform ディレクトリ）の絶対パス
- `abspath(path)`: 相対パスを絶対パスに変換（`..` や `.` を正規化）

この組み合わせにより、どのディレクトリから terraform コマンドが実行されても、正しく Lambda ソースコードを特定できるようになります。

## Windows/Linux 互換性

`abspath()` は Windows と Linux の両方で動作し、パス区切り文字（`\` vs `/`）の違いを自動的に吸収します。
