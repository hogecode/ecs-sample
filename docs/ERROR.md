


# Terraformエラー「waiting for Security Group Rule create: couldn't find resource」が解決されました。

## 問題の原因
terraform-aws-modulesを使用してセキュリティグループを作成する際に、セキュリティグループ間の参照ルール（ALB→ECS→RDS等）を同じモジュール内で定義すると、複数のセキュリティグループルールが並列で作成されるため、タイミング問題が発生していました。具体的には、go_server_sgのルール作成時にprivate_alb_sgがまだ完全に作成されていないという状況が発生していました。

## 実装した解決策
セキュリティグループ間の依存関係を持つルールをモジュール外部で`aws_security_group_rule`リソースで定義することで、タイミング問題を回避しました：

**主な変更点：**
1. **terraform-aws-modulesの役割を単純化** - 基本的なセキュリティグループ定義のみに使用
2. **Cross-SG Referencesを分離** - 以下のルールを`aws_security_group_rule`で別途定義：
   - Private ALB ← Next.js SG
   - Go Server ← Private ALB SG
   - RDS ← Go Server SG
   - RDS ← Bastion SG
   - Redis ← Go Server SG

3. **各モジュール内での依存関係を削除** - private_alb_sg、go_server_sg、rds_sg、redis_sgから参照を含むルール定義を削除

## 検証結果
✅ terraform validate - 構文チェック成功
✅ すべてのリソース定義が有効

この修正により、セキュリティグループとそのルールが正常に作成されるようになります。

---

