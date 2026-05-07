# Talento Sostenible

Aplicacion macOS en SwiftUI orientada a gestion comercial, financiera y operativa para un prototipo CRM/ERP de empresa.

## Estado del proyecto

El repositorio contiene un prototipo funcional nativo para macOS con foco en:

- CRM: contactos, empresas, leads, oportunidades, pipeline, actividades, campanas y automatizacion basica.
- Finanzas: facturas, gastos, vista previa y exportacion PDF.
- Comunicacion: integracion con Mail.app para lectura y redaccion desde cuenta corporativa.
- Agenda: calendario nativo, tareas y recordatorios locales.
- Portal del cliente: tickets y seguimiento.
- Dashboard ejecutivo con accesos rapidos y metricas.

## Stack tecnico

- SwiftUI
- Core Data
- AppKit
- EventKit
- UserNotifications
- AppleScript mediante NSAppleScript para integracion con Mail.app
- Proyecto Xcode generado con XcodeGen a partir de [project.yml](project.yml)

## Requisitos

- macOS 13 o superior
- Xcode 15 o superior
- Cuenta de correo corporativo configurada en Mail.app si se desea usar el modulo de Comunicacion

## Compilacion local

Abrir el proyecto en Xcode:

- [TalentoSostenible.xcodeproj](TalentoSostenible.xcodeproj)

O compilar por linea de comandos:

```bash
xcodebuild -project TalentoSostenible.xcodeproj -scheme TalentoSostenible -configuration Debug -sdk macosx CODE_SIGNING_ALLOWED=NO build
```

## Uso rapido

### Primer arranque

1. Abre [TalentoSostenible.xcodeproj](TalentoSostenible.xcodeproj) en Xcode.
2. Ejecuta la app sobre tu Mac.
3. Concede permisos de calendario y notificaciones cuando macOS los solicite.
4. Si vas a usar Comunicacion, deja antes operativa la cuenta corporativa en Mail.app.

### Flujo recomendado de demostracion

1. Revisa el Dashboard para ver accesos rapidos y metricas base.
2. En CRM, crea o revisa contactos, empresas, leads y oportunidades.
3. En Agenda, valida calendario, tareas y recordatorios.
4. En Finanzas, completa datos fiscales y de cobro antes de generar una factura.
5. En Comunicacion, selecciona la cuenta corporativa y prueba redaccion o respuesta desde Mail.app.
6. En Portal del cliente, revisa el circuito de tickets.

### Configuracion minima para facturacion

Antes de exportar facturas, conviene completar desde la app:

- Datos fiscales del emisor
- IBAN
- Titular de cuenta
- Entidad bancaria
- Condiciones de pago

### Configuracion minima para comunicacion

Antes de usar la bandeja corporativa, conviene verificar:

- Cuenta corporativa anadida en Mail.app
- Correo corporativo configurado en la app
- Firma corporativa revisada en la configuracion interna

## Estructura principal

- [TalentoSostenible/ContentView.swift](TalentoSostenible/ContentView.swift): navegacion principal y sidebar jerarquico.
- [TalentoSostenible/TalentoSostenibleApp.swift](TalentoSostenible/TalentoSostenibleApp.swift): arranque de la app y recordatorios iniciales.
- [TalentoSostenible/Models](TalentoSostenible/Models): persistencia y modelo Core Data.
- [TalentoSostenible/Services](TalentoSostenible/Services): servicios de inteligencia CRM, correo y notificaciones.
- [TalentoSostenible/Views](TalentoSostenible/Views): vistas funcionales del producto.

## Modulos principales

### CRM

- Gestion de contactos y empresas
- Leads y oportunidades
- Pipeline comercial
- Registro de actividades
- Campanas
- Automatizaciones basicas por trigger

### Finanzas

- Centro financiero con resumen
- Facturacion con plantilla PDF personalizada
- Configuracion editable de datos fiscales y de cobro desde la app
- Registro de gastos

### Comunicacion

- Deteccion de cuentas disponibles en Mail.app
- Lectura de mensajes
- Carga de cuerpo del correo
- Redaccion y respuesta mediante Mail.app
- Firma corporativa configurable desde la app

### Agenda y operaciones

- Calendario nativo
- Tareas por estado
- Recordatorios locales
- Tickets de soporte

## Integraciones nativas

- Mail.app para correo corporativo
- FaceTime y llamadas mediante URLs del sistema
- Calendario mediante EventKit
- Notificaciones locales de seguimiento

## Capturas

Las capturas del producto todavia no estan versionadas dentro del repositorio. La documentacion ya queda preparada para anadirlas en una siguiente iteracion, idealmente con este bloque:

- Dashboard ejecutivo
- Centro de Finanzas con facturacion
- Comunicacion con Mail corporativo
- CRM con pipeline y oportunidades
- Agenda con calendario y tareas

Cuando existan imagenes reales del producto, conviene guardarlas en una carpeta dedicada dentro del repositorio y enlazarlas desde esta seccion.

## Limitaciones actuales del prototipo

- La seccion de Comunicacion depende de que la cuenta corporativa autentique correctamente en Mail.app del Mac.
- La automatizacion es funcional pero todavia basica y centrada en triggers y acciones simples.
- El tablero de tareas no incluye aun drag and drop real.
- El almacenamiento es local mediante Core Data; no hay sincronizacion remota ni backend.

## Validacion reciente

La app ha sido validada recientemente con compilacion local correcta usando:

```bash
xcodebuild -project TalentoSostenible.xcodeproj -scheme TalentoSostenible -configuration Debug -sdk macosx CODE_SIGNING_ALLOWED=NO build
```

## Proximo paso recomendado

Como siguiente iteracion, conviene completar una de estas lineas:

1. Documentacion funcional y capturas del producto.
2. Endurecimiento del flujo de correo corporativo.
3. Publicacion de roadmap y pendientes del prototipo.