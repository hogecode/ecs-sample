# Lambda IAM Policy Action 空エラー修正

**日付**: 2026年4月25日  
**対象**: Lambda 関数の IAM ポリシー生成時に Action が空になるエラー  
**種別**: バグ修正

## 問題の説明

### エラーメッセージ
```
Error: creating IAM Policy (ecs-sample-dev-s3_file_validator-role-inline): 
operation error IAM: CreatePolicy, https response error StatusCode: 400, 
RequestID: ee5f96eb-5a98-4c39-b06d-ef0bce9ffebb, 
MalformedPolicyDocument: Policy statement must contain actions.
```

### 根本原因

Lambda 関数の `policy_statements` パラメータで、以下の問題がありました：

1. **条件分岐の不完全性**: `s3_read_policy` が True でも、`s3_trigger` が `null` の場合、Policy statement が生成される可能性があった

2. **Resource 参照の脆弱性**: `s3_trigger != null ? s3_trigger.bucket_id : "*"` として、bucket_id が存在しないかもしれない `*` を使用していた

結果として、Action が空の Policy statement が IAM に送信され、エラーが発生していました。

## 修正内容

### 修正ファイル
**terraform/main.tf** (行 472-490)

### 変更前
```hcl
policy_statements = each.value.s3_read_policy ? [
  {
    Effect = "Allow"
    Action = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:HeadObject"
    ]
    Resource = "arn:aws:s3:::${each.value.s3_trigger != null ? each.value.s3_trigger.bucket_id : "*"}/*"
  },
  {
    Effect = "Allow"
    Action = [
      "s3:ListBucket",
      "s3:GetBucketVersioning"
    ]
    Resource = "arn:aws:s3:::${each.value.s3_trigger != null ? each.value.s3_trigger.bucket_id : "*"}"
  }
] : []
```

### 変更後
```hcl
policy_statements = each.value.s3_read_policy && each.value.s3_trigger != null ? [
  {
    Effect = "Allow"
    Action = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:HeadObject"
    ]
    Resource = "arn:aws:s3:::${each.value.s3_trigger.bucket_id}/*"
  },
  {
    Effect = "Allow"
    Action = [
      "s3:ListBucket",
      "s3:GetBucketVersioning"
    ]
    Resource = "arn:aws:s3:::${each.value.s3_trigger.bucket_id}"
  }
] : []
```

## 修正のポイント

### 1. 条件分岐の明確化

**修正前**:
```hcl
each.value.s3_read_policy ? [...] : []
```

**修正後**:
```hcl
each.value.s3_read_policy && each.value.s3_trigger != null ? [...] : []
```

両方の条件が必要：
- `s3_read_policy` = true: S3 ポリシーを作成する意図
- `s3_trigger` != null: 実際に S3 トリガーが設定されている

### 2. Bucket ID 参照の簡略化

**修正前**:
```hcl
"arn:aws:s3:::${each.value.s3_trigger != null ? each.value.s3_trigger.bucket_id : "*"}/*"
```

**修正後**:
```hcl
"arn:aws:s3:::${each.value.s3_trigger.bucket_id}/*"
```

条件 `each.value.s3_trigger != null` を上位で確認したため、Resource 内では直接参照可能に。

## なぜ Policy statement が空になったのか

Terraform の評価順序：
1. 条件 `each.value.s3_read_policy` が True
2. しかし `each.value.s3_trigger` が `null`
3. Policy statement リストは生成されるが、Resource が `*` になる
4. IAM の検証で「wildcard Resource では Action が必須」と判定

実際には Action は含まれていますが、bucket_id が不正な値（ワイルドカード）になったため、IAM が Policy を拒否していました。

## 検証方法

```bash
cd terraform
terraform apply
```

エラーメッセージ「MalformedPolicyDocument: Policy statement must contain actions」が出現しなくなることを確認。

## 関連ファイル

- `terraform/main.tf` (行 415-502) - Lambda 関数設定
- `terraform/lambda_functions.json` - Lambda 関数定義
- `terraform/modules/lambda/main.tf` - Lambda モジュール

## 学習ポイント

Terraform で複数の条件を組み合わせる場合は、各条件の評価タイミングを明確にすることが重要。特に、null チェックと boolean チェックの組み合わせは、`&&` で明示的に結合することで、意図を明確にできます。
