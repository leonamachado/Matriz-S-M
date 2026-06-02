// --- Transceiver (ESP32) ---
// Recebe por ESP-NOW e encaminha por Serial (COM) para o Processing.

#include <WiFi.h>
#include <esp_now.h>

uint8_t myMac[6]; // opcional para debug

void OnDataRecv(const esp_now_recv_info_t *info, const uint8_t *data, int len) {

  // Converte payload recebido em string segura
  String s = "";
  for (int i = 0; i < len; i++) {
    char c = (char)data[i];
    // evita caracteres lixo quando payload é curto
    if (c >= 32 && c <= 126) s += c;
  }

  s.trim();

  // imprime exatamente como antes
  Serial.println(s);
}

void setup() {
  Serial.begin(115200);
  delay(100);

  WiFi.mode(WIFI_STA);

  Serial.print("Transceiver MAC: ");
  Serial.println(WiFi.macAddress());

  if (esp_now_init() != ESP_OK) {
    Serial.println("Erro ao iniciar ESP-NOW (Transceiver)");
    return;
  }

  // registra callback de recepção (IDF5)
  esp_now_register_recv_cb(OnDataRecv);

  Serial.println("Transceiver iniciado. Recebendo linhas e repassando por Serial...");
}

void loop() {
  // passivo — tudo ocorre no callback
}
