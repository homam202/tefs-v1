// ============================================================================
// Magnetic gradiometer v5
// ESP32 (BLE) + 2x RM3100 + GC9A01 round TFT + piezo buzzer + battery monitor
// No GPS / SD / IMU / WiFi by design.
// ============================================================================
// WIRING
//   I2C (RM3100 A=0x20, B=0x21)  SDA=GPIO21  SCL=GPIO22  (4.7k pull-ups to the sensor 3.3 V)
//   GC9A01   CS=15  DC=2  RST=4  SCL(SCK)=18  SDA(MOSI)=23  VCC/BLK=3V3
//   NAV button  GPIO32 -> GND      TRIG button GPIO33 -> GND
//   Piezo buzzer (passive, non-magnetic)  GPIO25 -> 100 ohm -> piezo -> GND
//   Battery: VBAT -> 100k -> GPIO34 -> 100k -> GND, plus 100 nF from GPIO34 to GND
//
// BUTTONS
//   Live screen:  NAV short = zero here        NAV long (0.9 s) = open menu
//                 TRIG short = take a point     TRIG long = cycle scan mode MANUAL/AUTO/LIVE
//   Menu (4 items): NAV short = next item,  TRIG short = select
//
// SCAN MODES
//   MANUAL : point on TRIG press (default)
//   AUTO   : a point every AUTO_MS (TRIG takes one immediately)
//   LIVE   : continuous on-screen reading only (nothing is sent to the app)
//
// BLE (for the RM3100 Grid Scanner app): Nordic UART service, TX notifications.
//   The device STREAMS "x,y,z
" lines at 10 Hz. The app takes hypot(x,y,z) and subtracts its own
//   baseline, so the gradient g (signed nT) is sent as x = 50000 + g, y = 0, z = 0.
//   The app records grid cells itself (its own record button / auto timer); TRIG here only
//   takes a point for the on-screen display.
//
// Libraries: Adafruit GFX, Adafruit GC9A01A.  Board: ESP32 (not S3/C3).
// Tools > Partition Scheme > "Huge APP (3MB No OTA)".
// NOTE: untested on hardware. Verify I2C addresses, registers and gain in the RM3100 datasheet.
// ============================================================================

#include <Wire.h>
#include <SPI.h>
#include <Preferences.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLE2902.h>
#include <Adafruit_GFX.h>
#include <Adafruit_GC9A01A.h>
#include <algorithm>
#include <limits.h>

// ---------- Pins ----------
#define PIN_NAV   32
#define PIN_TRIG  33
#define PIN_BUZZ  25
#define PIN_VBAT  34
#define TFT_CS    15
#define TFT_DC    2
#define TFT_RST   4

// ---------- Sensors ----------
#define ADDR_A 0x20                                   // lower sensor
#define ADDR_B 0x21                                   // upper sensor
const uint16_t CC = 400;                              // cycle count
const float NT_PER_LSB = 1000.0f / (0.375f * CC);     // ~75 LSB/uT at CC=200, linear in CC (check datasheet)
const int OVER_POINT = 4;                             // reads averaged per sample (MANUAL/AUTO)
const int OVER_LIVE  = 2;                             // (LIVE)

// ---------- Behaviour ----------
const uint32_t SAMPLE_MS = 2000;                      // averaging time for one point
const uint32_t AUTO_MS   = 5000;                      // AUTO mode interval
const float TILT_LIMIT_NT = 1500.0f;                  // ~3 degrees at ~30 uT; tune in the field
const int BT_CENTER = 512, BT_HALF = 511;

// ---------- Sensitivity presets (3 levels) ----------
struct Sens { float deadband, fullScale, alpha; const char *name; };
const Sens SENS[3] = {
  {30.0f, 800.0f, 0.15f, "LOW"},
  {15.0f, 300.0f, 0.25f, "MED"},
  { 6.0f, 100.0f, 0.40f, "HIGH"}
};
uint8_t sensIdx = 1;

enum MeasMode { M_TOTAL, M_Z };
MeasMode measMode = M_TOTAL;
const char *MEAS_NAMES[] = {"TOTAL", "Z"};

