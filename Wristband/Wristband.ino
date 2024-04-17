/* A bracelet that detects heart rate and blood oxygen and displays them on an OLED display, then transmits the data to a central device via Bluetooth. */

#include "DFRobot_BloodOxygen_S.h"
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <ArduinoBLE.h>

#define I2C_COMMUNICATION
#define SCREEN_WIDTH 128 // OLED display width, in pixels
#define SCREEN_HEIGHT 32 // OLED display height, in pixels
#define OLED_RESET    -1 // Reset pin # (or -1 if sharing Arduino reset pin)

Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);

#ifdef I2C_COMMUNICATION
#define I2C_ADDRESS    0x57
DFRobot_BloodOxygen_S_I2C MAX30102(&Wire, I2C_ADDRESS);
#else
#if defined(ARDUINO_AVR_UNO) || defined(ESP8266)
SoftwareSerial mySerial(4, 5);
DFRobot_BloodOxygen_S_SoftWareUart MAX30102(&mySerial, 9600);
#else
DFRobot_BloodOxygen_S_HardWareUart MAX30102(&Serial1, 9600); 
#endif
#endif

const int yellowLedPin = 4; // The yellow LED connected to digital pin 4

BLEService healthService("180D"); // Use the standard UUID for the heart rate service
BLECharacteristic heartRateCharacteristic("2A37", BLERead | BLENotify, 2); // Heart rate characteristic
// BLECharacteristic spo2Characteristic("2A38", BLERead | BLENotify, 2); // Spo2 characteristic
// Define the custom UUID for the SpO2 characteristic
const char* customSpo2CharacteristicUuid = "12345678-2002-1027-1234-123456789001";
// Change BLECharacteristic instantiation to use the custom UUID
BLECharacteristic spo2Characteristic(customSpo2CharacteristicUuid, BLERead | BLENotify, 2); // Use the custom UUID

void setup() {
  Serial.begin(115200);
  pinMode(yellowLedPin, OUTPUT);

  //BLE setup
  if (!BLE.begin()) {
    Serial.println("starting BLE failed!");
    while (1);
  }

  BLE.setLocalName("HeartRate_SPO2_Monitor");
  BLE.setAdvertisedService(healthService);
  healthService.addCharacteristic(heartRateCharacteristic);
  healthService.addCharacteristic(spo2Characteristic);
  BLE.addService(healthService);

  // Use an explicit uint8_t value of type 0 to initialize the feature
  uint8_t initValue = 0;
  heartRateCharacteristic.writeValue(&initValue, sizeof(initValue)); 
  spo2Characteristic.writeValue(&initValue, sizeof(initValue)); 

  BLE.advertise();
  
  Serial.println("Bluetooth device active, waiting for connections...");

  // Initialize MAX30102
  while (false == MAX30102.begin()) {
    Serial.println("init fail!");
    delay(1000);
  }
  Serial.println("init success!");
  Serial.println("start measuring...");
  MAX30102.sensorStartCollect();
  
  // Initialize OLED Display
  if(!display.begin(SSD1306_SWITCHCAPVCC, 0x3C)) { // Address 0x3C for 128x32
    Serial.println(F("SSD1306 allocation failed"));
    for(;;);
  }
  delay(2000);
  display.clearDisplay();
  display.setTextSize(1);      // Normal 1:1 pixel scale
  display.setTextColor(SSD1306_WHITE); // Draw white text
  display.setCursor(0,0);     // Start at top-left corner
}

void loop() {
 if (BLE.connected()) {
    digitalWrite(yellowLedPin, HIGH); // Turn on the yellow LED when BLE is connected
  } else {
    digitalWrite(yellowLedPin, LOW); // Turn off the yellow LED when BLE is not connected
  }

// Read and display heart rate and SpO2 values
  MAX30102.getHeartbeatSPO2();
  display.clearDisplay();
  display.setCursor(0,0);
  // Display the readings on OLED
  display.print("SPO2: ");
  display.print(MAX30102._sHeartbeatSPO2.SPO2);
  display.println("%");
  display.print("Heart Rate: ");
  display.print(MAX30102._sHeartbeatSPO2.Heartbeat);
  display.println(" bpm");
  display.display(); // Actually display all the above

  // Update the value of the BLE characteristic
  uint8_t hrVal[2] = {0, 0}; 
  hrVal[0] = MAX30102._sHeartbeatSPO2.Heartbeat; // Assume a heart rate between 0-255bpm
  heartRateCharacteristic.writeValue(hrVal, 2);

  uint8_t spo2Val[2] = {0, 0}; 
  spo2Val[0] = MAX30102._sHeartbeatSPO2.SPO2; // Assume SPO2 is between 0 and 100%
  spo2Characteristic.writeValue(spo2Val, 2);

  delay(15000); // Update every 15 seconds
}
