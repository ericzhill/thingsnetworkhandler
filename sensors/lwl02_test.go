package sensors

import "testing"

/*
   "frm_payload": "TGwCAAALAAAiAA==",
   "decoded_payload": {
     "BAT_V": 3.18,
     "LAST_WATER_LEAK_DURATION": 34,
     "MOD": 2,
     "WATER_LEAK_STATUS": 1,
     "WATER_LEAK_TIMES": 11
   },

*/

func TestLWL02PayloadDecoding(t *testing.T) {
	payload := "TGwCAAALAAAiAA=="
	reading, err := NewLWL02SensorReading(payload)
	if err != nil {
		t.Fatal(err)
	}
	if reading.BatteryVoltage != 3.18 {
		t.Fatal("Expected 3.18, got ", reading.BatteryVoltage)
	}
}
