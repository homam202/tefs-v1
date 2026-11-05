// ESP32 + RM3100 (I2C) -> BLE Nordic UART, line format: "x,y,z\n" in nT (integers)
// Wiring: SDA=21, SCL=22, 3V3, GND. Set RM3100 address pins -> I2C addr 0x20 (change below if different).
#include <Wire.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLE2902.h>

#define RM_ADDR 0x20
#define REG_CMM 0x01
#define REG_CCX 0x04
#define REG_TMRC 0x0B
#define REG_MX 0x24
#define REG_STATUS 0x34
#define CYCLES 200            // gain ~75 counts/uT at 200 cycles
const float COUNTS_PER_UT = 75.0;

#define UART_SVC "6e400001-b5a0-f393-e0a9-e50e24dcca9e"
#define UART_TX  "6e400003-b5a0-f393-e0a9-e50e24dcca9e"

BLECharacteristic *tx;
bool connected = false;

class CB : public BLEServerCallbacks {
  void onConnect(BLEServer*) { connected = true; }
  void onDisconnect(BLEServer *s) { connected = false; s->getAdvertising()->start(); }
};

void wr(uint8_t reg, uint8_t v) { Wire.beginTransmission(RM_ADDR); Wire.write(reg); Wire.write(v); Wire.endTransmission(); }

void rmInit() {
  for (uint8_t i = 0; i < 3; i++) {            // cycle count per axis
    Wire.beginTransmission(RM_ADDR); Wire.write(REG_CCX + i * 2);
    Wire.write(CYCLES >> 8); Wire.write(CYCLES & 0xFF); Wire.endTransmission();
  }
  wr(REG_TMRC, 0x96);                          // ~37 Hz continuous rate
  wr(REG_CMM, 0x79);                           // continuous mode, X/Y/Z
}

bool rmRead(float &x, float &y, float &z) {
  Wire.beginTransmission(RM_ADDR); Wire.write(REG_STATUS); Wire.endTransmission(false);
  Wire.requestFrom(RM_ADDR, 1);
  if (!Wire.available() || !(Wire.read() & 0x80)) return false;   // data not ready
  Wire.beginTransmission(RM_ADDR); Wire.write(REG_MX); Wire.endTransmission(false);
  Wire.requestFrom(RM_ADDR, 9);
  if (Wire.available() < 9) return false;
  int32_t v[3];
  for (int i = 0; i < 3; i++) {
    int32_t a = Wire.read(), b = Wire.read(), c = Wire.read();
    v[i] = (a << 16) | (b << 8) | c;
    if (v[i] & 0x800000) v[i] |= 0xFF000000;   // sign-extend 24-bit
  }
  x = v[0] / COUNTS_PER_UT * 1000.0; y = v[1] / COUNTS_PER_UT * 1000.0; z = v[2] / COUNTS_PER_UT * 1000.0;
  return true;
}

void sendLine(const String &s) {                // chunk to 20 bytes (default MTU safe)
  for (size_t i = 0; i < s.length(); i += 20) {
    tx->setValue((uint8_t*)s.substring(i, i + 20).c_str(), min((size_t)20, s.length() - i));
    tx->notify(); delay(5);
  }
}

void setup() {
  Serial.begin(115200);
  Wire.begin(21, 22); Wire.setClock(400000);
  rmInit();
  BLEDevice::init("MAG-RM3100");
  BLEServer *srv = BLEDevice::createServer(); srv->setCallbacks(new CB());
  BLEService *svc = srv->createService(UART_SVC);
  tx = svc->createCharacteristic(UART_TX, BLECharacteristic::PROPERTY_NOTIFY);
  tx->addDescriptor(new BLE2902());
  svc->start();
  srv->getAdvertising()->addServiceUUID(UART_SVC);
  srv->getAdvertising()->start();
}

void loop() {
  static uint32_t t = 0;
  float x, y, z;
  if (millis() - t >= 100 && rmRead(x, y, z)) {  // 10 Hz to the phone
    t = millis();
    String s = String((long)x) + "," + String((long)y) + "," + String((long)z) + "\n";
    Serial.print(s);
    if (connected) sendLine(s);
  }
}