enum ScanMode { SCAN_MANUAL, SCAN_AUTO, SCAN_LIVE };
ScanMode scanMode = SCAN_MANUAL;
const char *SCAN_NAMES[] = {"MANUAL", "AUTO", "LIVE"};

#define UART_SVC "6e400001-b5a0-f393-e0a9-e50e24dcca9e"
#define UART_TX  "6e400003-b5a0-f393-e0a9-e50e24dcca9e"
const long APP_BIAS = 50000;               // nT offset so the app's magnitude keeps the sign of g
BLECharacteristic *bleTx = nullptr;
bool bleConnected = false;
uint32_t lastTx = 0;

class SrvCB : public BLEServerCallbacks {
  void onConnect(BLEServer *) { bleConnected = true; }
  void onDisconnect(BLEServer *s) { bleConnected = false; s->getAdvertising()->start(); }
};

void bleInit() {
  BLEDevice::init("GRAD-RM3100");
  BLEServer *srv = BLEDevice::createServer();
  srv->setCallbacks(new SrvCB());
  BLEService *svc = srv->createService(UART_SVC);
  bleTx = svc->createCharacteristic(UART_TX, BLECharacteristic::PROPERTY_NOTIFY);
  bleTx->addDescriptor(new BLE2902());
  svc->start();
  srv->getAdvertising()->addServiceUUID(UART_SVC);
  srv->getAdvertising()->start();
}

void bleSend(float g) {
  long x = APP_BIAS + lroundf(constrain(g, -40000.0f, 40000.0f));
  char b[24];
  int n = snprintf(b, sizeof(b), "%ld,0,0\n", x);   // fits one 20-byte notification
  bleTx->setValue((uint8_t *)b, n);
  bleTx->notify();
}
Preferences prefs;
Adafruit_GC9A01A tft(TFT_CS, TFT_DC, TFT_RST);

// ---------- Calibration data (saved in NVS, namespace "grad") ----------
struct Cal { float off[3]; float sc[3]; };
struct CalData {
  uint32_t magic;
  Cal a, b;
  float refA[3], refB[3];     // vertical reference (calibrated frame)
  int8_t zSign;               // +1 if sensor Z points down (field points into +Z)
};
const uint32_t CAL_MAGIC = 0x47524431;   // "GRD1"
CalData cd;
bool calValid = false;

// ---------- Runtime ----------
enum State { S_LIVE, S_SAMPLING, S_MENU };
State state = S_LIVE;
float baseline = 0, emaVal = 0, curVal = 0, tiltVal = 0;
bool emaInit = false, autoZeroPending = true;
int sinceReset = 0;
uint32_t nextAuto = 0, sampStart = 0, holdUntil = 0, flashUntil = 0, lastTick = 0, lastBat = 0;
double sumS = 0;
int sn = 0;
float holdVal = 0, maxTilt = 0;
char flashBuf[20] = "";
int menuSel = 0;
int batPct = 100;

struct Med5 {
  float b[5] = {0, 0, 0, 0, 0};
  int i = 0, n = 0;
  float push(float x) {
    b[i] = x; i = (i + 1) % 5; if (n < 5) n++;
    float s[5];
    for (int k = 0; k < 5; k++) s[k] = b[k];
    std::sort(s, s + 5);
    return (n < 5) ? x : s[2];
  }
} med;

// ---------- Buttons ----------
enum Ev { EV_NONE, EV_SHORT, EV_LONG };
struct Btn {
  uint8_t pin; uint16_t longMs; bool down = false, longFired = false; uint32_t t0 = 0;
  Btn(uint8_t p, uint16_t l) : pin(p), longMs(l) {}
  Ev update() {
    bool p = digitalRead(pin) == LOW;
    uint32_t now = millis();
    if (p && !down) { down = true; t0 = now; longFired = false; return EV_NONE; }
    if (p && down && !longFired && now - t0 >= longMs) { longFired = true; return EV_LONG; }
    if (!p && down) { down = false; if (!longFired && now - t0 >= 30) return EV_SHORT; }
    return EV_NONE;
  }
};
Btn btnNav(PIN_NAV, 900), btnTrig(PIN_TRIG, 900);

