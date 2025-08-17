package sensors

import (
	"bytes"
	"encoding/base64"
	"encoding/binary"
	"time"
)

const (
	LHT52_Sensor_Unknown = iota
	LHT52_Sensor_Reset
	LHT52_Sensor_TempReading
)

type LHT52SensorReading struct {
	EventType      int
	TempCelsius    float64
	TempFahrenheit float64
	Humidity       float64
	Timestamp      time.Time
}

// NewLHT52SensorReading creates a structure from the base64 encoded
// string payload passed in, returning an error for any decoding issues
// incurred, or returning the struct with unpacked fields.
//
// Sensor decoding logic inferred from example code located at:
// https://github.com/dragino/dragino-end-node-decoder/blob/main/LHT52/LHT52%20Decoder%20TTN.txt
func NewLHT52SensorReading(payload string) (*LHT52SensorReading, error) {
	// Decode the payload
	raw, err := base64.StdEncoding.DecodeString(payload)
	if err != nil {
		return nil, err
	}
	if len(raw) != 11 {
		return &LHT52SensorReading{
			EventType: LHT52_Sensor_Reset,
		}, nil
	}
	var data int16
	result := &LHT52SensorReading{
		EventType: LHT52_Sensor_TempReading,
	}
	err = binary.Read(bytes.NewBuffer(raw[0:2]), binary.BigEndian, &data)
	if err != nil {
		return nil, err
	}
	result.TempCelsius = float64(data) / 100
	result.TempFahrenheit = result.TempCelsius*9/5 + 32
	err = binary.Read(bytes.NewBuffer(raw[2:4]), binary.BigEndian, &data)
	if err != nil {
		return nil, err
	}
	result.Humidity = float64(data) / 10
	var unixTime int32
	err = binary.Read(bytes.NewBuffer(raw[7:11]), binary.BigEndian, &unixTime)
	if err != nil {
		return nil, err
	}
	result.Timestamp = time.Unix(int64(unixTime), 0)

	return result, nil
}
