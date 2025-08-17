package handler

import (
	"context"
	"log/slog"
	"os"
	"strings"

	"github.com/aws/aws-lambda-go/events"
)

var downlinkAPIKey = os.Getenv("DOWNLINK_API_KEY")

func Handler(ctx context.Context, req events.LambdaFunctionURLRequest) (events.LambdaFunctionURLResponse, error) {
	// Ensure server is configured
	if strings.TrimSpace(downlinkAPIKey) == "" {
		slog.Error("DOWNLINK_API_KEY not configured")
		return events.LambdaFunctionURLResponse{
			StatusCode: 500,
			Body:       "server not configured",
		}, nil
	}

	// Fetch header value case-insensitively
	gotHeader := ""
	for k, v := range req.Headers {
		if strings.EqualFold(k, "X-Downlink-Apikey") {
			gotHeader = v
			break
		}
	}

	if gotHeader == "" || gotHeader != downlinkAPIKey {
		slog.Warn("unauthorized request: missing or invalid X-Downlink-Apikey")
		return events.LambdaFunctionURLResponse{
			StatusCode: 401,
			Body:       "unauthorized",
		}, nil
	}

	// Authorized: log body and return OK
	slog.Info("received unknown request body", "length", len(req.Body), "payload", req.Body)
	return events.LambdaFunctionURLResponse{
		StatusCode: 200,
		Body:       "ok",
	}, nil
}
