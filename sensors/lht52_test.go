package sensors

import (
	"testing"
	"time"
)

func TestLHT52EmptyPayloadDecoding(t *testing.T) {
	payload := ""
	packet, err := NewLHT52SensorReading(payload)
	if err != nil {
		t.Fatal(err)
	}
	if packet.EventType != LHT52_Sensor_Reset {
		t.Fatal("EventType should be LHT52_Sensor_Reset")
	}
}

func TestLHT52InvalidPayloadDecoding(t *testing.T) {
	payload := "invalid"
	_, err := NewLHT52SensorReading(payload)
	if err == nil {
		t.Fatal("Error should be returned")
	}
}

func TestLHT52PayloadDecoding(t *testing.T) {
	payload := "+GMCqn//AWh6dYY="
	packet, err := NewLHT52SensorReading(payload)
	if err != nil {
		t.Fatal(err)
	}
	if packet.EventType != LHT52_Sensor_TempReading {
		t.Fatal("Wrong event type")
	}
	if packet.TempCelsius != -19.49 {
		t.Fatal("Expected -19.49 got ", packet.TempCelsius)
	}
	if packet.Humidity != 68.2 {
		t.Fatal("Expected 68.2 got ", packet.Humidity)
	}
	if packet.Timestamp != time.Unix(1752855942, 0) {
		t.Fatal("Invalid timestamp")
	}
	if packet.TempFahrenheit != -3.0820000000000007 {
		t.Fatal("Expected -3.082 got ", packet.TempFahrenheit)
	}
}
