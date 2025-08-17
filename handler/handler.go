package handler

import (
	"context"
	"encoding/json"
	"log/slog"
)

func Handler(ctx context.Context, event json.RawMessage) error {
	slog.Info("unhandled message", string(event))
	return nil
}
