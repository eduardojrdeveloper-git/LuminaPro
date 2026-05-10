# Bitácora de Aprendizaje: Lumina Pro (iOS CI/CD & Flutter)

Este documento resume los desafíos técnicos y las soluciones implementadas para construir una aplicación de Flutter para iOS desde un entorno Windows, utilizando GitHub Actions y evitando bloqueos de firma de código.

## 1. Desafíos de Firma de Código (Code Signing)
**Problema:** Xcode bloquea la compilación para dispositivos físicos (ARM64) si no se detecta un `Development Team` válido, incluso usando la bandera `--no-codesign`.

**Lecciones:**
- **Bypass en `pbxproj`:** Es necesario parchear el archivo `ios/Runner.xcodeproj/project.pbxproj` para cambiar `CODE_SIGNING_ALLOWED` de `YES` a `NO` y eliminar las referencias a `DevelopmentTeam`.
- **Modo Simulator vs Device:** Compilar para el simulador (`--simulator`) no requiere firmas, pero el binario resultante no es compatible con procesadores ARM64 de iPhones reales (se cierra al abrir).
- **Inyección en `Generated.xcconfig`:** Para que el bypass sea efectivo, las variables `CODE_SIGNING_ALLOWED=NO` y `CODE_SIGNING_REQUIRED=NO` deben inyectarse directamente en los archivos de configuración de Flutter para Xcode.

## 2. Gestión de Identificadores (Bundle ID)
**Problema:** Xcode valida el Bundle ID contra la base de datos de Apple. Si el ID ya está registrado por otro usuario, el build falla.

**Solución:**
- Generar un Bundle ID dinámico y aleatorio durante el proceso de CI/CD (ej. `com.luminapro.app.$(openssl rand -hex 4)`) para asegurar que el proceso de compilación en la nube sea único y no tenga conflictos.

## 3. Automatización (GitHub Actions)
**Aprendizajes de Workflow:**
- **Versiones de Actions:** GitHub depreca versiones rápidamente. Siempre usar `actions/checkout@v4` y `actions/upload-artifact@v4`.
- **Idempotencia con PlistBuddy:** Al modificar el `Info.plist`, usar comandos que verifiquen si la clave ya existe (`Set` || `Add`) para evitar que el script falle con errores de "Entry Already Exists".
- **Inyección de Dependencias:** Usar `sed` o `cat` para reconstruir el `pubspec.yaml` de forma que las dependencias locales (como plugins FFI) se inserten con la indentación correcta.

## 4. Acceso al File System en iOS
**Requisito:** Poder transferir música (FLAC/WAV) y perfiles de EQ (`.txt`) desde Windows.

**Configuración Crítica en `Info.plist`:**
- `UIFileSharingEnabled`: `true` (Habilita compartir archivos en iTunes/3uTools).
- `LSSupportsOpeningDocumentsInPlace`: `true` (Permite que la app abra archivos directamente desde el almacenamiento).

## 5. Arquitectura del Motor de Audio
- **FFI (Foreign Function Interface):** La comunicación entre Flutter y C++ debe ser síncrona para audio de baja latencia. El plugin FFI debe estar en una subcarpeta separada y ser inyectado como dependencia de ruta.
- **Escaneo de Archivos:** Usar `path_provider` para acceder a `getApplicationDocumentsDirectory()`, que es el punto de entrada para los archivos subidos por el usuario vía USB.

---
*Este documento es una guía de referencia rápida para futuros proyectos con arquitectura similar.*
