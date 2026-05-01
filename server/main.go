package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/hogecode/ecs-sample/server/db"
	"github.com/hogecode/ecs-sample/server/db/generated"
)

func main() {
	r := gin.Default()

	// AWS Secrets Manager ARN を環境変数から取得
	secretARN := os.Getenv("DB_CREDENTIALS_SECRET_ARN")
	if secretARN == "" {
		log.Fatal("DB_CREDENTIALS_SECRET_ARN environment variable is not set")
	}

	// コンテキストを作成
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	// Secrets Manager からDB接続情報を取得して接続を確立
	database, err := db.GetDBFromEnv(ctx, secretARN)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer database.Close()

	// 従業員クエリを作成
	queries := generated.New(database)

	// CORSを有効化
	r.Use(func(c *gin.Context) {
		c.Writer.Header().Set("Access-Control-Allow-Origin", "*")
		c.Writer.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		c.Writer.Header().Set("Access-Control-Allow-Headers", "Content-Type")
		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(204)
			return
		}
		c.Next()
	})

	// Health Check Endpoint
	r.GET("/api/health", func(c *gin.Context) {
		c.JSON(200, gin.H{
			"status": "healthy",
		})
	})

	// Hello World API
	r.GET("/api/hello", func(c *gin.Context) {
		c.JSON(200, gin.H{
			"message": "Hello, World!",
			"status":  "success",
		})
	})

	// 従業員一覧取得エンドポイント
	r.GET("/api/employees", func(c *gin.Context) {
		limit := 10
		offset := 0

		if l := c.Query("limit"); l != "" {
			if parsed, err := strconv.Atoi(l); err == nil && parsed > 0 {
				limit = parsed
			}
		}

		if o := c.Query("offset"); o != "" {
			if parsed, err := strconv.Atoi(o); err == nil && parsed >= 0 {
				offset = parsed
			}
		}

		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()

		employees, err := queries.ListEmployees(ctx, generated.ListEmployeesParams{
			Limit:  int32(limit),
			Offset: int32(offset),
		})
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{
				"error": "Failed to fetch employees",
			})
			return
		}

		c.JSON(200, gin.H{
			"data": employees,
			"count": len(employees),
		})
	})

	// 従業員ID取得エンドポイント
	r.GET("/api/employees/:id", func(c *gin.Context) {
		id, err := strconv.ParseInt(c.Param("id"), 10, 64)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{
				"error": "Invalid employee ID",
			})
			return
		}

		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()

		employees, err := queries.GetEmployeeByID(ctx, id)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{
				"error": "Failed to fetch employee",
			})
			return
		}

		c.JSON(200, employees)
	})

	// 従業員作成エンドポイント
	r.POST("/api/employees", func(c *gin.Context) {
		var req struct {
			Name       string  `json:"name" binding:"required"`
			Email      string  `json:"email" binding:"required,email"`
			Department string  `json:"department" binding:"required"`
			Salary     float64 `json:"salary" binding:"required,gt=0"`
		}

		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{
				"error": err.Error(),
			})
			return
		}

		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()

		err := queries.CreateEmployee(ctx, generated.CreateEmployeeParams{
			Name:       req.Name,
			Email:      req.Email,
			Department: req.Department,
			Salary:     fmt.Sprintf("%.2f", req.Salary),
		})
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{
				"error": "Failed to create employee",
			})
			return
		}

		// 最後に挿入された ID を持つ従業員を取得するため、メールアドレスで検索
		// または LastInsertId を使用することもできますが、ここでは最新の ID を推測
		// 本来は DB から最後に挿入された ID を取得する必要があります
		c.JSON(http.StatusCreated, gin.H{
			"status": "Employee created successfully",
		})
	})

	// 従業員更新エンドポイント
	r.PUT("/api/employees/:id", func(c *gin.Context) {
		id, err := strconv.ParseInt(c.Param("id"), 10, 64)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{
				"error": "Invalid employee ID",
			})
			return
		}

		var req struct {
			Name       string  `json:"name" binding:"required"`
			Email      string  `json:"email" binding:"required,email"`
			Department string  `json:"department" binding:"required"`
			Salary     float64 `json:"salary" binding:"required,gt=0"`
		}

		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{
				"error": err.Error(),
			})
			return
		}

		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()

		err = queries.UpdateEmployee(ctx, generated.UpdateEmployeeParams{
			Name:       req.Name,
			Email:      req.Email,
			Department: req.Department,
			Salary:     fmt.Sprintf("%.2f", req.Salary),
			ID:         id,
		})
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{
				"error": "Failed to update employee",
			})
			return
		}

		// 更新後の従業員データを取得
		employee, err := queries.GetEmployeeByID(ctx, id)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{
				"error": "Failed to fetch updated employee",
			})
			return
		}

		c.JSON(200, employee)
	})

	// 従業員削除エンドポイント
	r.DELETE("/api/employees/:id", func(c *gin.Context) {
		id, err := strconv.ParseInt(c.Param("id"), 10, 64)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{
				"error": "Invalid employee ID",
			})
			return
		}

		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()

		if err := queries.DeleteEmployee(ctx, id); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{
				"error": "Failed to delete employee",
			})
			return
		}

		c.JSON(200, gin.H{
			"status": "Employee deleted successfully",
		})
	})

	// サーバー起動
	r.Run(":8080")
}
