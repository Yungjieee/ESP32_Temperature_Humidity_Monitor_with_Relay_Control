#include <WiFi.h>
#include "DHT.h"
#include <HTTPClient.h>
#include <WiFiClient.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <ArduinoJson.h>


// setup wifi
const char* ssid = "Alicia";
const char* pass = "ilovemcd";

// DHT sensor setup
#define DHTPIN 4
#define DHTTYPE DHT11
DHT dht(DHTPIN, DHTTYPE);

// setup oled
#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 32
#define OLED_RESET -1
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);

// setup led
#define LED_BUILTIN 2

//setup relay
#define RELAY_PIN 23

float temp_threshold = 35.0;
float hum_threshold = 80.0;
float hum = 0, temp = 0;
unsigned long sendDataPrevMillis = 0;
static unsigned long thresholdLastCheck = 0;
int count = 0;
String serverName = "http://iottraining.threelittlecar.com/";


void setup() {
  // put your setup code here, to run once:
  Serial.begin(115200);
  delay(100);

  // init wifi
  WiFi.begin(ssid, pass);
  delay(100);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("");
  Serial.println("WiFi connected");

  // init oled
  if (!display.begin(SSD1306_SWITCHCAPVCC, 0x3C)) {
    Serial.println(F("SSD1306 allocation failed"));
    while (true)
      ;
  }
  display.clearDisplay();
  display.setTextSize(1);
  display.setTextColor(SSD1306_WHITE);

  // init led
  pinMode(LED_BUILTIN, OUTPUT);
  digitalWrite(LED_BUILTIN, LOW);  // LED off by default

  // init relay
  pinMode(RELAY_PIN, OUTPUT);
  digitalWrite(RELAY_PIN, LOW);  // relay off

  // init dht
  dht.begin();
  delay(2000);
}

void loop() {

  // Fetch updated threshold values every 10 seconds
  if (millis() - thresholdLastCheck > 10000 || thresholdLastCheck == 0) {
    getThresholdFromServer();
    thresholdLastCheck = millis();
  }

  // Send DHT sensor data every 10 seconds
  if (millis() - sendDataPrevMillis > 10000 || sendDataPrevMillis == 0) {
    count++;
    getDHT();
    sendDataPrevMillis = millis();

    if (WiFi.status() == WL_CONNECTED) {
      WiFiClient client;
      HTTPClient http;
      String relayStatus = (temp > temp_threshold || hum > hum_threshold) ? "ON" : "OFF";
      String httpReqStr = serverName + "dht11.php?id=101&temp=" + temp + "&hum=" + hum + "&relay=" + relayStatus;
      ;
      http.begin(client, httpReqStr.c_str());
      int httpResponseCode = http.GET();
      if (httpResponseCode > 0) {
        Serial.print("HTTP Response code: ");
        Serial.println(httpResponseCode);
        String payload = http.getString();
        Serial.println(payload);
      } else {
        Serial.print("Error code: ");
        Serial.println(httpResponseCode);
      }
      // Free resources
      http.end();
    }
  }
}


void getDHT() {

  temp = dht.readTemperature();
  hum = dht.readHumidity();

  delay(2000);

  if (!isnan(temp) && !isnan(hum)) {
    Serial.printf("Temp: %.2f°C | Humidity: %.2f%% ", temp, hum);

    // OLED display
    display.clearDisplay();
    display.setCursor(0, 0);
    display.print("Temp: ");
    display.print(temp);
    display.println(" C");

    display.print("Hum: ");
    display.print(hum);
    display.println(" %");

    // Status
    String status;
    String relayStatus;


    // if (temp > 35 || hum > 80) {
    if (temp > temp_threshold || hum > hum_threshold) {
      digitalWrite(RELAY_PIN, HIGH);    // Turn ON relay
      digitalWrite(LED_BUILTIN, HIGH);  // Turn ON LED
      Serial.print("\nExceed temp threshold: ");
      Serial.print(temp_threshold);
      Serial.print(" or hum threshold: ");
      Serial.println(hum_threshold);
      status = "Status: ALERT!";
      relayStatus = "ON";
    } else {
      digitalWrite(RELAY_PIN, LOW);    // Turn OFF relay
      digitalWrite(LED_BUILTIN, LOW);  // Turn OFF LED
      status = "Status: Normal";
      relayStatus = "OFF";
    }
    display.println(status);
    display.display();

    // Print relay status to Serial Monitor
    Serial.println("Relay Status: " + relayStatus);
    Serial.println(status);

  } else {
    Serial.println("DHT sensor read failed.");
  }

  delay(200);
}

void getThresholdFromServer() {
  if (WiFi.status() == WL_CONNECTED) {
    HTTPClient http;
    String url = serverName + "get_threshold.php?id=101";
    http.begin(url);
    int httpCode = http.GET();
    if (httpCode > 0) {
      String payload = http.getString();
      Serial.println("Threshold Payload: " + payload);
      DynamicJsonDocument doc(256);
      deserializeJson(doc, payload);
      temp_threshold = doc["temp_threshold"];
      hum_threshold = doc["hum_threshold"];
    }
    http.end();
  }
}
