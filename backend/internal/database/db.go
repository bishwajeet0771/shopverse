package database

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"time"

	"github.com/shopverse/backend/internal/models"

	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/secretsmanager"

	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

var DB *gorm.DB

// RDSCredentials represents the PostgreSQL credentials
// stored in AWS Secrets Manager.
type RDSCredentials struct {
	Username string `json:"username"`
	Password string `json:"password"`
	Host     string `json:"host"`
	Port     int    `json:"port"`
	Database string `json:"database"`
	SSLMode  string `json:"sslmode"`
}

// Connect retrieves the RDS credentials from AWS Secrets Manager
// and establishes a connection to PostgreSQL.
func Connect() {
	secretName := os.Getenv("DB_SECRET_NAME")

	if secretName == "" {
		log.Fatal("DB_SECRET_NAME environment variable is required")
	}

	log.Printf(
		"Retrieving database credentials from AWS Secrets Manager: %s",
		secretName,
	)

	credentials, err := getRDSCredentials(secretName)
	if err != nil {
		log.Fatalf(
			"Failed to retrieve RDS credentials from Secrets Manager: %v",
			err,
		)
	}

	// PostgreSQL defaults.
	if credentials.Port == 0 {
		credentials.Port = 5432
	}

	if credentials.SSLMode == "" {
		credentials.SSLMode = "require"
	}

	// Build PostgreSQL DSN.
	dsn := fmt.Sprintf(
		"host=%s user=%s password=%s dbname=%s port=%d sslmode=%s",
		credentials.Host,
		credentials.Username,
		credentials.Password,
		credentials.Database,
		credentials.Port,
		credentials.SSLMode,
	)

	var errDB error

	// RDS may take a short amount of time to become reachable.
	// Retry the connection instead of immediately terminating.
	for attempt := 1; attempt <= 10; attempt++ {
		log.Printf(
			"Connecting to PostgreSQL (attempt %d/10)...",
			attempt,
		)

		DB, errDB = gorm.Open(
			postgres.Open(dsn),
			&gorm.Config{
				Logger: logger.Default.LogMode(logger.Info),
			},
		)

		if errDB == nil {
			// Verify the underlying database connection.
			sqlDB, sqlErr := DB.DB()

			if sqlErr != nil {
				errDB = sqlErr
			} else {
				errDB = sqlDB.Ping()
			}
		}

		if errDB == nil {
			break
		}

		log.Printf(
			"Database connection attempt %d/10 failed: %v",
			attempt,
			errDB,
		)

		if attempt < 10 {
			log.Println("Retrying database connection in 5 seconds...")
			time.Sleep(5 * time.Second)
		}
	}

	if errDB != nil {
		log.Fatalf(
			"Failed to connect to PostgreSQL after 10 attempts: %v",
			errDB,
		)
	}

	log.Println("PostgreSQL database connected successfully")

	// Run database migrations.
	if err := migrateDatabase(); err != nil {
		log.Fatalf(
			"Failed to migrate database: %v",
			err,
		)
	}

	log.Println("Database migrated successfully")

	// Seed sample products.
	seedProducts()
}

// getRDSCredentials retrieves the PostgreSQL credentials
// from AWS Secrets Manager.
//
// AWS credentials are automatically obtained from the EKS
// Pod Identity / AWS SDK default credential chain.
func getRDSCredentials(secretName string) (*RDSCredentials, error) {
	ctx, cancel := context.WithTimeout(
		context.Background(),
		30*time.Second,
	)
	defer cancel()

	// Load AWS configuration.
	//
	// In EKS production, this uses the IAM permissions
	// provided through EKS Pod Identity.
	cfg, err := config.LoadDefaultConfig(ctx)

	if err != nil {
		return nil, fmt.Errorf(
			"failed to load AWS configuration: %w",
			err,
		)
	}

	client := secretsmanager.NewFromConfig(cfg)

	result, err := client.GetSecretValue(
		ctx,
		&secretsmanager.GetSecretValueInput{
			SecretId: &secretName,
		},
	)

	if err != nil {
		return nil, fmt.Errorf(
			"failed to retrieve secret %q: %w",
			secretName,
			err,
		)
	}

	if result.SecretString == nil {
		return nil, fmt.Errorf(
			"secret %q does not contain SecretString",
			secretName,
		)
	}

	var credentials RDSCredentials

	if err := json.Unmarshal(
		[]byte(*result.SecretString),
		&credentials,
	); err != nil {
		return nil, fmt.Errorf(
			"failed to parse RDS credentials from secret: %w",
			err,
		)
	}

	// Validate required credentials.
	if credentials.Username == "" {
		return nil, fmt.Errorf(
			"RDS secret is missing username",
		)
	}

	if credentials.Password == "" {
		return nil, fmt.Errorf(
			"RDS secret is missing password",
		)
	}

	if credentials.Host == "" {
		return nil, fmt.Errorf(
			"RDS secret is missing host",
		)
	}

	if credentials.Database == "" {
		return nil, fmt.Errorf(
			"RDS secret is missing database",
		)
	}

	return &credentials, nil
}

