package sensors

import (
	"bytes"
	"encoding/base64"
	"encoding/binary"
	"fmt"
)

const (
	LWL02_Water_Leak_Unknown = iota
	LWL02_Water_Leak_Detected
	LWL02_Water_Leak_Cleared
)

type LWL02SensorReading struct {
	BatteryVoltage  float64
	WaterLeakStatus int
}

// NewLWL02SensorReading unpacks a sensor reading from a string payload
// per the structure defined here:
//
//	https://wiki.dragino.com/xwiki/bin/view/Main/User%20Manual%20for%20LoRaWAN%20End%20Nodes/LWL02%20-%20LoRaWAN%20Door%20Sensor%20User%20Manual/#H4.3UplinkPayload
//
// The payload format is:
// ┌─────────────┬──────────────┬──────────────────┬─────────────────────────┬──────────────┐
// │ Size(bytes) │       2      │         1        │             3           │      1       │
// ├─────────────┼──────────────┼──────────────────┼─────────────────────────┼──────────────┤
// │    value    │ Status & BAT │ MOD Always: 0x02 │ Total water leak events │ Alarm status │
// └─────────────┴──────────────┴──────────────────┴─────────────────────────┴──────────────┘
func NewLWL02SensorReading(payload string) (*LWL02SensorReading, error) {
	// Decode the payload
	raw, err := base64.StdEncoding.DecodeString(payload)
	if err != nil {
		return nil, err
	}
	if len(raw) < 7 {
		return nil, fmt.Errorf("LWL02SensorReading: invalid payload length %d", len(raw))
	}
	source := bytes.NewReader(raw)
	result := &LWL02SensorReading{}
	var status int16
	err = binary.Read(source, binary.BigEndian, &status)
	if err != nil {
		return nil, err
	}
	result.BatteryVoltage = float64(status&0x3FFF) / 1000
	var model byte
	err = binary.Read(source, binary.BigEndian, &model)
	if model != 0x02 {
		return nil, fmt.Errorf("LWL02SensorReading: invalid model %d", model)
	}
	return result, nil
}