// ============================================================================
// BUZZER (non-blocking, piezo on LEDC)
// ============================================================================
#if defined(ESP_ARDUINO_VERSION_MAJOR) && ESP_ARDUINO_VERSION_MAJOR >= 3
  void buzzInit() { ledcAttach(PIN_BUZZ, 2000, 8); }
  void buzzWrite(int f) { ledcWriteTone(PIN_BUZZ, f); }
#else
  void buzzInit() { ledcSetup(0, 2000, 8); ledcAttachPin(PIN_BUZZ, 0); }
  void buzzWrite(int f) { ledcWriteTone(0, f); }
#endif

struct Seg { uint16_t f, ms; };
const int QN = 12;
Seg bq[QN];
int qHead = 0, qCount = 0, curFreq = -1;
bool segRun = false;
uint32_t segEnd = 0;
bool tiltTone = false;

void buzzPush(uint16_t f, uint16_t ms) {
  if (qCount < QN) { bq[(qHead + qCount) % QN] = {f, ms}; qCount++; }
}
void setFreq(int f) { if (f != curFreq) { buzzWrite(f); curFreq = f; } }
void buzzUpdate() {
  uint32_t now = millis();
  if (segRun && (int32_t)(now - segEnd) >= 0) segRun = false;
  if (!segRun && qCount > 0) {
    Seg s = bq[qHead]; qHead = (qHead + 1) % QN; qCount--;
    setFreq(s.f); segEnd = now + s.ms; segRun = true;
  }
  if (!segRun) setFreq(tiltTone ? 300 : 0);
}
void beepStartup()  { buzzPush(880, 300); buzzPush(0, 120); buzzPush(880, 300); }
void beepSampleStart() { buzzPush(1200, 80); }
void beepTick()     { buzzPush(500, 30); }
void beepDone()     { buzzPush(1500, 70); buzzPush(0, 50); buzzPush(1500, 70); }
void beepReject()   { buzzPush(300, 400); }

// ============================================================================
// DISPLAY (GC9A01 240x240, partial redraws to avoid flicker)
// ============================================================================
#define C_BLACK  0x0000
#define C_WHITE  0xFFFF
#define C_YELLOW 0xFFE0
#define C_GREEN  0x07E0
#define C_RED    0xF800
#define C_ORANGE 0xFD20
#define C_REDT   0xF9E7
#define C_BLUET  0x547F
#define C_GRAYT  0xB5B6
#define C_SEL    0x01F4

const int CY = 124, DR = 76;          // disc centre y and radius
const int RING_N = 48;
int cIv = INT_MIN, cBatKey = -1, cTiltQ = -1, ringDrawn = 0;
uint16_t cCol = 0, cLc = 0;
int cBt = -1;
char cH1[20] = "", cH2[20] = "", cLabel[20] = "";

void drawCentered(const char *s, int cx, int y, uint8_t size, uint16_t fg, uint16_t bg, int clearW) {
  tft.setTextSize(size);
  int16_t x1, y1; uint16_t w, h;
  tft.getTextBounds(s, 0, 0, &x1, &y1, &w, &h);
  tft.fillRect(cx - clearW / 2, y, clearW, h + 2, bg);
  tft.setTextColor(fg);
  tft.setCursor(cx - (int)w / 2, y);
  tft.print(s);
}

uint16_t levelColor(int iv, float fs) {
  float t = sqrtf(fminf(1.0f, fabsf((float)iv) / fs));
  int r0 = 50, g0 = 50, b0 = 50, r1, g1, b1;
  if (iv >= 0) { r1 = 255; g1 = 30; b1 = 30; }      // red = metal
  else         { r1 = 30; g1 = 110; b1 = 255; }     // blue = opposite
  return tft.color565((uint8_t)(r0 + (r1 - r0) * t), (uint8_t)(g0 + (g1 - g0) * t), (uint8_t)(b0 + (b1 - b0) * t));
}

void ringDot(int i, uint16_t col) {
  float ang = -PI / 2 + 2 * PI * i / RING_N;
  tft.fillCircle(120 + (int)(113 * cosf(ang)), 120 + (int)(113 * sinf(ang)), 3, col);
}
void clearRing() { for (int i = 0; i < RING_N; i++) ringDot(i, C_BLACK); ringDrawn = 0; }

