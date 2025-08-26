package handler

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
	"thingsnetworkhandler/sensors"
)

type uplinkMessage struct {
	FPort      int    `json:"f_port"`
	FrmPayload string `json:"frm_payload"`
}

type eventData struct {
	UplinkMessage uplinkMessage `json:"uplink_message"`
}

type eventRecord struct {
	Name string    `json:"name"`
	Data eventData `json:"data"`
}

// TestPayload001 detects the uplink events in the captured payload file,
// sends the frm_payload through the LHT52 unpacker, and logs values.
func TestPayload001(t *testing.T) {
	// Locate the sample payload file relative to this test file.
	wd, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	// handler package is under handler/, samples are at ../samples/
	samplePath := filepath.Join(wd, "..", "samples", "eui-a840416c81850cd1_live_data_1752852388582.json")
	b, err := os.ReadFile(samplePath)
	if err != nil {
		t.Fatalf("failed reading sample file: %v", err)
	}

	var events []eventRecord
	if err := json.Unmarshal(b, &events); err != nil {
		t.Fatalf("failed to unmarshal sample JSON: %v", err)
	}

	found := 0
	for _, ev := range events {
		if ev.Name != "as.up.data.forward" {
			continue
		}
		upl := ev.Data.UplinkMessage
		if upl.FrmPayload == "" || upl.FPort != 2 {
			continue
		}
		reading, err := sensors.NewLHT52SensorReading(upl.FrmPayload)
		if err != nil {
			// Not an LHT52 payload; skip but note for debugging
			t.Logf("skipping payload on f_port=%d due to decode error: %v", upl.FPort, err)
			continue
		}
		found++
		t.Logf("LHT52 reading: EventType=%d TempC=%.2f TempF=%.3f Hum=%.1f%% Timestamp=%s",
			reading.EventType, reading.TempCelsius, reading.TempFahrenheit, reading.Humidity, reading.Timestamp.UTC().Format("2006-01-02T15:04:05Z"))
	}

	if found == 0 {
		t.Fatalf("no decodable LHT52 uplink payloads found in sample file")
	}
}
