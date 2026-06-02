import processing.serial.*;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.ArrayList;

Serial myPort;

// -----------------------------------------------------------------------------
// SERIAL / SIMULAÇÃO
// -----------------------------------------------------------------------------
boolean serialDisponivel = false;
boolean simulacaoAtiva = false;

int ultimoSimUpdate = 0;
int intervaloSim = 1200;

int[][] simMatrix;

// -----------------------------------------------------------------------------
// GRID
// -----------------------------------------------------------------------------
int cols = 16;
int rows = 16;

int marginX = 40;
int marginY = 40;

int[][] matriz = new int[cols][rows];
int[][] bufferMatriz = new int[cols][rows];

// -----------------------------------------------------------------------------
// TRAÇOS DE MEMÓRIA
// -----------------------------------------------------------------------------
float[][] ativacoes = new float[cols][rows];

float totalActivations = 0;

// esquecimento global
float memoryDecay = 0.9995;

// -----------------------------------------------------------------------------
// VISUAL
// -----------------------------------------------------------------------------
int cellSize = 40;
int cellSizeX = 80;

int linhaAtual = 0;

PFont fonte;

// -----------------------------------------------------------------------------
// PAINEL LATERAL
// -----------------------------------------------------------------------------
int panelWidth;

int totalWidth;
int totalHeight;

// -----------------------------------------------------------------------------
// CONEXÕES
// -----------------------------------------------------------------------------
CopyOnWriteArrayList<Conexao> conexoes =
  new CopyOnWriteArrayList<Conexao>();

int MAX_CONEXOES = 700;

// -----------------------------------------------------------------------------
// VISITANTES / HUMOR
// -----------------------------------------------------------------------------
int visitantes = 0;

float globalMoodTarget = 0;
float globalMood = 0;

float moodSmoothing = 0.06;

float visitorSaturationPoint = 200.0;

float minPointWob = 0.5;
float maxPointWob = 4.0;

int minNewPerUpdate = 2;
int maxNewPerUpdate = 15;

float minFadeSpeed = 0.002;
float maxFadeSpeed = 0.018;

float minFreqMul = 0.8;
float maxFreqMul = 1.8;

// -----------------------------------------------------------------------------
// SETTINGS
// -----------------------------------------------------------------------------
void settings() {

  int baseWidth =
    cols * cellSizeX + marginX * 2;

  panelWidth = baseWidth / 3;

  totalWidth =
    baseWidth + panelWidth;

  totalHeight =
    rows * cellSize + marginY * 2;

  size(totalWidth, totalHeight);
}

// -----------------------------------------------------------------------------
// SETUP
// -----------------------------------------------------------------------------
void setup() {

  println("Iniciando visualização da matriz...");

  fonte = createFont("Helvetica", 12);

  simMatrix = new int[cols][rows];

  for (int i = 0; i < cols; i++) {

    for (int j = 0; j < rows; j++) {

      ativacoes[i][j] = 0;
      simMatrix[i][j] = 0;
    }
  }

  try {

    myPort = new Serial(this, "COM19", 115200);

    myPort.bufferUntil('\n');

    serialDisponivel = true;

    println("COM19 conectada.");

  } catch(Exception e) {

    serialDisponivel = false;

    println("COM19 não encontrada.");
    println("Pressione 's' para iniciar simulação.");
  }
}

// -----------------------------------------------------------------------------
// KEYBOARD
// -----------------------------------------------------------------------------
void keyPressed() {

  if (key == '=') {
    visitantes++;
  }

  if (key == '-') {
    visitantes = max(0, visitantes - 1);
  }

  if (key == 's') {

    simulacaoAtiva = !simulacaoAtiva;

    println("Simulação: " + simulacaoAtiva);
  }
}

