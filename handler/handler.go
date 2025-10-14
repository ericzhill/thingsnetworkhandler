package handler

import (
	"context"
	_ "embed"
	"encoding/json"
	"log/slog"
	"os"
	"strings"
	"time"

	"github.com/aws/aws-lambda-go/events"
)

var downlinkAPIKey = os.Getenv("DOWNLINK_API_KEY")

type ttnDeviceId struct {
	DeviceId   string `json:"device_id"`
	DevEUI     string `json:"dev_eui"`
	JoinEUI    string `json:"join_eui"`
	DeviceAddr string `json:"dev_addr"`
}
type ttnIdentifier struct {
	DeviceInfo ttnDeviceId `json:"device_ids"`
}

type ttnUplinkMessage struct {
	SessionKey string    `json:"session_key_id"`
	Port       string    `json:"f_port"`
	Control    string    `json:"f_cnt"`
	Payload    string    `json:"frm_payload"`
	ReceivedAt time.Time `json:"received_at"`
}

type ttnEventData struct {
	Type          string           `json:"@type"`
	DeviceId      string           `json:"end_device_ids"`
	UplinkMessage ttnUplinkMessage `json:"uplink_message"`
}
type ttnEvent struct {
	Name        string          `json:"name"`
	Time        time.Time       `json:"time"`
	Identifiers []ttnIdentifier `json:"identifiers"`
	EventData   ttnEventData    `json:"data"`
}

//go:embed version.info
var version string

func Handler(ctx context.Context, req events.LambdaFunctionURLRequest) (events.LambdaFunctionURLResponse, error) {
	slog.Info("handler startup", "version", version)

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

	// Unpack the list of events and process them accordingly
	var ttnEvents []ttnEvent = make([]ttnEvent, 0)
	err := json.Unmarshal([]byte(req.Body), &ttnEvents)
	if err != nil {
		return events.LambdaFunctionURLResponse{
			StatusCode: 500,
			Body:       "internal marshalling error",
		}, err
	}
	if len(ttnEvents) == 0 {
		// Authorized: log body and return OK
		slog.Info("received request body that didn't unpack", "length", len(req.Body), "payload", req.Body)
		return events.LambdaFunctionURLResponse{
			StatusCode: 200,
			Body:       "ok",
		}, nil
	}
	for _, ev := range ttnEvents {
		switch ev.Name {
		case "ns.up.data.forward":
			slog.Info("found", "payload", ev.EventData.UplinkMessage.Payload)
		default:
			slog.Info("received and ignored event", "event", ev.Name, "payload", req.Body)
		}
	}

	// Authorized: log body and return OK
	slog.Info("received unknown request body", "length", len(req.Body), "payload", req.Body)
	return events.LambdaFunctionURLResponse{
		StatusCode: 200,
		Body:       "ok",
	}, nil
}
