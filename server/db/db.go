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
	log.Printf("Starting database initialization...")

	// AWS Secrets Manager クライアントを初期化
	log.Printf("Loading AWS configuration...")
	cfg, err := config.LoadDefaultConfig(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to load AWS config: %w", err)
	}

	client := secretsmanager.NewFromConfig(cfg)

	// シークレットを取得
	log.Printf("Fetching DB credentials from Secrets Manager: %s", secretARN)
	result, err := client.GetSecretValue(ctx, &secretsmanager.GetSecretValueInput{
		SecretId: &secretARN,
	})
	if err != nil {
		return nil, fmt.Errorf("failed to get secret from Secrets Manager: %w", err)
	}
	log.Printf("Successfully retrieved DB credentials from Secrets Manager")

	// JSON をパース
	log.Printf("Parsing DB credentials JSON...")
	var credentials DBCredentials
	err = json.Unmarshal([]byte(*result.SecretString), &credentials)
	if err != nil {
		return nil, fmt.Errorf("failed to parse secret JSON: %w", err)
	}
	log.Printf("DB credentials parsed: host=%s, port=%d, database=%s, user=%s", credentials.Host, credentials.Port, credentials.Database, credentials.Username)

	// MySQL DSN を構築
	log.Printf("Building MySQL DSN: %s@%s:%d/%s", credentials.Username, credentials.Host, credentials.Port, credentials.Database)
	dsn := fmt.Sprintf(
		"%s:%s@tcp(%s:%d)/%s?parseTime=true",
		credentials.Username,
		credentials.Password,
		credentials.Host,
		credentials.Port,
		credentials.Database,
	)

	// データベース接続を確立
	log.Printf("Attempting to open database connection to %s:%d...", credentials.Host, credentials.Port)
	db, err := sql.Open("mysql", dsn)
	if err != nil {
		return nil, fmt.Errorf("failed to open database connection: %w", err)
	}
	log.Printf("Database connection object created, testing connection with PingContext...")

	// 接続をテスト
	log.Printf("Testing database connection (timeout: context duration)...")
	err = db.PingContext(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to ping database at %s:%d (check RDS security group and network): %w", credentials.Host, credentials.Port, err)
	}
	log.Printf("Database connection successful!")

	log.Printf("Successfully connected to database: %s@%s:%d/%s", credentials.Username, credentials.Host, credentials.Port, credentials.Database)

	// コネクションプール設定
	db.SetMaxOpenConns(25)
	db.SetMaxIdleConns(5)

	return db, nil
}