// -----------------------------------------------------------------------------
// DRAW
// -----------------------------------------------------------------------------
void draw() {

  background(255);

  // ---------------------------------------------------------------------------
  // SIMULAÇÃO
  // ---------------------------------------------------------------------------
  if (!serialDisponivel && simulacaoAtiva) {
    simularSerial();
  }

  // ---------------------------------------------------------------------------
  // HUMOR GLOBAL
  // ---------------------------------------------------------------------------
  float humorBase =
    log(1 + visitantes) /
    log(1 + visitorSaturationPoint);

  humorBase = constrain(humorBase, 0, 1);

  globalMoodTarget = humorBase;

  globalMood =
    lerp(
      globalMood,
      globalMoodTarget,
      moodSmoothing
    );

  // ---------------------------------------------------------------------------
  // CONEXÕES
  // ---------------------------------------------------------------------------
  for (Conexao c : conexoes) {
    c.update();
    c.draw();
  }

  for (Conexao c : conexoes) {

    if (c.isDead()) {
      conexoes.remove(c);
    }
  }

  // ---------------------------------------------------------------------------
  // NÓS
  // ---------------------------------------------------------------------------
  textFont(fonte);

  textSize(12);

  textAlign(LEFT, TOP);

  for (int i = 0; i < cols; i++) {

    for (int j = 0; j < rows; j++) {

      if (matriz[i][j] == 1) {

        float cx =
          marginX + i * cellSizeX + cellSizeX/2;

        float cy =
          marginY + j * cellSize + cellSize/2;

        float pointWobAmp =
          lerp(
            minPointWob,
            maxPointWob,
            globalMood
          );

        float wob =
          sin(
            (millis() /
            (380.0 - 120.0 * globalMood))
            + i * 0.3
            + j * 0.7
          )
          * pointWobAmp;

        float wob2 =
          cos(
            (millis() /
            (360.0 - 110.0 * globalMood))
            + i * 0.8
            + j * 0.4
          )
          * pointWobAmp;

        fill(0);

        noStroke();

        ellipse(
          cx + wob,
          cy + wob2,
          cellSize * 0.8,
          cellSize * 0.8
        );

        float p = 0;

        if (totalActivations > 0) {

          p =
            ativacoes[i][j]
            * 100.0
            / totalActivations;
        }

        String line1 =
          "<" + i + "," + j + ">";

        String line2 =
          nf(p, 0, 1) + "%";

        float tx =
          marginX + (i + 1) * cellSizeX - 10;

        float ty =
          marginY + (j + 1) * cellSize - 28;

        fill(0);

        text(line1, tx, ty);
        text(line2, tx, ty + 14);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------
  textSize(14);

  textAlign(LEFT, BOTTOM);

  fill(0);

  text(
    "Visitantes: " + visitantes,
    marginX,
    height - 8
  );

  // ---------------------------------------------------------------------------
  // PAINEL DE MEMÓRIA
  // ---------------------------------------------------------------------------
  drawPainelMemoria();
}

// -----------------------------------------------------------------------------
// SERIAL
// -----------------------------------------------------------------------------
void serialEvent(Serial myPort) {

  String line =
    myPort.readStringUntil('\n');

  if (line == null) return;

  line = trim(line);

  if (line.equalsIgnoreCase("mais")) {

    visitantes++;

    return;
  }

  if (line.equalsIgnoreCase("menos")) {

    visitantes = max(0, visitantes - 1);

    return;
  }

  if (line.equals("UPDATE")) {

    aplicarBufferNaMatriz();

  } else if (line.matches("[0-1 ]+")) {

    String[] vals =
      split(line, ' ');

    for (
      int j = 0;
      j < vals.length && j < rows;
      j++
    ) {

      if (int(vals[j]) == 1) {

        bufferMatriz[linhaAtual][j] = 1;
      }
    }

    linhaAtual++;

    if (linhaAtual >= cols) {
      linhaAtual = 0;
    }
  }
}

// -----------------------------------------------------------------------------
// APLICAR BUFFER
// -----------------------------------------------------------------------------
void aplicarBufferNaMatriz() {

  // ---------------------------------------------------------------------------
  // ESQUECIMENTO
  // ---------------------------------------------------------------------------
  totalActivations = 0;

  for (int i = 0; i < cols; i++) {

    for (int j = 0; j < rows; j++) {

      ativacoes[i][j] *= memoryDecay;

      totalActivations += ativacoes[i][j];
    }
  }

  // ---------------------------------------------------------------------------
  // NOVAS ATIVAÇÕES
  // ---------------------------------------------------------------------------
  for (int i = 0; i < cols; i++) {

    for (int j = 0; j < rows; j++) {

      if (bufferMatriz[i][j] == 1) {

        ativacoes[i][j] += 1.0;
      }

      matriz[i][j] = bufferMatriz[i][j];

      bufferMatriz[i][j] = 0;
    }
  }

  // recalcula total
  totalActivations = 0;

  for (int i = 0; i < cols; i++) {

    for (int j = 0; j < rows; j++) {

      totalActivations += ativacoes[i][j];
    }
  }

  linhaAtual = 0;

  marcarConexoesParaMorte();

  atualizarConexoesMemoria();
}

// -----------------------------------------------------------------------------
// SIMULAÇÃO
// -----------------------------------------------------------------------------
void simularSerial() {

  if (
    millis() - ultimoSimUpdate
    < intervaloSim
  ) {
    return;
  }

  ultimoSimUpdate = millis();

  int mudancas =
    int(random(1, 4));

  for (int n = 0; n < mudancas; n++) {

    int x = int(random(cols));
    int y = int(random(rows));

    if (random(1) < 0.2) {

      simMatrix[x][y] = 1;

    } else {

      simMatrix[x][y] = 0;
    }
  }

  int ativos = 0;

  for (int i = 0; i < cols; i++) {

    for (int j = 0; j < rows; j++) {

      if (simMatrix[i][j] == 1) {
        ativos++;
      }
    }
  }

  if (ativos > 40) {

    for (int k = 0; k < 10; k++) {

      int x = int(random(cols));
      int y = int(random(rows));

      simMatrix[x][y] = 0;
    }
  }

  for (int i = 0; i < cols; i++) {

    for (int j = 0; j < rows; j++) {

      bufferMatriz[i][j] =
        simMatrix[i][j];
    }
  }

  aplicarBufferNaMatriz();
}

// -----------------------------------------------------------------------------
// CONEXÃO
// -----------------------------------------------------------------------------
class Conexao {

  int i1, j1, i2, j2;

  float progress = 0;

  float baseSpeed;

  float wiggleAmpBase;

  float moodFreq;
  float moodShift;
  float moodChaos;

  float freqMul;

  boolean dying = false;

  float fadeSpeed;

  Conexao(
    int a,
    int b,
    int c,
    int d,
    float moodFactor
  ) {

    i1 = a;
    j1 = b;

    i2 = c;
    j2 = d;

    baseSpeed =
      0.001 + random(0.008);

    wiggleAmpBase =
      3.0 + random(3.0);

    moodFreq =
      random(0.5, 2.5);

    moodShift =
      random(TWO_PI);

    moodChaos =
      random(0.4, 2.0);

    freqMul =
      random(0.9, 1.15);

    fadeSpeed =
      lerp(
        minFadeSpeed,
        maxFadeSpeed,
        moodFactor
      );
  }

  void kill() {

    if (!dying) {

      dying = true;

      fadeSpeed =
        lerp(
          minFadeSpeed,
          maxFadeSpeed,
          globalMood
        );
    }
  }

  boolean isDead() {

    return dying &&
           progress <= 0.005;
  }

  void update() {

    float speedScale =
      lerp(0.6, 1.6, globalMood);

    float s =
      baseSpeed * speedScale;

    if (!dying) {

      progress =
        min(1.0, progress + s);

    } else {

      progress =
        max(0.0, progress - fadeSpeed);
    }
  }

  void draw() {

    if (progress <= 0) return;

    float x1 =
      marginX + i1 * cellSizeX + cellSizeX/2;

    float y1 =
      marginY + j1 * cellSize + cellSize/2;

    float x2 =
      marginX + i2 * cellSizeX + cellSizeX/2;

    float y2 =
      marginY + j2 * cellSize + cellSize/2;

    float t =
      millis() * 0.001 *
      lerp(
        minFreqMul,
        maxFreqMul,
        globalMood
      );

    float f1 =
      t * moodFreq * freqMul;

    float f2 =
      t * (moodFreq * 0.9) * freqMul;

    float wigAmp =
      wiggleAmpBase *
      lerp(1.0, 1.6, globalMood);

    float wobble1 =
      sin(
        f1 + i1 * 0.4 + j1 * 0.25
      ) * wigAmp;

    float wobble2 =
      sin(
        f2 + i2 * 0.4 + j2 * 0.25
      ) * wigAmp;

    float moodWiggle =
      (
        sin(
          t * moodFreq + moodShift
        )
        * moodChaos * 2.0

        +

        cos(
          t * moodFreq * 0.35
          + moodShift * 0.4
        )
        * (moodChaos * 0.6)
      )
      * globalMood * 0.9;

    float cx =
      (x1 + x2)/2
      + wobble1
      + moodWiggle;

    float cy =
      (y1 + y2)/2
      + wobble2
      + moodWiggle * 0.55;

    float alpha =
      map(progress, 0, 1, 0, 90);

    noFill();

    stroke(0, alpha);

    strokeWeight(2);

    beginShape();

    for (
      float tt = 0;
      tt < progress;
      tt += 0.03
    ) {

      float x =
        bezierPoint(
          x1, cx, cx, x2, tt
        );

      float y =
        bezierPoint(
          y1, cy, cy, y2, tt
        );

      vertex(x, y);
    }

    endShape();
  }
}

// -----------------------------------------------------------------------------
// CONEXÕES BASEADAS EM MEMÓRIA
// -----------------------------------------------------------------------------
void atualizarConexoesMemoria() {

  ArrayList<int[]> ativos =
    new ArrayList<int[]>();

  for (int i = 0; i < cols; i++) {

    for (int j = 0; j < rows; j++) {

      if (matriz[i][j] == 1) {

        ativos.add(new int[]{i, j});
      }
    }
  }

  if (ativos.size() < 2) return;

  int numToCreate =
    int(
      lerp(
        minNewPerUpdate,
        maxNewPerUpdate,
        globalMood
      )
    );

  numToCreate = max(1, numToCreate);

  int created = 0;
  int attempts = 0;

  while (
    created < numToCreate &&
    attempts < numToCreate * 8
  ) {

    attempts++;

    int[] src =
      ativos.get(
        int(random(ativos.size()))
      );

    int[] dst =
      ativos.get(
        int(random(ativos.size()))
      );

    if (
      src[0] == dst[0] &&
      src[1] == dst[1]
    ) {
      continue;
    }

    float memoryWeight =
      ativacoes[src[0]][dst[1]];

    float probability =
      memoryWeight /
      (memoryWeight + 5.0);

    if (random(1) > probability) {
      continue;
    }

    Conexao c =
      new Conexao(
        src[0],
        src[1],
        dst[0],
        dst[1],
        globalMood
      );

    conexoes.add(c);

    created++;

    if (conexoes.size() > MAX_CONEXOES) {
      conexoes.remove(0);
    }
  }
}

// -----------------------------------------------------------------------------
// REMOVER CONEXÕES
// -----------------------------------------------------------------------------
void marcarConexoesParaMorte() {

  for (Conexao c : conexoes) {

    if (
      matriz[c.i1][c.j1] == 0 ||
      matriz[c.i2][c.j2] == 0
    ) {

      c.kill();
    }
  }
}

// -----------------------------------------------------------------------------
// PAINEL DE MEMÓRIA
// -----------------------------------------------------------------------------
void drawPainelMemoria() {

  int panelX =
    cols * cellSizeX + marginX * 2;

  float gridTop = 10;
  float gridLeft = panelX + 10;

  float gridW = panelWidth - 20;
  float gridH = totalHeight - 20;

  float cellW = gridW / cols;
  float cellH = gridH / rows;

  textSize(13);

  textAlign(CENTER, CENTER);

  for (int i = 0; i < cols; i++) {

    for (int j = 0; j < rows; j++) {

      float x =
        gridLeft + i * cellW + cellW/2;

      float y =
        gridTop + j * cellH + cellH/2;

      float prob = 0;

      if (totalActivations > 0) {

        prob =
          ativacoes[i][j]
          / totalActivations;
      }

      float gray =
        lerp(180, 10, prob * 20);

      gray =
        constrain(gray, 10, 180);

      fill(gray);

      text(
        nf(prob, 0, 2),
        x,
        y
      );
    }
  }

  noStroke();
}
