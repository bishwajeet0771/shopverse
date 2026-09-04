package database

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/secretsmanager"
)

// DBCredentials mirrors the JSON shape stored in the Secrets Manager
// secret created by terraform/modules/rds (see aws_secretsmanager_secret_version).
type DBCredentials struct {
	Username string `json:"username"`
	Password string `json:"password"`
	Host     string `json:"host"`
	Port     string `json:"port"`
	DBName   string `json:"dbname"`
}

// fetchDBCredentialsFromSecretsManager loads DB connection details from
// AWS Secrets Manager using the ambient AWS credentials (IRSA on EKS
// provides these automatically to the pod — no static keys needed).
func fetchDBCredentialsFromSecretsManager(ctx context.Context, secretArn, region string) (*DBCredentials, error) {
	cfgOpts := []func(*config.LoadOptions) error{}
	if region != "" {
		cfgOpts = append(cfgOpts, config.WithRegion(region))
	}

	awsCfg, err := config.LoadDefaultConfig(ctx, cfgOpts...)
	if err != nil {
		return nil, fmt.Errorf("failed to load AWS config: %w", err)
	}

	client := secretsmanager.NewFromConfig(awsCfg)

	result, err := client.GetSecretValue(ctx, &secretsmanager.GetSecretValueInput{
		SecretId: &secretArn,
	})
	if err != nil {
		return nil, fmt.Errorf("failed to fetch secret %q: %w", secretArn, err)
	}

	if result.SecretString == nil {
		return nil, fmt.Errorf("secret %q has no SecretString payload", secretArn)
	}

	var creds DBCredentials
	if err := json.Unmarshal([]byte(*result.SecretString), &creds); err != nil {
		return nil, fmt.Errorf("failed to parse secret JSON: %w", err)
	}

	return &creds, nil
}
