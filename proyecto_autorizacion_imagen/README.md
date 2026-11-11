# Autorización de uso de imagen — Módulo 3 (offline-first)

App Flutter para recolectar la autorización de uso de imagen de los
participantes de un video o anuncio, pensada para funcionar sin internet en
el momento del rodaje y sincronizarse sola cuando vuelve la señal.

Este primer entregable cubre **la base del proyecto y el Módulo 3** de la
presentación: formulario + captura de selfie + cola local + sincronización
con Firebase (Firestore + Storage). Los módulos 1 (firma electrónica con
SignWell) y 2 (verificación facial con AWS Rekognition) quedan con los
campos ya previstos en el modelo de datos, listos para conectarse en los
siguientes pasos.

## Qué hay aquí

```
lib/
  models/
    registro_autorizacion.dart   → el registro de cada participante
  services/
    almacenamiento_local_service.dart  → la cola offline (JSON + fotos en el dispositivo)
    conectividad_service.dart         → detecta cuándo vuelve el internet
    sincronizacion_service.dart       → sube fotos (Storage) y datos (Firestore)
  widgets/
    captura_selfie_widget.dart   → botón de cámara + preview
  screens/
    formulario_screen.dart       → pantalla principal
    lista_registros_screen.dart  → registros guardados + "Sincronizar ahora"
  main.dart
pubspec.yaml
```

No incluye las carpetas `android/`, `ios/`, `web/`, etc. — esas las genera
Flutter (ver paso 1 abajo). Así el proyecto no queda atado a una versión
específica del SDK que no controlamos desde aquí.

## Requisitos previos

- Flutter instalado (`flutter --version` debe funcionar). Si no lo tienes:
  https://docs.flutter.dev/get-started/install
- Un editor (Android Studio o VS Code con la extensión de Flutter) y un
  emulador o celular físico para probar la cámara.
- Una cuenta de Firebase (gratis) — es el proveedor que se recomendó en el
  Módulo 3.

## 1. Generar las carpetas de la plataforma

Dentro de esta carpeta del proyecto:

```bash
flutter create .
flutter pub get
```

Esto agrega `android/`, `ios/`, `web/`, `test/`, etc. sin tocar el código
de `lib/` ni el `pubspec.yaml` que ya trae las dependencias correctas.

## 2. Permisos de cámara

`image_picker` necesita permiso de cámara. Después del paso 1, agrega:

**Android** — en `android/app/src/main/AndroidManifest.xml`, dentro de `<manifest>`:
```xml
<uses-permission android:name="android.permission.CAMERA" />
```

**iOS** — en `ios/Runner/Info.plist`, dentro de `<dict>`:
```xml
<key>NSCameraUsageDescription</key>
<string>Se usa la cámara para tomar la selfie de autorización</string>
```

## 3. Configurar Firebase

1. Crea un proyecto en https://console.firebase.google.com (el free tier
   alcanza de sobra para el curso).
2. Activa **Firestore** y **Storage** en modo de prueba (reglas abiertas
   temporalmente; antes de mostrarlo en producción hay que cerrarlas).
3. Instala la CLI de FlutterFire y corre, dentro del proyecto:
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```
   Esto genera `lib/firebase_options.dart` y conecta la app con tu proyecto
   de Firebase (Android/iOS/web).
4. En `lib/main.dart`, cambia:
   ```dart
   await Firebase.initializeApp();
   ```
   por:
   ```dart
   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
   ```
   y agrega `import 'firebase_options.dart';` arriba (el propio comando
   `flutterfire configure` suele ofrecerse a hacer este cambio por ti).

Si te saltas este paso, la app igual corre: el formulario guarda todo en el
dispositivo, solo que nunca vas a ver el estado pasar de "Pendiente" a
"Sincronizado" (aparece un aviso en pantalla recordándolo).

## 4. Correr la app

```bash
flutter run
```

## Cómo probar que el modo offline funciona

1. Activa el modo avión en el celular/emulador.
2. Llena el formulario, toma la selfie, marca los consentimientos y guarda.
3. Debe aparecer "Guardado en el dispositivo..." y, en la lista de
   registros, el chip **Pendiente**.
4. Desactiva el modo avión (o toca "Sincronizar ahora" en la lista).
5. El chip debe pasar a **Sincronizado**, y el registro debe verse en la
   consola de Firestore/Storage.

## Próximos pasos (siguiendo la guía de fases)

1. **Módulo 1 — Firma electrónica (SignWell):** resumir su autenticación,
   límites de uso y formato de respuesta; escribir la función de prueba
   que envía el documento (`documentoFirmaId` y `estadoFirma` en el modelo
   ya están listos para recibir ese resultado).
2. **Manejo de errores de esa integración** (Fase 2 de la guía): red caída,
   4xx/5xx de la API, timeout — con el mismo criterio que ya se usó aquí en
   `sincronizacion_service.dart` (cada tipo de error se distingue, no un
   único try/catch genérico).
3. **Módulo 2 — Verificación facial (AWS Rekognition):** cuando se suba el
   video final, comparar `fotoUrlRemota` de cada registro contra los
   rostros detectados en `videoId`.
4. **Envolver cada módulo como tool MCP** (`firmar_autorizacion`,
   `comparar_rostro`, `sincronizar_registros`) para que el agente conectado
   (OpenCode + Ollama/Qwen) pueda invocarlos — Fases 3 a 6 de la guía.
