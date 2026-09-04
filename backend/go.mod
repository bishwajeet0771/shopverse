module github.com/shopverse/backend

go 1.24

require (
	github.com/aws/aws-sdk-go-v2/config v1.27.27
	github.com/aws/aws-sdk-go-v2/service/secretsmanager v1.32.6
	github.com/gofiber/fiber/v2 v2.52.11
	github.com/golang-jwt/jwt/v5 v5.2.0
	golang.org/x/crypto v0.31.0
	gorm.io/driver/postgres v1.5.9
	gorm.io/gorm v1.25.5
)

require (
	github.com/andybalholm/brotli v1.0.5 // indirect
	github.com/aws/aws-sdk-go-v2 v1.30.3 // indirect
	github.com/aws/smithy-go v1.20.3 // indirect
	github.com/google/uuid v1.5.0 // indirect
	github.com/jackc/pgpassfile v1.0.0 // indirect
	github.com/jackc/pgservicefile v0.0.0-20221227161230-091c0ba34f0a // indirect
	github.com/jackc/pgx/v5 v5.5.5 // indirect
	github.com/jinzhu/inflection v1.0.0 // indirect
	github.com/jinzhu/now v1.1.5 // indirect
	github.com/klauspost/compress v1.17.0 // indirect
	github.com/mattn/go-colorable v0.1.13 // indirect
	github.com/mattn/go-isatty v0.0.20 // indirect
	github.com/mattn/go-runewidth v0.0.15 // indirect
	github.com/rivo/uniseg v0.2.0 // indirect
	github.com/valyala/bytebufferpool v1.0.0 // indirect
	github.com/valyala/fasthttp v1.51.0 // indirect
	github.com/valyala/tcplisten v1.0.0 // indirect
	golang.org/x/sys v0.16.0 // indirect
	golang.org/x/text v0.16.0 // indirect
)

// NOTE: run `go mod tidy` after unzipping — this pulls the real, verified
// checksums for the AWS SDK / pgx modules into go.sum (they were removed
// here since this environment has no network access to the Go module proxy).
