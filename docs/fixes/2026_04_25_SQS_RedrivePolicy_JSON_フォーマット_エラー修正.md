# SQS RedrivePolicy JSON フォーマット エラー修正

## 問題

Terraform の `terraform apply` 実行時に以下のエラーが発生していました：

```
Error: setting SQS Queue (https://sqs.ap-northeast-1.amazonaws.com/885545925004/email-ecs-sample-dev) 
attribute (RedrivePolicy): operation error SQS: SetQueueAttributes, 
https response error StatusCode: 400, RequestID: e6d23f69-01ee-5e11-8e0c-5d0f25d458c5, 
InvalidAttributeValue: Invalid value for the parameter RedrivePolicy. 
Reason: Redrive policy is not a valid JSON map.
```

このエラーは複数のキュー（email、notifications、default）で発生していました。

## 原因

AWS SQS API の RedrivePolicy には特定の JSON フォーマット要件があります。特に、`maxReceiveCount` パラメータは**文字列型**である必要があります。

修正前のコード：
```hcl
redrive_policy = jsonencode({
  deadLetterTargetArn = module.sqs_deadletter.queue_arn
  maxReceiveCount     = 3  # ❌ 数値型（不正）
})
```

## 解決策

`maxReceiveCount` を数値から文字列に変更しました：

```hcl
redrive_policy = jsonencode({
  deadLetterTargetArn = module.sqs_deadletter.queue_arn
  maxReceiveCount     = "3"  # ✅ 文字列型（正式）
})
```

## 修正ファイル

- **ファイル**: `terraform/modules/messaging/sqs/main.tf`
- **行番号**: 43 行目
- **変更内容**: `maxReceiveCount = 3` → `maxReceiveCount = "3"`

## 参考資料

Stack Overflow の関連質問：
- https://stackoverflow.com/questions/69618566/how-to-fix-error-message-when-adding-sqs-redrive-policy-for-deadletter-queue-cre

AWS SQS RedrivePolicy の仕様に従い、`maxReceiveCount` は JSON の文字列値として送信する必要があります。

## 検証

修正後、Terraform の terraform plan/apply で以下を確認してください：

```bash
terraform plan
terraform apply
```

SQS キューの RedrivePolicy が正常に設定されることを確認します。
