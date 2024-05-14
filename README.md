# Smart-Sock-FYP
Launched in partnership with Aintree Hospital to improve monitoring of patients with heart failure, the Smart Sock Project is a multi-functional health monitoring system that detects ankle oedema, heart rate and blood oxygen and includes an anklet, wristband and smart sock APP.

## File Description

- **DesignResult** - This file concisely summarizes the project's design philosophy, experimental methods, and the final results of the device operation.
- **fsrFlexTest** - Test code used to check if the anklet circuit is functioning properly.
- **Anklet** - Anklet code that detects swelling of the ankle through sensor changes and issues a warning when changes exceed normal ranges.
- **Wristband** - Wristband code that can monitor heart rate and blood oxygen levels, and displays current rates on a screen.
- **Smart Sock APP**
  - **Overview**: Due to Xcode's native Git integration, the "Smart Sock APP" folder has its own .git directory, hence the files of the application are added as a submodule to the main project. This application includes three core files:
    - **ContentView.swift** - Responsible for defining and managing the application's user interface, containing all elements of user interaction.
    - **BluetoothManager.swift** - Manages interaction with Bluetooth hardware, including searching for devices, connecting to devices, and handling data from devices.
    - **Smart_Sock.xcdatamodeld** - Core Data's data model file, defines the model used by the application to store data.
  - Other files such as system files, test files, etc., are all located within the "Smart Sock APP" project.

## Video presentation

[click here to watch the Anklet Test video] (https://youtu.be/gibniL41s3s)
[click here to watch the Smart Sock Test video] (https://youtu.be/yrWCAZGC_oE)