// migrateDatabase runs all GORM database migrations.
func migrateDatabase() error {
	return DB.AutoMigrate(
		&models.User{},
		&models.Product{},
		&models.CartItem{},
		&models.Order{},
		&models.OrderItem{},
	)
}

// seedProducts inserts the application's sample products.
//
// The function is intentionally idempotent so that restarting
// a pod does not create duplicate products.
func seedProducts() {
	products := []models.Product{
		// Electronics
		{
			Name: "Wireless Noise-Cancelling Headphones",
			Category: "Electronics",
			Price: 79.99,
			OriginalPrice: 129.99,
			Rating: 4.8,
			ReviewCount: 2847,
			Badge: "Best Seller",
			Emoji: "🎧",
			Color: "from-violet-500 to-purple-600",
		},
		{
			Name: "Smart Fitness Watch",
			Category: "Electronics",
			Price: 149.99,
			OriginalPrice: 199.99,
			Rating: 4.7,
			ReviewCount: 3891,
			Badge: "Top Rated",
			Emoji: "⌚",
			Color: "from-emerald-500 to-teal-600",
		},
		{
			Name: "Portable Bluetooth Speaker",
			Category: "Electronics",
			Price: 44.99,
			OriginalPrice: 69.99,
			Rating: 4.3,
			ReviewCount: 2156,
			Badge: "Sale",
			Emoji: "🔊",
			Color: "from-indigo-500 to-blue-600",
		},
		{
			Name: "Wireless Charging Pad",
			Category: "Electronics",
			Price: 29.99,
			OriginalPrice: 44.99,
			Rating: 4.4,
			ReviewCount: 1834,
			Badge: "Popular",
			Emoji: "🔋",
			Color: "from-cyan-500 to-blue-500",
		},
		{
			Name: "4K Action Camera",
			Category: "Electronics",
			Price: 199.99,
			OriginalPrice: 279.99,
			Rating: 4.6,
			ReviewCount: 1245,
			Badge: "New",
			Emoji: "📷",
			Color: "from-gray-700 to-gray-900",
		},
		{
			Name: "Mechanical Gaming Keyboard",
			Category: "Electronics",
			Price: 89.99,
			OriginalPrice: 119.99,
			Rating: 4.7,
			ReviewCount: 3456,
			Badge: "Gamer Pick",
			Emoji: "⌨️",
			Color: "from-red-500 to-rose-600",
		},
		{
			Name: "USB-C Hub 7-in-1",
			Category: "Electronics",
			Price: 34.99,
			OriginalPrice: 49.99,
			Rating: 4.5,
			ReviewCount: 2103,
			Badge: "Essential",
			Emoji: "🔌",
			Color: "from-slate-500 to-gray-600",
		},

		// Clothing
		{
			Name: "Premium Cotton T-Shirt",
			Category: "Clothing",
			Price: 24.99,
			OriginalPrice: 39.99,
			Rating: 4.5,
			ReviewCount: 1523,
			Badge: "Popular",
			Emoji: "👕",
			Color: "from-blue-500 to-cyan-500",
		},
		{
			Name: "Classic Denim Jacket",
			Category: "Clothing",
			Price: 69.99,
			OriginalPrice: 99.99,
			Rating: 4.6,
			ReviewCount: 892,
			Badge: "Trending",
			Emoji: "🧥",
			Color: "from-blue-600 to-indigo-700",
		},
		{
			Name: "Running Sneakers Pro",
			Category: "Clothing",
			Price: 89.99,
			OriginalPrice: 129.99,
			Rating: 4.8,
			ReviewCount: 4521,
			Badge: "Best Seller",
			Emoji: "👟",
			Color: "from-orange-500 to-red-500",
		},
		{
			Name: "Cozy Wool Sweater",
			Category: "Clothing",
			Price: 54.99,
			OriginalPrice: 79.99,
			Rating: 4.4,
			ReviewCount: 678,
			Badge: "Winter Pick",
			Emoji: "🧶",
			Color: "from-amber-600 to-orange-700",
		},

		// Accessories
		{
			Name: "Minimalist Leather Wallet",
			Category: "Accessories",
			Price: 34.99,
			OriginalPrice: 49.99,
			Rating: 4.4,
			ReviewCount: 1205,
			Badge: "New",
			Emoji: "👛",
			Color: "from-rose-500 to-pink-600",
		},
		{
			Name: "Stainless Steel Water Bottle",
			Category: "Accessories",
			Price: 19.99,
			OriginalPrice: 29.99,
			Rating: 4.5,
			ReviewCount: 1876,
			Badge: "Eco-Friendly",
			Emoji: "💧",
			Color: "from-sky-500 to-blue-600",
		},
		{
			Name: "Polarized Aviator Sunglasses",
			Category: "Accessories",
			Price: 39.99,
			OriginalPrice: 59.99,
			Rating: 4.6,
			ReviewCount: 2341,
			Badge: "UV Protection",
			Emoji: "🕶️",
			Color: "from-amber-500 to-yellow-600",
		},
		{
			Name: "Canvas Laptop Backpack",
			Category: "Accessories",
			Price: 49.99,
			OriginalPrice: 74.99,
			Rating: 4.7,
			ReviewCount: 1567,
			Badge: "Top Rated",
			Emoji: "🎒",
			Color: "from-green-600 to-emerald-700",
		},
		{
			Name: "Leather Belt Premium",
			Category: "Accessories",
			Price: 29.99,
			OriginalPrice: 44.99,
			Rating: 4.3,
			ReviewCount: 934,
			Badge: "Classic",
			Emoji: "👔",
			Color: "from-yellow-700 to-amber-800",
		},

		// Food & Drinks
		{
			Name: "Organic Coffee Beans 1kg",
			Category: "Food & Drinks",
			Price: 18.99,
			OriginalPrice: 24.99,
			Rating: 4.6,
			ReviewCount: 967,
			Badge: "Organic",
			Emoji: "☕",
			Color: "from-amber-500 to-orange-600",
		},
		{
			Name: "Premium Green Tea Collection",
			Category: "Food & Drinks",
			Price: 14.99,
			OriginalPrice: 22.99,
			Rating: 4.5,
			ReviewCount: 723,
			Badge: "Healthy",
			Emoji: "🍵",
			Color: "from-green-500 to-emerald-600",
		},
		{
			Name: "Dark Chocolate Gift Box",
			Category: "Food & Drinks",
			Price: 24.99,
			OriginalPrice: 34.99,
			Rating: 4.8,
			ReviewCount: 1456,
			Badge: "Gift Pick",
			Emoji: "🍫",
			Color: "from-amber-700 to-yellow-900",
		},
		{
			Name: "Mixed Nuts Gourmet Pack",
			Category: "Food & Drinks",
			Price: 12.99,
			OriginalPrice: 18.99,
			Rating: 4.4,
			ReviewCount: 845,
			Badge: "Snack Pack",
			Emoji: "🥜",
			Color: "from-yellow-500 to-amber-600",
		},

		// Sports
		{
			Name: "Yoga Mat Premium Non-Slip",
			Category: "Sports",
			Price: 29.99,
			OriginalPrice: 45.99,
			Rating: 4.9,
			ReviewCount: 4210,
			Badge: "Top Rated",
			Emoji: "🧘",
			Color: "from-green-500 to-emerald-600",
		},
		{
			Name: "Resistance Bands Set",
			Category: "Sports",
			Price: 19.99,
			OriginalPrice: 34.99,
			Rating: 4.6,
			ReviewCount: 3124,
			Badge: "Home Gym",
			Emoji: "💪",
			Color: "from-red-500 to-orange-600",
		},
		{
			Name: "Insulated Sports Bottle",
			Category: "Sports",
			Price: 24.99,
			OriginalPrice: 39.99,
			Rating: 4.5,
			ReviewCount: 1890,
			Badge: "Active",
			Emoji: "🏃",
			Color: "from-teal-500 to-green-600",
		},
		{
			Name: "Jump Rope Speed Pro",
			Category: "Sports",
			Price: 15.99,
			OriginalPrice: 24.99,
			Rating: 4.3,
			ReviewCount: 1234,
			Badge: "Cardio",
			Emoji: "🏋️",
			Color: "from-purple-500 to-indigo-600",
		},

		// Home & Living
		{
			Name: "Scented Soy Candle Set",
			Category: "Home & Living",
			Price: 22.99,
			OriginalPrice: 34.99,
			Rating: 4.7,
			ReviewCount: 2567,
			Badge: "Relaxation",
			Emoji: "🕯️",
			Color: "from-pink-400 to-rose-500",
		},
		{
			Name: "Bamboo Desk Organizer",
			Category: "Home & Living",
			Price: 27.99,
			OriginalPrice: 39.99,
			Rating: 4.4,
			ReviewCount: 876,
			Badge: "Eco-Friendly",
			Emoji: "🗂️",
			Color: "from-lime-500 to-green-600",
		},
		{
			Name: "Ceramic Plant Pot Set",
			Category: "Home & Living",
			Price: 32.99,
			OriginalPrice: 49.99,
			Rating: 4.6,
			ReviewCount: 1345,
			Badge: "Decor",
			Emoji: "🪴",
			Color: "from-emerald-400 to-teal-500",
		},
		{
			Name: "Cozy Throw Blanket",
			Category: "Home & Living",
			Price: 39.99,
			OriginalPrice: 59.99,
			Rating: 4.8,
			ReviewCount: 2890,
			Badge: "Comfort",
			Emoji: "🛋️",
			Color: "from-violet-400 to-purple-500",
		},
	}

	for _, product := range products {
		var existingProduct models.Product

		result := DB.
			Where("name = ?", product.Name).
			First(&existingProduct)

		if result.Error == gorm.ErrRecordNotFound {
			if err := DB.Create(&product).Error; err != nil {
				log.Printf(
					"Failed to seed product %q: %v",
					product.Name,
					err,
				)
			}
		} else if result.Error != nil {
			log.Printf(
				"Failed to check product %q: %v",
				product.Name,
				result.Error,
			)
		}
	}

	log.Println("Product seeding completed")
}
