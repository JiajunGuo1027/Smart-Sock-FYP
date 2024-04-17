/* The anklet can output the change value of pressure and bending through FSR and Flex Sensor. 
When the change exceeds the normal range, the red light will light and give an early warning. 
The detection is stopped when severe motion is detected and the blue light is on. 
The yellow light is on when Bluetooth is connected.*/

#include <Arduino.h>
#include <Wire.h>
#include <ArduinoBLE.h>
#include <Arduino_LSM6DS3.h> // Include the IMU library

// Define analog input pins for the sensors
const int fsrPin = A0; // FSR sensor connected to A0
const int flexPin = A1; // Flex sensor connected to A1
const int ledPin = 2; // Red LED connected to digital pin 2
const int blueLedPin = 3; // Blue LED connected to digital pin 3
const int yellowLedPin = 4; // Yellow LED connected to digital pin 4

// Variables to store initial values and changes
float fsrInitial = 0;
float flexInitial = 0;
float fsrChange = 0;
float flexChange = 0;

// Variables for calculating averages
float fsrSum = 0;
float flexSum = 0;
int readingsCount = 0;

// Filtered change variables
float filteredFsrChange = 0;
float filteredFlexChange = 0;

unsigned long lastMeasurementTime = 0; // Time of the last measurement
unsigned long lastOutputTime = 0; // Time of the last output
const long measurementInterval = 3000; // Measurement interval in milliseconds
const long outputInterval = 15000; // Output interval in milliseconds

// BLE service and characteristics
BLEService sensorService("1101"); // Custom service UUID
BLEFloatCharacteristic fsrCharacteristic("2101", BLERead | BLENotify); // FSR characteristic
BLEFloatCharacteristic flexCharacteristic("2102", BLERead | BLENotify); // Flex characteristic

void setup() {
  Serial.begin(9600); // Start serial communication
  pinMode(fsrPin, INPUT);
  pinMode(flexPin, INPUT);
  pinMode(ledPin, OUTPUT);// Set the three LED pins as output
  pinMode(blueLedPin, OUTPUT);
  pinMode(yellowLedPin, OUTPUT);
  delay(1000); // Wait for the serial connection to stabilize

  // Initialize IMU
if (!IMU.begin()) {
  Serial.println("Failed to initialize IMU!");
  while (1);
}

  // BLE setup
  if (!BLE.begin()) {
    Serial.println("Starting BLE failed!");
    while (1);
  }

  BLE.setLocalName("Ankle_Swelling_Monitor");
  BLE.setAdvertisedService(sensorService);
  sensorService.addCharacteristic(fsrCharacteristic);
  sensorService.addCharacteristic(flexCharacteristic);
  BLE.addService(sensorService);
  // Initialize the FSR and Flex characteristics with initial values
  fsrCharacteristic.writeValue(0.0);
  flexCharacteristic.writeValue(0.0);

  BLE.advertise();
  Serial.println("BLE device is ready and broadcasting");

  // Measure initial values
  for (int i = 0; i < 5; i++) {
    fsrSum += analogRead(fsrPin);
    flexSum += analogRead(flexPin);
    delay(1000); // Measure once per second
  }
  fsrInitial = fsrSum / 5; // Calculate average FSR initial value
  flexInitial = flexSum / 5; // Calculate average Flex initial value
  
  // Output initial values to the serial monitor
  Serial.print("FSR Initial Value: ");
  Serial.print(fsrInitial);
  Serial.print(", Flex Initial Value: ");
  Serial.println(flexInitial);

  lastMeasurementTime = millis();
  lastOutputTime = millis();
}

void loop() {
  unsigned long currentMillis = millis();

  if (BLE.connected()) {
    digitalWrite(yellowLedPin, HIGH); // Turn on the yellow LED when BLE is connected
} else {
    digitalWrite(yellowLedPin, LOW); // Turn off the yellow LED when BLE is not connected
}

  float ax, ay, az; // Variables to store accelerometer data
  IMU.readAcceleration(ax, ay, az); // Read acceleration data

  // Calculate the magnitude of acceleration
  float accelerationMagnitude = sqrt(ax * ax + ay * ay + az * az);

  // Define a threshold for violent movement detection
  const float movementThreshold = 2.0; 

  // Check if the magnitude of acceleration exceeds the threshold
  if (accelerationMagnitude > movementThreshold) {
    digitalWrite(blueLedPin, HIGH); // Turn on the blue LED
    Serial.println("Violent movement detected, stopping sensor checks.");
    // Do not process sensor data or update characteristics when movement is violent
    return; // Skip the rest of the loop
  } else {
    digitalWrite(blueLedPin, LOW); // Ensure the blue LED is off when there's no violent movement
  }
  // Measure sensor values every 3 seconds
  if (currentMillis - lastMeasurementTime >= measurementInterval) {
    lastMeasurementTime = currentMillis;
    fsrChange = analogRead(fsrPin) - fsrInitial;
    flexChange = analogRead(flexPin) - flexInitial;

    // Accumulate changes for averaging
    filteredFsrChange += fsrChange;
    filteredFlexChange += flexChange;
    readingsCount++;
  }
  
  // Output average changes every 15 seconds
  if (currentMillis - lastOutputTime >= outputInterval) {
    lastOutputTime = currentMillis;

    // Calculate average changes
    if (readingsCount > 0) { // Avoid division by zero
      filteredFsrChange /= readingsCount;
      filteredFlexChange /= readingsCount;

      // Update BLE characteristics
      fsrCharacteristic.writeValue(filteredFsrChange);
      flexCharacteristic.writeValue(filteredFlexChange);

      Serial.print("FSR Change: ");
      Serial.print(filteredFsrChange);
      Serial.print(", Flex Change: ");
      Serial.println(filteredFlexChange);

      // Check if changes exceed thresholds and issue warnings
      if (filteredFsrChange > 50) {
        Serial.println("Ankle swelling detected: FSR");
        digitalWrite(ledPin, HIGH); // Turn on the LED
      }
      if (filteredFlexChange < -1) {
        Serial.println("Ankle swelling detected: Flex");
        digitalWrite(ledPin, HIGH); // Turn on the LED
      }

      // If there are no warnings, turn off the LED
      if (filteredFsrChange <= 50 && filteredFlexChange >= -1) {
        digitalWrite(ledPin, LOW); // Turn off the LED
       }

      // Reset variables for the next 15-second cycle
      filteredFsrChange = 0;
      filteredFlexChange = 0;
      readingsCount = 0;
    }
  }
}