void dInit() { tft.begin(); tft.setRotation(0); tft.fillScreen(C_BLACK); }
void dSplash() { tft.fillScreen(C_BLACK); drawCentered("GRADIOMETER", 120, 105, 2, C_WHITE, C_BLACK, 200); }

void dForce() {
  tft.fillScreen(C_BLACK);
  cIv = INT_MIN; cBatKey = -1; cTiltQ = -1; cBt = -1; ringDrawn = 0; cCol = 0; cLc = 0;
  cH1[0] = cH2[0] = cLabel[0] = 0;
}

void drawBattery(int pct, uint16_t bg) {
  uint16_t c = pct > 50 ? C_GREEN : (pct >= 20 ? C_YELLOW : C_RED);
  tft.fillRect(120, 54, 28, 13, bg);
  tft.drawRect(122, 55, 22, 11, C_WHITE);
  tft.fillRect(144, 58, 3, 5, C_WHITE);
  tft.fillRect(124, 57, (pct * 18) / 100, 7, c);
}

void drawTilt(float frac) {
  uint16_t c = frac < 0.5f ? C_GREEN : (frac < 1.0f ? C_YELLOW : C_RED);
  tft.fillRect(88, 229, 64, 6, C_BLACK);
  tft.drawRect(88, 229, 64, 6, C_GRAYT);
  tft.fillRect(89, 230, (int)(62 * fminf(1.0f, frac)), 4, c);
}

// kind: 0 clear, 1 metal, 2 opposite, 3 info, 4 tilt
void dLive(int iv, const char *h1, const char *h2, const char *label, int kind,
           bool bt, int pct, float tiltFrac, float sampFrac, float fs) {
  uint16_t col = levelColor(iv, fs);
  uint16_t lc = (kind == 1) ? C_REDT : (kind == 2) ? C_BLUET : (kind == 0) ? C_GRAYT : (kind == 4) ? C_ORANGE : C_WHITE;

  if (iv != cIv || col != cCol) {
    tft.fillCircle(120, CY, DR, col);
    tft.drawCircle(120, CY, DR + 2, C_WHITE);
    char b[12]; snprintf(b, sizeof(b), "%+d", iv);
    drawCentered(b, 120, 100, 5, C_WHITE, col, 130);
    drawCentered("nT", 120, 144, 2, C_WHITE, col, 40);
    cIv = iv; cCol = col;
    cBt = -1; cBatKey = -1;          // icons sit on the disc: redraw them
  }
  if ((int)bt != cBt) {
    tft.fillCircle(100, 60, 6, bt ? C_GREEN : cCol);
    tft.drawCircle(100, 60, 6, C_WHITE);
    cBt = (int)bt;
  }
  int bk = pct / 5;
  if (bk != cBatKey) { drawBattery(pct, cCol); cBatKey = bk; }

  int tq = (int)(fminf(1.0f, tiltFrac) * 20);
  if (tq != cTiltQ) { drawTilt(tiltFrac); cTiltQ = tq; }

  if (strcmp(h1, cH1) != 0) { drawCentered(h1, 120, 8, 1, C_GRAYT, C_BLACK, 100); strncpy(cH1, h1, sizeof(cH1) - 1); }
  if (strcmp(h2, cH2) != 0) { drawCentered(h2, 120, 20, 2, C_WHITE, C_BLACK, 130); strncpy(cH2, h2, sizeof(cH2) - 1); }
  if (strcmp(label, cLabel) != 0 || lc != cLc) {
    drawCentered(label, 120, 206, 2, lc, C_BLACK, 126);
    strncpy(cLabel, label, sizeof(cLabel) - 1); cLabel[sizeof(cLabel) - 1] = 0; cLc = lc;
  }
  if (sampFrac >= 0) {
    int target = min(RING_N, (int)(sampFrac * RING_N));
    while (ringDrawn < target) { ringDot(ringDrawn, C_YELLOW); ringDrawn++; }
  } else if (ringDrawn > 0) {
    clearRing();
  }
}

const int MENU_N = 4;
void itemText(int i, char *b, size_t n) {
  switch (i) {
    case 0: snprintf(b, n, "Calibrate"); break;
    case 1: snprintf(b, n, "Mode: %s", MEAS_NAMES[measMode]); break;
    case 2: snprintf(b, n, "Sens: %s", SENS[sensIdx].name); break;
    default: snprintf(b, n, "Back");
  }
}

