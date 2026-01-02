# PhotoDex — Aplicație iOS pentru analiză de imagini *on-device* (Proof of Concept)

> **Lucrare de licență (2024)** — *Aplicație Mobilă: Suport pentru Învățare Asistată*  
> **Autor:** Vlad-Ioan Vorniceanu • **Coordonator științific:** Conf. Univ. Dr. Mihai Doinea

## Rezumat

**PhotoDex** este prima mea aplicație iOS dezvoltată individual, realizată ca parte a lucrării de licență (2024). Proiectul a fost conceput ca **Proof of Concept** pentru ideea că ecosistemul iOS actual (Core ML + Vision) permite rularea **procesărilor complexe de date și a modelelor de Machine Learning direct pe dispozitiv** (*on-device*), fără dependență de servicii externe.

Aplicația analizează fotografii și cadre live ale camerei pentru:
- **detecția obiectelor** în scenă,
- **identificarea/încadrarea persoanelor** și estimarea poziției corpului (Body Pose),
- prezentarea rezultatelor într-o interfață orientată spre **rapiditate, confidențialitate și utilizare practică**.

---

## Motivație și context

Evoluția fotografiei digitale (rezoluții ridicate, volum mare de date vizuale) crește cerința de instrumente care să **înțeleagă conținutul imaginii** rapid și local. În același timp, confidențialitatea și latența fac ca soluțiile *cloud-only* să fie mai puțin potrivite pentru scenarii de utilizare în timp real.

PhotoDex abordează aceste nevoi printr-o arhitectură care rulează **inferință ML locală**, în timp real, pe iPhone/iPad.

---

## Obiective urmărite

1. **Capturarea imaginilor pentru analiză**  
   Integrarea unui modul de cameră în aplicație, pentru un flux end-to-end.

2. **Procesare locală a imaginilor (on-device ML)**  
   Integrarea și rularea modelelor ML prin **Core ML** și orchestrat prin **Vision**.

3. **Analiză LIVE a cadrelor**  
   Analiza în timp real a fluxului video al camerei, cu overlay al rezultatelor.

---

## Funcționalități principale

- **Analizare LIVE a cadrelor** (camera stream)
- **Capturare de imagini** din cameră
- **Selectare imagini din galerie**
- **Analiza imaginilor capturate/selectate** și afișarea rezultatelor (detecții / etichete / pose)

---

## Arhitectură (overview)

Fluxul logic este construit în jurul unui pipeline de procesare locală:

1. **Captură** prin `CameraManager` și `CameraDelegate`, urmată de confirmarea inițierii analizei.
2. **Inferință** prin cereri Vision, folosind modele Core ML integrate (ex.: *YOLOv5s* și *MobileNetV2*), în paralel cu **Body Pose Detection**.
3. **Fuzionare rezultate**: combinația output-urilor (detecții + clasificare/semantica + pose) este redată în UI; punctele de Body Pose pot fi afișate la cerere.

> Notă: modelele și detaliile exacte de integrare sunt cele din proiect (în folderul aplicației / resurse Core ML).

---

## Tehnologii utilizate

- **Swift / iOS**
- **Core ML** — integrarea și rularea modelelor ML pe dispozitiv
- **Vision** — pre- și post-procesare, request-uri de analiză și Body Pose Detection
- **AVFoundation** (implicit, pentru captură cameră), acolo unde este necesar

---

## Capturi din prezentarea lucrării

### Introducere / context
<img width="2880" height="1620" alt="slide_2" src="https://github.com/user-attachments/assets/688c0fc3-9482-4047-850d-9cd381a9c706" />

### Obiective și beneficii
<img width="2880" height="1620" alt="slide_3" src="https://github.com/user-attachments/assets/11a9e915-7218-4703-b4d4-7fe83dee666d" />

### Funcționalități principale
<img width="2880" height="1620" alt="slide_5" src="https://github.com/user-attachments/assets/0906e554-d749-432a-9a72-189258c3d71b" />

### Arhitectură (diagramă de flux)
<img width="2880" height="1620" alt="slide_6" src="https://github.com/user-attachments/assets/2fa72704-b5e3-48c6-b61f-bd002b19472c" />

---

## Cum rulezi proiectul

1. Clonează repository-ul:
   ```bash
   git clone https://github.com/VladVorniceanu/Licenta2024.git
   ```
2. Deschide proiectul în Xcode:
   - `PhotoDex.xcodeproj`
3. Selectează un **iPhone real** (recomandat pentru camera + performanță ML) și rulează.
4. La prima rulare, acordă permisiunea pentru cameră (dacă este cerută de aplicație).

> Observație: în Simulator, accesul la cameră și performanța ML pot fi limitate.

---

## Valoare demonstrativă (Proof of Concept)

PhotoDex demonstrează practic că:
- inferența ML și analiza vizuală pot fi realizate **local**, cu latență redusă,
- confidențialitatea este îmbunătățită prin evitarea transmiterii imaginilor către servere,
- aplicațiile mobile pot integra pipeline-uri „grele” (detecție + analiză pose) în fluxuri UX utilizabile.

---

## Limitări și direcții de dezvoltare

- evaluări comparative sistematice (precizie / FPS / consum energetic) pe multiple dispozitive;
- îmbunătățirea UI/UX pentru cazuri de utilizare educaționale specifice;
- extinderea setului de clase detectabile și a strategiilor de filtrare a rezultatelor;
- optimizări suplimentare pentru performanță (quantization, batching, throttling pe frames).

---

## Licență și mențiuni

- Codul și resursele din acest repository sunt publicate conform setărilor repo-ului.
- Modelele ML incluse pot avea licențe separate; verifică licențele sursă dacă reutilizezi modele/greutăți în proiecte comerciale.

