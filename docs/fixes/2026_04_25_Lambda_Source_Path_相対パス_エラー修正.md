# Lambda Source Path 相対パスエラー修正

**日付**: 2026年4月25日  
**対象**: Lambda 関数の source_path 解決エラー  
**種別**: バグ修正

## 問題の説明

### エラーメッセージ
```
Error: External Program Execution Failed

  with module.lambda_functions["s3_file_validator"].module.lambda_function.data.external.archive_prepare[0],
  on .terraform\modules\lambda_functions.lambda_function\package.tf line 10, in data "external" "archive_prepare":
  10:   program = [local.python, "${path.module}/package.py", "prepare"]

The data source received an unexpected error while attempting to execute the
program.

Program: C:\Users\user\AppData\Local\Programs\Python\Python311-32\python.exe
Error Message: Could not locate source_path "../lambda/s3-file-validator".
Paths are relative to directory where `terraform plan` is being run
("C:\Users\user\AppData\Local\app\ecs-sample\terraform")
```

### 根本原因
Lambda 関数の source_path を JSON ファイルで相対パスで指定していたが、terraform-aws-modules/lambda/aws モジュールの package.py スクリプトがパスを正しく解決できなかった。

**ファイル構造**:
```
ecs-sample/
├── terraform/           ← terraform plan が実行される場所 (path.root = ./terraform)
│   ├── main.tf
│   ├── lambda_functions.json
│   └── modules/
└── lambda/
    └── src/s3-file-validator/
```

**問題のコード（修正前）**:
- `lambda_functions.json`: `"source_path": "../lambda/s3-file-validator"`
- `terraform/main.tf`: `source_path = config.source_path` （そのまま渡す）

terraform が実行される `terraform/` ディレクトリから見ると、相対パス `../lambda/s3-file-validator` は正しく解決される。しかし、terraform-aws-modules の外部 Python スクリプトが実行される際、パス解決の基準ディレクトリが異なるため、エラーが発生した。

## 修正内容

### 修正ファイル
**terraform/main.tf** (行 426)

### 変更前
```hcl
lambda_functions_resolved = {
  for name, config in local.lambda_functions_config : name => {
    description           = config.description
    source_path           = config.source_path  # ← JSON から直接相対パスを使用
    handler               = config.handler
    # ...
  }
}
```

### 変更後
```hcl
lambda_functions_resolved = {
  for name, config in local.lambda_functions_config : name => {
    description           = config.description
    source_path           = "${path.root}/../${config.source_path}"  # ← 絶対パスに変換
    handler               = config.handler
    # ...
  }
}
```

### パス解決ロジック

修正後の path 評価:

1. `path.root`: terraform/ ディレクトリの絶対パス
   - 例: `C:\Users\user\AppData\Local\app\ecs-sample\terraform`

2. `..`: 1階層上に移動
   - 例: `C:\Users\user\AppData\Local\app\ecs-sample`

3. `${config.source_path}`: JSON ファイルの相対パス
   - 例: `lambda/s3-file-validator`

4. 結果: 
   - `C:\Users\user\AppData\Local\app\ecs-sample\lambda\s3-file-validator`

この絶対パスを terraform-aws-modules に渡すことで、外部 Python スクリプトでも正しくディレクトリを特定できる。

## 検証方法

```bash
cd terraform
terraform plan
```

エラー メッセージが出現しなくなることを確認。

## 関連ファイル

- `terraform/main.tf` (行 415-475)
- `terraform/lambda_functions.json` (source_path 設定)
- `terraform/modules/lambda/main.tf` (モジュール定義)

## 今後の改善案

今後、Lambda 関数をさらに追加する場合は:

1. `lambda_functions.json` に新しい関数定義を追加
2. `lambda/src/{function-name}/` ディレクトリを作成
3. `terraform plan` 実行時に自動的に絶対パスが解決される