void dMenu(int sel) {
  tft.fillScreen(C_BLACK);
  drawCentered("MENU", 120, 26, 2, C_YELLOW, C_BLACK, 100);
  for (int i = 0; i < MENU_N; i++) {
    int y = 62 + i * 32;
    bool s = (i == sel);
    if (s) tft.fillRoundRect(34, y - 5, 172, 26, 6, C_SEL);
    char b[24]; itemText(i, b, sizeof(b));
    drawCentered(b, 120, y, 2, C_WHITE, s ? C_SEL : C_BLACK, 160);
  }
  drawCentered("NAV: next   TRIG: OK", 120, 204, 1, C_GRAYT, C_BLACK, 150);
}

void dMsg(const char *l1, const char *l2, const char *big) {
  tft.fillScreen(C_BLACK);
  if (l1) drawCentered(l1, 120, 60, 2, C_YELLOW, C_BLACK, 220);
  if (l2) drawCentered(l2, 120, 90, 2, C_WHITE, C_BLACK, 236);
  if (big) drawCentered(big, 120, 130, 4, C_WHITE, C_BLACK, 160);
}

// ============================================================================
// SENSORS
// ============================================================================
void wr(uint8_t a, uint8_t reg, uint8_t v) {
  Wire.beginTransmission(a);
  Wire.write(reg);
  Wire.write(v);
  Wire.endTransmission();
}

void initSensor(uint8_t a) {
  const uint8_t regs[3] = {0x04, 0x06, 0x08};
  for (int i = 0; i < 3; i++) {
    wr(a, regs[i], CC >> 8);
    wr(a, regs[i] + 1, CC & 0xFF);
  }
}

bool readRaw(uint8_t a, float v[3]) {
  wr(a, 0x00, 0x70);                                      // single measurement, X Y Z
  uint32_t t0 = millis();
  while (true) {
    Wire.beginTransmission(a);
    Wire.write(0x34);                                     // STATUS
    Wire.endTransmission();
    if (Wire.requestFrom(a, (uint8_t)1) == 1 && (Wire.read() & 0x80)) break;   // DRDY
    if (millis() - t0 > 100) return false;
  }
  Wire.beginTransmission(a);
  Wire.write(0xA4);                                       // first data register
  Wire.endTransmission();
  if (Wire.requestFrom(a, (uint8_t)9) != 9) return false;
  for (int i = 0; i < 3; i++) {
    uint8_t b0 = Wire.read();
    uint8_t b1 = Wire.read();
    uint8_t b2 = Wire.read();
    int32_t r = ((int32_t)b0 << 16) | ((int32_t)b1 << 8) | b2;
    if (r & 0x800000) r |= 0xFF000000;                    // sign-extend 24 bit
    v[i] = r * NT_PER_LSB;
  }
  return true;
}

// Calibrated vector (nT), averaged over "over" reads
bool readVec(uint8_t a, const Cal &c, float out[3], int over) {
  float sum[3] = {0, 0, 0};
  int ok = 0;
  for (int k = 0; k < over; k++) {
    float v[3];
    if (readRaw(a, v)) { for (int i = 0; i < 3; i++) sum[i] += v[i]; ok++; }
  }
  if (ok < max(1, over / 2)) return false;
  for (int i = 0; i < 3; i++) out[i] = (sum[i] / ok - c.off[i]) * c.sc[i];
  return true;
}

float norm3(const float v[3]) { return sqrtf(v[0] * v[0] + v[1] * v[1] + v[2] * v[2]); }

// Z with first-order XY correction using the stored vertical reference
float zCorr(const float v[3], const float r[3]) {
  float dX = v[0] - r[0], dY = v[1] - r[1];
  return v[2] + (r[0] * dX + r[1] * dY) / r[2];
}

// Tilt quality (nT): change of vertical component and horizontal magnitude vs the reference.
// Both are independent of rotation about the vertical axis. Evaluated on the upper sensor B.
float tiltMetric(const float b[3], const float r[3]) {
  float h = sqrtf(b[0] * b[0] + b[1] * b[1]);
  float hr = sqrtf(r[0] * r[0] + r[1] * r[1]);
  float dz = b[2] - r[2], dh = h - hr;
  return sqrtf(dz * dz + dh * dh);
}

