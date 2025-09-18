#include <M5Unified.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

#define SERVICE_UUID                 "c48e6067-5295-43d8-9c59-16616a5a300a"
#define DOOR_COUNT_CHAR_UUID         "a1e8f2de-570a-45b3-851f-365a6a364d1f"
#define BATTERY_LEVEL_CHAR_UUID      "2a19"
#define RESET_COUNTER_CHAR_UUID      "f0b1a051-a20c-43f1-b1e4-39f5c43a3d53"

const char* DEVICE_NAME = "FridgeMonitorM5";
int doorOpenCount = 0;

BLECharacteristic *pDoorCountCharacteristic;
BLECharacteristic *pBatteryLevelCharacteristic;
bool deviceConnected = false;
uint8_t batteryLevel = 0;
unsigned long lastBatteryCheck = 0;


float prevAccX = 0, prevAccY = 0, prevAccZ = 0;
float jerkThreshold = 0.5; // this is where you want to adjust your sensing thing
unsigned long lastJerkTime = 0; 
long cooldownPeriod = 2000;   

void updateDisplay() {
    M5.Display.fillScreen(TFT_BLACK);
    int centerX = 135 / 2;
    M5.Display.setTextColor(TFT_WHITE);
    M5.Display.setTextDatum(MC_DATUM);
    M5.Display.setFont(&fonts::Font2);
    M5.Display.drawString(deviceConnected ? "Connected" : "Searching...", centerX, 20);
    M5.Display.setFont(&fonts::Font7);
    M5.Display.drawString(String(doorOpenCount), centerX, 120);
    M5.Display.setFont(&fonts::Font4);
    M5.Display.drawString("Count", centerX, 190);
}

void resetCounter() {
    doorOpenCount = 0;
    if (deviceConnected) {
        pDoorCountCharacteristic->setValue(doorOpenCount);
        pDoorCountCharacteristic->notify();
    }
    updateDisplay();
}

class ResetCallback: public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *pCharacteristic) {
        String value = pCharacteristic->getValue().c_str();
        if (value == "1") {
            resetCounter();
        }
    }
};

class MyServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
        deviceConnected = true;
        updateDisplay();
    }
    void onDisconnect(BLEServer* pServer) {
        deviceConnected = false;
        updateDisplay();
        BLEDevice::startAdvertising();
    }
};

void setup() {
    auto cfg = M5.config();
    M5.begin(cfg);
    M5.Display.setRotation(0);
    M5.Power.begin();
    setCpuFrequencyMhz(80);
    M5.Imu.begin();
    updateDisplay();

    M5.Imu.getAccelData(&prevAccX, &prevAccY, &prevAccZ);

    BLEDevice::init(DEVICE_NAME);
    BLEServer *pServer = BLEDevice::createServer();
    pServer->setCallbacks(new MyServerCallbacks());
    BLEService *pService = pServer->createService(SERVICE_UUID);
    pDoorCountCharacteristic = pService->createCharacteristic(DOOR_COUNT_CHAR_UUID, BLECharacteristic::PROPERTY_NOTIFY | BLECharacteristic::PROPERTY_READ);
    pDoorCountCharacteristic->addDescriptor(new BLE2902());
    pDoorCountCharacteristic->setValue(doorOpenCount);
    pBatteryLevelCharacteristic = pService->createCharacteristic(BATTERY_LEVEL_CHAR_UUID, BLECharacteristic::PROPERTY_NOTIFY | BLECharacteristic::PROPERTY_READ);
    pBatteryLevelCharacteristic->addDescriptor(new BLE2902());
    BLECharacteristic *pResetCharacteristic = pService->createCharacteristic(RESET_COUNTER_CHAR_UUID, BLECharacteristic::PROPERTY_WRITE);
    pResetCharacteristic->setCallbacks(new ResetCallback());
    pService->start();
    BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
    pAdvertising->addServiceUUID(SERVICE_UUID);
    pAdvertising->setScanResponse(true);
    BLEDevice::startAdvertising();
}

void loop() {
    M5.update();

    if (M5.BtnA.wasPressed()) {
        resetCounter();
    }

    if (millis() - lastBatteryCheck > 5000) {
        batteryLevel = M5.Power.getBatteryLevel();
        if (deviceConnected) {
            pBatteryLevelCharacteristic->setValue(&batteryLevel, 1);
            pBatteryLevelCharacteristic->notify();
        }
        lastBatteryCheck = millis();
    }

    float accX, accY, accZ;
    M5.Imu.getAccelData(&accX, &accY, &accZ);
    
    float jerkX = accX - prevAccX;
    float jerkY = accY - prevAccY;
    float jerkZ = accZ - prevAccZ;
    float totalJerk = sqrt(jerkX*jerkX + jerkY*jerkY + jerkZ*jerkZ);
    
    if (totalJerk > jerkThreshold && millis() - lastJerkTime > cooldownPeriod) {
        doorOpenCount++;
        lastJerkTime = millis(); 
        
        if (deviceConnected) {
            pDoorCountCharacteristic->setValue(doorOpenCount);
            pDoorCountCharacteristic->notify();
        }
        updateDisplay();
    }
    

    prevAccX = accX;
    prevAccY = accY; 
    prevAccZ = accZ;
    
    delay(50); 
}