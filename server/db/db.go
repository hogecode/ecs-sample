package db

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"log"

	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/secretsmanager"
	_ "github.com/go-sql-driver/mysql"
)

// DBCredentials は Secrets Manager から取得するDB接続情報
type DBCredentials struct {
	Username string `json:"username"`
	Password string `json:"password"`
	Host     string `json:"host"`
	Database string `json:"database"`
	Port     int    `json:"port"`
	Engine   string `json:"engine"`
}

// GetDBFromSecrets は Secrets Manager からDBクレデンシャルを取得して接続を確立する
func GetDBFromSecrets(ctx context.Context, secretARN string) (*sql.DB, error) {
	// AWS Secrets Manager クライアントを初期化
	cfg, err := config.LoadDefaultConfig(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to load AWS config: %w", err)
	}

	client := secretsmanager.NewFromConfig(cfg)

	// シークレットを取得
	result, err := client.GetSecretValue(ctx, &secretsmanager.GetSecretValueInput{
		SecretId: &secretARN,
	})
	if err != nil {
		return nil, fmt.Errorf("failed to get secret from Secrets Manager: %w", err)
	}

	// JSON をパース
	var credentials DBCredentials
	err = json.Unmarshal([]byte(*result.SecretString), &credentials)
	if err != nil {
		return nil, fmt.Errorf("failed to parse secret JSON: %w", err)
	}

	// MySQL DSN を構築
	dsn := fmt.Sprintf(
		"%s:%s@tcp(%s:%d)/%s?parseTime=true",
		credentials.Username,
		credentials.Password,
		credentials.Host,
		credentials.Port,
		credentials.Database,
	)

	// データベース接続を確立
	db, err := sql.Open("mysql", dsn)
	if err != nil {
		return nil, fmt.Errorf("failed to open database: %w", err)
	}

	// 接続をテスト
	err = db.PingContext(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to ping database: %w", err)
	}

	log.Printf("Successfully connected to database: %s@%s:%d/%s", credentials.Username, credentials.Host, credentials.Port, credentials.Database)

	// コネクションプール設定
	db.SetMaxOpenConns(25)
	db.SetMaxIdleConns(5)

	return db, nil
}
