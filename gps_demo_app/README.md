# Demo GPS → Webhook → PostgreSQL

Esta aplicación obtiene la ubicación del teléfono, la envía al backend Flask y
consulta los registros que el backend guarda en PostgreSQL.

## Flujo

1. El celular obtiene latitud, longitud, precisión, altitud, velocidad, rumbo y
   marca de tiempo.
2. La app envía un `POST` a `/api/ubicaciones`.
3. Flask inserta los datos en la tabla `ubicaciones` de PostgreSQL.
4. La app ejecuta un `GET /api/ubicaciones` y muestra los registros guardados.

## Antes de presentar

El backend debe estar publicado en Render y debe tener configurada la variable
`DATABASE_URL` con la URL de conexión de PostgreSQL.

Comprueba desde un navegador:

```text
https://TU-SERVICIO.onrender.com/
```

Debe responder con el mensaje `Backend GPS funcionando en Render`.

## Instalar y usar el APK

El APK generado está en:

```text
build/app/outputs/flutter-apk/app-release.apk
```

1. Pasa el APK al teléfono e instálalo.
2. Abre **Demo GPS PostgreSQL**.
3. Pega la URL base de Render, por ejemplo
   `https://mi-backend.onrender.com`.
4. Pulsa **Obtener y enviar ubicación**.
5. Acepta el permiso de ubicación.
6. La pantalla mostrará los datos del teléfono y confirmará que PostgreSQL
   guardó el registro.
7. Pulsa **Ver datos guardados** para volver a consultar la base.

La app agrega automáticamente `/api/ubicaciones` a la URL base.

## Comprobación directa en PostgreSQL

Ejecuta esta consulta desde el cliente SQL conectado a la base de Render:

```sql
SELECT *
FROM ubicaciones
ORDER BY id DESC;
```

## Generar otro APK

La URL puede permanecer editable o quedar incluida al compilar:

```powershell
flutter build apk --release `
  --dart-define=API_URL=https://TU-SERVICIO.onrender.com
```
