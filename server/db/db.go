package db

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"strconv"

	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/secretsmanager"
	_ "github.com/go-sql-driver/mysql"
)

// DBCredentials は AWS Secrets Manager から取得するマスターユーザーのクレデンシャル
// AWS RDS manage_master_user_password で管理される場合、JSON には username と password のみが含まれる
type DBCredentials struct {
	Username string `json:"username"`
	Password string `json:"password"`
}

// GetDBFromEnv は環境変数から RDS 接続情報と Secrets Manager ARN を取得して接続を確立する
func GetDBFromEnv(ctx context.Context, masterSecretARN string) (*sql.DB, error) {
	log.Printf("Starting database initialization from environment variables...")

	// 環境変数から RDS 接続情報を取得
	host := os.Getenv("DB_HOST")
	portStr := os.Getenv("DB_PORT")
	database := os.Getenv("DB_NAME")
	engine := os.Getenv("DB_ENGINE")

	if host == "" || portStr == "" || database == "" {
		return nil, fmt.Errorf("missing required environment variables: DB_HOST, DB_PORT, DB_NAME")
	}

	port := 3306
	if portNum, err := strconv.Atoi(portStr); err == nil {
		port = portNum
	}

	log.Printf("RDS Configuration from environment: host=%s, port=%d, database=%s, engine=%s", host, port, database, engine)

	// AWS Secrets Manager クライアントを初期化
	log.Printf("Loading AWS configuration...")
	cfg, err := config.LoadDefaultConfig(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to load AWS config: %w", err)
	}

	client := secretsmanager.NewFromConfig(cfg)

	// RDS Master Secret ARN からクレデンシャルを取得
	log.Printf("Fetching RDS master credentials from Secrets Manager: %s", masterSecretARN)
	result, err := client.GetSecretValue(ctx, &secretsmanager.GetSecretValueInput{
		SecretId: &masterSecretARN,
	})
	if err != nil {
		return nil, fmt.Errorf("failed to get RDS master secret from Secrets Manager: %w", err)
	}
	log.Printf("Successfully retrieved RDS master credentials from Secrets Manager")

	// JSON をパース
	log.Printf("Parsing RDS master credentials JSON...")
	var credentials DBCredentials
	err = json.Unmarshal([]byte(*result.SecretString), &credentials)
	if err != nil {
		return nil, fmt.Errorf("failed to parse RDS master secret JSON: %w", err)
	}
	log.Printf("RDS master credentials parsed: user=%s", credentials.Username)

	// DSN を構築 (環境変数から host, port, database を使用し、Secrets Manager からは username/password を使用)
	log.Printf("Building database DSN: %s@%s:%d/%s", credentials.Username, host, port, database)
	var dsn string
	switch engine {
	case "postgres":
		dsn = fmt.Sprintf(
			"user=%s password=%s host=%s port=%d dbname=%s sslmode=disable",
			credentials.Username,
			credentials.Password,
			host,
			port,
			database,
		)
	case "mysql", "":
		dsn = fmt.Sprintf(
			"%s:%s@tcp(%s:%d)/%s?parseTime=true",
			credentials.Username,
			credentials.Password,
			host,
			port,
			database,
		)
	default:
		return nil, fmt.Errorf("unsupported database engine: %s", engine)
	}

	// データベース接続を確立
	log.Printf("Attempting to open database connection to %s:%d...", host, port)
	db, err := sql.Open(engine, dsn)
	if err != nil {
		return nil, fmt.Errorf("failed to open database connection: %w", err)
	}
	log.Printf("Database connection object created, testing connection with PingContext...")

	// 接続をテスト
	log.Printf("Testing database connection (timeout: context duration)...")
	err = db.PingContext(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to ping database at %s:%d (check RDS security group and network): %w", host, port, err)
	}
	log.Printf("Database connection successful!")

	log.Printf("Successfully connected to database: %s@%s:%d/%s", credentials.Username, host, port, database)

	// コネクションプール設定
	db.SetMaxOpenConns(25)
	db.SetMaxIdleConns(5)

	return db, nil
}
