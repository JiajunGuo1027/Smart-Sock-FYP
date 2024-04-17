/* FSR and Flex sensor test code */
// Define the analog pins that connect to the Arduino
const int pinFSR = A0;  // The FSR is connected to A0 via an amplifier
const int pinFlex = A1; // The Flex Sensor is connected to the A1 via an amplifier

// The variable used to store the initial reading
int initialFSRValue;
int initialFlexValue;

bool initialRead = false; // Indicates whether the initial value has been read

void setup() {
  // Initializing serial communication
  Serial.begin(9600);
  // Read the initial sensor value
  initialFSRValue = analogRead(pinFSR);
  initialFlexValue = analogRead(pinFlex);
  initialRead = true; // Mark initial value read
}

void loop() {
  if (initialRead) {
    // Read the current FSR and Flex Sensor simulation values
    int currentFSRValue = analogRead(pinFSR);
    int currentFlexValue = analogRead(pinFlex);

    // Calculate the difference from the initial value
    int changeInFSR = currentFSRValue - initialFSRValue;
    int changeInFlex = currentFlexValue - initialFlexValue;

    // Print results to serial monitor
    Serial.print("FSR value: ");
    Serial.print(currentFSRValue);
    Serial.print(", Flex Sensor value: ");
    Serial.println(currentFlexValue);
    Serial.print("Change in FSR value: ");
    Serial.print(changeInFSR);
    Serial.print(", Change in Flex Sensor value: ");
    Serial.println(changeInFlex);
  } else {
    // If the initial value has not been read, read it again
    initialFSRValue = analogRead(pinFSR);
    initialFlexValue = analogRead(pinFlex);
    initialRead = true; // Mark initial value read
  }

  // Wait some time to read again
  delay(5000);
}