bool readGradient(int over, float &g, float &tilt) {
  float a[3], b[3];
  if (!readVec(ADDR_A, cd.a, a, over) || !readVec(ADDR_B, cd.b, b, over)) return false;
  if (measMode == M_TOTAL) g = norm3(a) - norm3(b);
  else g = cd.zSign * (zCorr(a, cd.refA) - zCorr(b, cd.refB));
  tilt = tiltMetric(b, cd.refB);
  return true;
}

// ============================================================================
// BATTERY
// ============================================================================
void updateBattery() {
  uint32_t s = 0;
  for (int i = 0; i < 16; i++) s += analogReadMilliVolts(PIN_VBAT);
  float v = 2.0f * (s / 16.0f) / 1000.0f;                  // 100k/100k divider
  static const float tv[7] = {3.30f, 3.60f, 3.70f, 3.80f, 3.90f, 4.00f, 4.15f};
  static const float tp[7] = {0, 10, 30, 55, 75, 88, 100};
  int p;
  if (v <= tv[0]) p = 0;
  else if (v >= tv[6]) p = 100;
  else {
    int k = 0;
    while (v > tv[k + 1]) k++;
    p = (int)(tp[k] + (tp[k + 1] - tp[k]) * (v - tv[k]) / (tv[k + 1] - tv[k]));
  }
  batPct = constrain(p, 0, 100);
}

// ============================================================================
// CALIBRATION (hard-iron 30 s + vertical reference 3 s)
// ============================================================================
void wait1s() {
  uint32_t t = millis();
  while (millis() - t < 1000) { buzzUpdate(); delay(5); }
}

bool calibrateAll() {
  float mnA[3], mxA[3], mnB[3], mxB[3];
  for (int i = 0; i < 3; i++) { mnA[i] = mnB[i] = 1e9; mxA[i] = mxB[i] = -1e9; }
  uint32_t t0 = millis();
  int lastSec = -1;
  while (millis() - t0 < 30000) {
    buzzUpdate();
    int sec = 30 - (millis() - t0) / 1000;
    if (sec != lastSec) {
      char b[8]; snprintf(b, sizeof(b), "%d", sec);
      dMsg("ROTATE POLE", "IN ALL DIRECTIONS", b);
      lastSec = sec;
    }
    float a[3], b[3];
    if (readRaw(ADDR_A, a) && readRaw(ADDR_B, b)) {
      for (int i = 0; i < 3; i++) {
        mnA[i] = min(mnA[i], a[i]); mxA[i] = max(mxA[i], a[i]);
        mnB[i] = min(mnB[i], b[i]); mxB[i] = max(mxB[i], b[i]);
      }
    }
  }
  float rA = 0, rB = 0; bool valid = true;
  for (int i = 0; i < 3; i++) {
    float da = mxA[i] - mnA[i], db = mxB[i] - mnB[i];
    if (da < 20000.0f || db < 20000.0f) valid = false;       // less than 20 uT range: not rotated enough
    rA += da; rB += db;
  }
  if (!valid) { dMsg("CAL FAILED", "ROTATE MORE", nullptr); beepReject(); delay(1500); return false; }
  rA /= 3; rB /= 3;
  for (int i = 0; i < 3; i++) {
    cd.a.off[i] = (mxA[i] + mnA[i]) / 2; cd.a.sc[i] = rA / (mxA[i] - mnA[i]);
    cd.b.off[i] = (mxB[i] + mnB[i]) / 2; cd.b.sc[i] = rB / (mxB[i] - mnB[i]);
  }
  float k = rA / rB;                                         // equalize the two sensors
  for (int i = 0; i < 3; i++) cd.b.sc[i] *= k;

  // Step 2: vertical reference
  for (int s = 4; s > 0; s--) {
    char b[8]; snprintf(b, sizeof(b), "%d", s);
    dMsg("HOLD VERTICAL", "USE THE LEVEL", b);
    wait1s();
  }
  dMsg("KEEP STILL", nullptr, nullptr);
  float sa[3] = {0, 0, 0}, sb[3] = {0, 0, 0}; int n = 0;
  t0 = millis();
  while (millis() - t0 < 3000) {
    buzzUpdate();
    float a[3], b[3];
    if (readVec(ADDR_A, cd.a, a, 4) && readVec(ADDR_B, cd.b, b, 4)) {
      for (int i = 0; i < 3; i++) { sa[i] += a[i]; sb[i] += b[i]; }
      n++;
    }
  }
  if (n < 3) { dMsg("CAL FAILED", "CHECK SENSORS", nullptr); beepReject(); delay(1500); return false; }
  for (int i = 0; i < 3; i++) { cd.refA[i] = sa[i] / n; cd.refB[i] = sb[i] / n; }
  cd.zSign = (cd.refA[2] > 0) ? 1 : -1;
  cd.magic = CAL_MAGIC;
  prefs.putBytes("cal", &cd, sizeof(CalData));
  calValid = true;
  autoZeroPending = true;
  dMsg("SAVED", nullptr, nullptr);
  beepDone();
  uint32_t t = millis();
  while (millis() - t < 1200) { buzzUpdate(); delay(5); }
  return true;
}

