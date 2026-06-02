#include <WiFi.h>
#include <esp_now.h>

// ----------------------------
// CONFIGURAÇÕES INICIAIS
// ----------------------------
const int masoPins[] = {
  16, 17, 18, 19,
  21, 22, 23,
  25, 26, 27,
  32, 33,
  4, 5,
  13, 14
};
const int numMasoPins = sizeof(masoPins) / sizeof(masoPins[0]);

#define NUM_SADO_PINS 20
#define NUM_MASO_PINS 20
int matrix[NUM_SADO_PINS][NUM_MASO_PINS] = {0};

// Endereço MAC do Transceiver (substituir caso mude)
uint8_t transceiverAddress[] = {0x78, 0x1C, 0x3C, 0xA9, 0xFA, 0xD8};

// Estrutura de mensagem recebida do SADO
typedef struct {
  char id[6];
  uint8_t pin;
  bool state;
} SadoMessage;

SadoMessage incoming;
bool updateEnviado = false;

// ----------------------------
// CALLBACK DE RECEPÇÃO
// ----------------------------
void OnDataRecv(const esp_now_recv_info_t *info, const uint8_t *incomingData, int len) {
  if (len != sizeof(SadoMessage)) return;
  memcpy(&incoming, incomingData, sizeof(incoming));

  delay(10);

  if (incoming.state) {
    bool pontoAtivado = false;
    for (int j = 0; j < numMasoPins; j++) {
      int val = digitalRead(masoPins[j]);
      if (val == LOW) {
        matrix[incoming.pin][j] = 1;
        pontoAtivado = true;
        break;
      }
    }
  } else {
    for (int j = 0; j < numMasoPins; j++) {
      matrix[incoming.pin][j] = 0;
    }
  }

  sendMatrixBufferLine(incoming.pin);
}

// ----------------------------
// ENVIA UMA LINHA DA MATRIZ
// ----------------------------
void sendMatrixBufferLine(int sadoIndex) {
  String line = "";

  for (int j = 0; j < NUM_MASO_PINS; j++) {
    line += String(matrix[sadoIndex][j]);
    if (j < NUM_MASO_PINS - 1) line += " ";
  }

  Serial.println(line);  // imprime localmente

  // envia linha ao transceiver
  esp_now_send(transceiverAddress, (uint8_t *)line.c_str(), line.length() + 1);

  if (sadoIndex == NUM_SADO_PINS - 1 && !updateEnviado) {
    Serial.println("UPDATE");
    String up = "UPDATE";
    esp_now_send(transceiverAddress, (uint8_t *)up.c_str(), up.length() + 1);
    updateEnviado = true;
  }

  if (sadoIndex == 0) updateEnviado = false;
}

// ----------------------------
// SETUP
// ----------------------------
void setup() {
  Serial.begin(115200);
  WiFi.mode(WIFI_STA);

  for (int i = 0; i < numMasoPins; i++) {
    pinMode(masoPins[i], INPUT_PULLUP);
  }

  if (esp_now_init() != ESP_OK) {
    Serial.println("Erro ao inicializar ESP-NOW");
    return;
  }

  esp_now_register_recv_cb(OnDataRecv);

  // Adiciona o peer (transceiver)
  esp_now_peer_info_t peerInfo;
  memset(&peerInfo, 0, sizeof(peerInfo));
  memcpy(peerInfo.peer_addr, transceiverAddress, 6);
  peerInfo.channel = 0;
  peerInfo.encrypt = false;
  esp_now_add_peer(&peerInfo);

  Serial.println("Maso iniciado. Aguardando dados do Sado...");
}

// ----------------------------
// LOOP
// ----------------------------
void loop() {
  // passivo
}
