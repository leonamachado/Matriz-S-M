#include <WiFi.h>
#include <esp_now.h>

// ----------------------------
// ENDEREÇOS MAC DOS DESTINOS
// ----------------------------
uint8_t masoAddress[]       = {0x00, 0x4B, 0x12, 0x8F, 0x39, 0xD8};  // MASO principal
uint8_t backupAddress[]     = {0x00, 0x4B, 0x12, 0x8F, 0x61, 0x9C};  // MASO-backup

// Pinos do Sado (20 saídas)
const int sadoPins[] = {
  16, 17, 18, 19,
  21, 22, 23,
  25, 26, 27,
  32, 33,
  4, 5,
  13, 14
};
const int numPins = sizeof(sadoPins) / sizeof(sadoPins[0]);

const char SADO_ID[] = "S1";

// Estrutura da mensagem
typedef struct {
  char id[6];
  uint8_t pin;
  bool state;
} SadoMessage;

SadoMessage msg;

// ----------------------------
// CALLBACK DE ENVIO
// ----------------------------
void OnDataSent(const wifi_tx_info_t *info, esp_now_send_status_t status) {
  // sem Serial.print (TX0 está em uso)
}

// ----------------------------
// CONFIGURAÇÃO INICIAL
// ----------------------------
void setup() {

  WiFi.mode(WIFI_STA);

  if (esp_now_init() != ESP_OK) {
    return;
  }

  esp_now_register_send_cb(OnDataSent);

  // --- adiciona peer MASO
  esp_now_peer_info_t peerInfo;
  memset(&peerInfo, 0, sizeof(peerInfo));
  memcpy(peerInfo.peer_addr, masoAddress, 6);
  peerInfo.channel = 0;
  peerInfo.encrypt = false;
  esp_now_add_peer(&peerInfo);

  // --- adiciona peer MASO-backup
  memset(&peerInfo, 0, sizeof(peerInfo));
  memcpy(peerInfo.peer_addr, backupAddress, 6);
  peerInfo.channel = 0;
  peerInfo.encrypt = false;
  esp_now_add_peer(&peerInfo);

  // Configura pinos
  for (int i = 0; i < numPins; i++) {
    pinMode(sadoPins[i], OUTPUT);
    digitalWrite(sadoPins[i], LOW);
  }
}

// ----------------------------
// LOOP PRINCIPAL
// ----------------------------
void loop() {
  for (int i = 0; i < numPins; i++) {

    digitalWrite(sadoPins[i], HIGH);
    delay(50);

    strncpy(msg.id, SADO_ID, sizeof(msg.id));
    msg.pin = i;
    msg.state = true;

    esp_now_send(masoAddress,   (uint8_t *)&msg, sizeof(msg));
    esp_now_send(backupAddress, (uint8_t *)&msg, sizeof(msg));

    delay(50);

    digitalWrite(sadoPins[i], LOW);
    msg.state = false;

    esp_now_send(masoAddress,   (uint8_t *)&msg, sizeof(msg));
    esp_now_send(backupAddress, (uint8_t *)&msg, sizeof(msg));

    delay(50);
  }

  delay(50);
}