// ============================================================================
// ACTIONS
// ============================================================================
void flash(const char *msg, uint32_t ms) {
  strncpy(flashBuf, msg, sizeof(flashBuf) - 1);
  flashBuf[sizeof(flashBuf) - 1] = 0;
  flashUntil = millis() + ms;
}

void enterLive() {
  state = S_LIVE;
  emaInit = false; sinceReset = 0;
  med = Med5();
  nextAuto = millis() + AUTO_MS;
  dForce();
}

void openMenu() { state = S_MENU; menuSel = 0; dMenu(menuSel); }

void handleMenu(Ev en, Ev et) {
  if (en == EV_SHORT) { menuSel = (menuSel + 1) % MENU_N; dMenu(menuSel); }
  if (et == EV_SHORT) {
    switch (menuSel) {
      case 0: calibrateAll(); enterLive(); return;
      case 1: measMode = (measMode == M_TOTAL) ? M_Z : M_TOTAL;
              prefs.putUChar("mmode", (uint8_t)measMode); autoZeroPending = true; break;
      case 2: sensIdx = (sensIdx + 1) % 3; prefs.putUChar("sens", sensIdx); break;
      default: enterLive(); return;
    }
    dMenu(menuSel);
  }
}

void startSampling() {
  state = S_SAMPLING;
  sampStart = millis(); lastTick = sampStart;
  sumS = 0; sn = 0; maxTilt = 0;
  flashUntil = 0; holdUntil = 0;
  beepSampleStart();
}

void finishSampling() {
  tiltTone = false;
  state = S_LIVE;
  nextAuto = millis() + AUTO_MS;
  float mean = sumS / sn;

  if (maxTilt > TILT_LIMIT_NT) {                       // pole was not vertical: reject the point
    flash("TILT", 1500);
    beepReject();
    Serial.printf("point rejected: tilt %.0f nT\n", maxTilt);
    return;
  }
  Serial.printf("point mean=%.1f nT tilt=%.0f\n", mean, maxTilt);
  flash("POINT OK", 1500);
  holdVal = mean; holdUntil = millis() + 1500;
  beepDone();
}

void render() {
  static uint32_t last = 0;
  uint32_t now = millis();
  if (now - last < 100) return;
  last = now;

  float v = (now < holdUntil) ? holdVal : curVal;
  int iv = constrain((int)lroundf(v), -999, 999);
  float db = SENS[sensIdx].deadband;

  const char *label; int kind;
  if (now < flashUntil)                         { label = flashBuf;   kind = (strcmp(flashBuf, "TILT") == 0) ? 4 : 3; }
  else if (state == S_SAMPLING)                 { label = "SAMPLING"; kind = 3; }
  else if (tiltVal > TILT_LIMIT_NT)             { label = "TILT";     kind = 4; }
  else if (v > db)                              { label = "METAL";    kind = 1; }
  else if (v < -db)                             { label = "OPPOSITE"; kind = 2; }
  else                                          { label = "CLEAR";    kind = 0; }

  char h1[20], h2[20];
  if (scanMode == SCAN_AUTO && state == S_LIVE) {
    long rem = (long)(nextAuto - now); if (rem < 0) rem = 0;
    snprintf(h1, sizeof(h1), "AUTO %lds", (rem + 999) / 1000);
  } else snprintf(h1, sizeof(h1), "%s", SCAN_NAMES[scanMode]);
  snprintf(h2, sizeof(h2), "%s %s", MEAS_NAMES[measMode], SENS[sensIdx].name);

  float sf = (state == S_SAMPLING) ? fminf(1.0f, (float)(now - sampStart) / SAMPLE_MS) : -1.0f;
  dLive(iv, h1, h2, label, kind, bleConnected, batPct, tiltVal / TILT_LIMIT_NT, sf, SENS[sensIdx].fullScale);
}

// ============================================================================
// SETUP / LOOP
// ============================================================================
void setup() {
  Serial.begin(115200);
  pinMode(PIN_NAV, INPUT_PULLUP);
  pinMode(PIN_TRIG, INPUT_PULLUP);
  analogSetPinAttenuation(PIN_VBAT, ADC_11db);
  buzzInit();

  Wire.begin(21, 22);
  Wire.setClock(100000);                 // 100 kHz: safer on a long cable to the upper sensor
  Wire.setTimeOut(50);

  dInit();
  dSplash();
  beepStartup();

  prefs.begin("grad", false);
  measMode = (MeasMode)min<uint8_t>(prefs.getUChar("mmode", 0), 1);
  sensIdx = min<uint8_t>(prefs.getUChar("sens", 1), 2);
  if (prefs.getBytesLength("cal") == sizeof(CalData)) {
    prefs.getBytes("cal", &cd, sizeof(CalData));
    calValid = (cd.magic == CAL_MAGIC);
  }

  initSensor(ADDR_A);
  initSensor(ADDR_B);
  bleInit();

  uint32_t t = millis();
  while (millis() - t < 1000) { buzzUpdate(); delay(5); }

  while (!calValid) calibrateAll();      // first boot: calibration is mandatory
  updateBattery();
  enterLive();
}

void loop() {
  buzzUpdate();
  Ev en = btnNav.update();
  Ev et = btnTrig.update();

  if (state == S_MENU) { handleMenu(en, et); return; }

  // --- sensors ---
  int over = (scanMode == SCAN_LIVE) ? OVER_LIVE : OVER_POINT;
  float g, tilt, sample = 0;
  bool ok = readGradient(over, g, tilt);
  if (ok) {
    float m = med.push(g);
    if (!emaInit) { emaVal = m; emaInit = true; tiltVal = tilt; }
    emaVal += SENS[sensIdx].alpha * (m - emaVal);
    tiltVal += 0.3f * (tilt - tiltVal);
    sinceReset++;
    if (autoZeroPending && sinceReset >= 8) { baseline = emaVal; autoZeroPending = false; }
    curVal = emaVal - baseline;
    sample = m - baseline;
  }

  if (state == S_LIVE) {
    if (en == EV_SHORT) { baseline = emaVal; curVal = 0; flash("ZEROED", 800); }
    else if (en == EV_LONG) { openMenu(); return; }

    if (et == EV_LONG) {
      scanMode = (ScanMode)((scanMode + 1) % 3);
      nextAuto = millis() + AUTO_MS;
      flash(SCAN_NAMES[scanMode], 900);
    } else if (scanMode != SCAN_LIVE) {
      if (et == EV_SHORT) startSampling();
      else if (scanMode == SCAN_AUTO && (int32_t)(millis() - nextAuto) >= 0) startSampling();
    }
  } else if (state == S_SAMPLING) {
    uint32_t now = millis();
    if (ok) { sumS += sample; sn++; if (tiltVal > maxTilt) maxTilt = tiltVal; }
    tiltTone = (tiltVal > TILT_LIMIT_NT);
    if (!tiltTone && now - lastTick >= 500) { lastTick = now; beepTick(); }
    if (now - sampStart >= SAMPLE_MS && sn >= 3) finishSampling();
  }

  if (ok && bleConnected && millis() - lastTx >= 100) { lastTx = millis(); bleSend(curVal); }

  if (millis() - lastBat > 2000) { lastBat = millis(); updateBattery(); }
  render();
}
