# Genera el Manual de Usuario del CMMS Macsa como .docx real,
# construyendo el paquete OOXML (ZIP + XML) directamente, sin abrir Word.
# Salida: docs\Manual_Usuario_CMMS_Macsa.docx

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$root    = (Resolve-Path "$PSScriptRoot\..").Path
$outPath = Join-Path $root 'docs\Manual_Usuario_CMMS_Macsa.docx'
$tmpDir  = Join-Path $env:TEMP ("manual_cmms_" + [Guid]::NewGuid().ToString("N"))

New-Item -ItemType Directory -Path $tmpDir | Out-Null
New-Item -ItemType Directory -Path (Join-Path $tmpDir '_rels') | Out-Null
New-Item -ItemType Directory -Path (Join-Path $tmpDir 'word') | Out-Null
New-Item -ItemType Directory -Path (Join-Path $tmpDir 'word\_rels') | Out-Null
New-Item -ItemType Directory -Path (Join-Path $tmpDir 'docProps') | Out-Null

# =========================================================================
# Modelo del documento: lista de bloques declarativos.
# Cada bloque es un hashtable con Type + campos.
# Types: Title, H1, H2, H3, P, Bullet, Number, Figure, Note, Table, PageBreak, Blank, TOC, Centered
# =========================================================================
$blocks = New-Object System.Collections.ArrayList

function Add-Block($h) { [void]$blocks.Add($h) }

# ---------- PORTADA ----------
1..6 | ForEach-Object { Add-Block @{Type='Blank'} }
Add-Block @{Type='Centered'; Text='Grupo Macsa'; Italic=$true; Size=24}
Add-Block @{Type='Blank'}
Add-Block @{Type='Centered'; Text='Manual de Usuario'; Bold=$true; Size=48}
Add-Block @{Type='Centered'; Text='Sistema CMMS Macsa'; Bold=$true; Size=36}
Add-Block @{Type='Centered'; Text='Gestion Computarizada de Mantenimiento'; Italic=$true; Size=28}
1..10 | ForEach-Object { Add-Block @{Type='Blank'} }
Add-Block @{Type='Centered'; Text='Version 1.0 - Edicion para Usuario Final'; Size=22}
Add-Block @{Type='Centered'; Text=('Fecha de emision: ' + (Get-Date -Format 'MMMM yyyy')); Size=22}
Add-Block @{Type='Blank'}
Add-Block @{Type='Centered'; Text='Documento correspondiente a la version en desarrollo activo del sistema.'; Italic=$true; Size=20}
Add-Block @{Type='Centered'; Text='Algunas funciones podran ampliarse o modificarse en versiones posteriores.'; Italic=$true; Size=20}
Add-Block @{Type='PageBreak'}

# ---------- CONTROL DE VERSIONES ----------
Add-Block @{Type='H1'; Text='Control de versiones'}
Add-Block @{Type='P'; Text='El presente documento se actualizara conforme el sistema evolucione. La siguiente tabla registra las revisiones oficiales del manual.'}
Add-Block @{Type='Table'; Rows=@(
    @('Version','Fecha','Autor','Descripcion del cambio'),
    @('1.0','', '', 'Emision inicial del manual de usuario final.'),
    @('','', '', ''),
    @('','', '', '')
)}
Add-Block @{Type='H2'; Text='Aviso importante'}
Add-Block @{Type='P'; Text='El sistema CMMS Macsa se encuentra en proceso de mejora continua. Las capturas de pantalla incluidas en este manual reflejan la version vigente al momento de su elaboracion. Ante cualquier diferencia visual menor entre lo mostrado en pantalla y lo documentado, la funcionalidad general se mantiene equivalente.'}
Add-Block @{Type='PageBreak'}

# ---------- INDICE ----------
Add-Block @{Type='H1'; Text='Indice'}
Add-Block @{Type='TOC'}
Add-Block @{Type='PageBreak'}

# ---------- 1. INTRODUCCION ----------
Add-Block @{Type='H1'; Text='1. Introduccion'}
Add-Block @{Type='H2'; Text='1.1 Proposito del manual'}
Add-Block @{Type='P'; Text='Este manual tiene como finalidad orientar al usuario final en la operacion del sistema CMMS Macsa, una aplicacion destinada a la gestion computarizada del mantenimiento industrial. En el se describen, de forma clara y ordenada, las funciones disponibles, los pasos requeridos para ejecutarlas y las buenas practicas asociadas a su uso.'}

Add-Block @{Type='H2'; Text='1.2 Alcance'}
Add-Block @{Type='P'; Text='El documento cubre las funcionalidades accesibles a los perfiles de uso cotidiano del sistema: consulta de informacion, registro de reportes, gestion de ordenes de trabajo, planificacion preventiva y consulta del historial de eventos. Las funciones de administracion tecnica del sistema (gestion de usuarios y aprobacion de bajas de activos) se reservan a un manual complementario dirigido a administradores.'}

Add-Block @{Type='H2'; Text='1.3 Publico objetivo'}
Add-Block @{Type='P'; Text='El manual esta dirigido a los siguientes perfiles de usuario:'}
Add-Block @{Type='Bullet'; Text='Jefes de mantenimiento y supervisores, responsables de la planificacion y seguimiento de las actividades tecnicas.'}
Add-Block @{Type='Bullet'; Text='Reportadores, encargados de comunicar la ocurrencia de averias desde las areas operativas.'}
Add-Block @{Type='Bullet'; Text='Lectores, usuarios con acceso de consulta a la informacion del sistema.'}

Add-Block @{Type='H2'; Text='1.4 Convenciones utilizadas'}
Add-Block @{Type='P'; Text='Con el fin de facilitar la lectura, el manual emplea las siguientes convenciones tipograficas y visuales:'}
Add-Block @{Type='Bullet'; Text='Los nombres de botones, menus y campos aparecen en negrita, por ejemplo: Ingresar.'}
Add-Block @{Type='Bullet'; Text='Las secuencias de navegacion se representan con el simbolo mayor que, por ejemplo: Menu lateral > Activos > Nuevo.'}
Add-Block @{Type='Bullet'; Text='Las capturas de pantalla se numeran de forma consecutiva bajo el rotulo Figura N, acompanadas de una descripcion breve.'}
Add-Block @{Type='Bullet'; Text='Los cuadros de nota resaltan advertencias, recordatorios o consideraciones tecnicas relevantes.'}
Add-Block @{Type='PageBreak'}

# ---------- 2. DESCRIPCION GENERAL ----------
Add-Block @{Type='H1'; Text='2. Descripcion general del sistema'}
Add-Block @{Type='H2'; Text='2.1 Que es el CMMS Macsa'}
Add-Block @{Type='P'; Text='El CMMS Macsa es un sistema computarizado de gestion del mantenimiento (Computerized Maintenance Management System) desarrollado para centralizar la informacion tecnica de los activos productivos de la empresa. Permite administrar el inventario jerarquico de equipos, planificar mantenimientos preventivos, registrar y dar seguimiento a averias, emitir ordenes de trabajo y consultar el historial completo de eventos asociados a cada activo.'}

Add-Block @{Type='H2'; Text='2.2 Modulos principales'}
Add-Block @{Type='P'; Text='El sistema esta organizado en modulos funcionales agrupados por su ambito de uso:'}
Add-Block @{Type='Bullet'; Text='Panel de indicadores (Dashboard): visualizacion consolidada de metricas operativas.'}
Add-Block @{Type='Bullet'; Text='Activos: gestion del inventario jerarquico de equipos, subequipos, partes y subpartes.'}
Add-Block @{Type='Bullet'; Text='Ordenes de Trabajo: registro y seguimiento de intervenciones de mantenimiento.'}
Add-Block @{Type='Bullet'; Text='Mantenimiento Preventivo: definicion y programacion de planes preventivos.'}
Add-Block @{Type='Bullet'; Text='Disponibilidad Operativa: registro y analisis de reportes de operacion.'}
Add-Block @{Type='Bullet'; Text='Reporte de Averias: comunicacion de fallas desde las areas operativas.'}
Add-Block @{Type='Bullet'; Text='Kardex e Historial: consulta cronologica de todos los eventos del sistema.'}

Add-Block @{Type='H2'; Text='2.3 Requisitos tecnicos'}
Add-Block @{Type='P'; Text='El sistema es una aplicacion multiplataforma. Para su uso se recomienda:'}
Add-Block @{Type='Bullet'; Text='Navegador web actualizado: Google Chrome o Microsoft Edge en su version mas reciente.'}
Add-Block @{Type='Bullet'; Text='Alternativamente, aplicacion de escritorio para Windows proporcionada por el area de sistemas.'}
Add-Block @{Type='Bullet'; Text='Conexion estable a Internet o a la red interna de la empresa.'}
Add-Block @{Type='Bullet'; Text='Resolucion de pantalla minima recomendada: 1366 x 768 pixeles.'}
Add-Block @{Type='Bullet'; Text='Credenciales de acceso (usuario y contrasena) proporcionadas por el administrador del sistema.'}
Add-Block @{Type='Figure'; N=1; Caption='Vista general del sistema CMMS Macsa (Dashboard principal).'}
Add-Block @{Type='PageBreak'}

# ---------- 3. ACCESO AL SISTEMA ----------
Add-Block @{Type='H1'; Text='3. Acceso al sistema'}
Add-Block @{Type='H2'; Text='3.1 Inicio de sesion'}
Add-Block @{Type='P'; Text='Para acceder al sistema, el usuario debe contar con credenciales previamente creadas por el administrador. Los pasos para iniciar sesion son los siguientes:'}
Add-Block @{Type='Number'; Text='Abrir el navegador o la aplicacion de escritorio del CMMS Macsa.'}
Add-Block @{Type='Number'; Text='En la pantalla de bienvenida, escribir el nombre de usuario en el campo correspondiente.'}
Add-Block @{Type='Number'; Text='Ingresar la contrasena asignada en el campo Contrasena.'}
Add-Block @{Type='Number'; Text='Presionar el boton Ingresar.'}
Add-Block @{Type='Figure'; N=2; Caption='Pantalla de inicio de sesion.'}
Add-Block @{Type='Figure'; N=3; Caption='Ingreso de credenciales y boton Ingresar.'}

Add-Block @{Type='H2'; Text='3.2 Bloqueo por intentos fallidos'}
Add-Block @{Type='P'; Text='Como medida de seguridad, el sistema bloquea temporalmente el acceso de una cuenta luego de cinco intentos fallidos consecutivos. Durante el bloqueo, que tiene una duracion aproximada de cinco minutos, no sera posible iniciar sesion con esa cuenta, aun ingresando la contrasena correcta. Transcurrido el tiempo, el acceso se habilita nuevamente de forma automatica.'}
Add-Block @{Type='Figure'; N=4; Caption='Mensaje de cuenta bloqueada temporalmente.'}

Add-Block @{Type='H2'; Text='3.3 Cambio de contrasena obligatorio'}
Add-Block @{Type='P'; Text='Cuando un usuario ingresa por primera vez, o cuando el administrador restablece su contrasena, el sistema exige el cambio inmediato de la clave temporal antes de permitir el acceso al resto de las funciones. En esa pantalla se debe ingresar la nueva contrasena y confirmarla.'}
Add-Block @{Type='Figure'; N=5; Caption='Pantalla de cambio de contrasena obligatorio.'}

Add-Block @{Type='H2'; Text='3.4 Solicitud de restablecimiento de contrasena'}
Add-Block @{Type='P'; Text='Si el usuario ha olvidado su contrasena, puede solicitar su restablecimiento desde la propia pantalla de inicio de sesion, mediante la opcion correspondiente. El administrador recibira la solicitud y generara una contrasena temporal que sera comunicada al usuario por los canales internos.'}
Add-Block @{Type='Figure'; N=6; Caption='Dialogo para solicitar restablecimiento de contrasena.'}

Add-Block @{Type='H2'; Text='3.5 Cambio voluntario de contrasena'}
Add-Block @{Type='P'; Text='En cualquier momento, un usuario autenticado puede modificar su propia contrasena desde el menu lateral, seleccionando la opcion Cambiar mi Contrasena. Se abrira un dialogo donde debera indicar la contrasena actual y la nueva contrasena deseada.'}
Add-Block @{Type='Figure'; N=7; Caption='Dialogo para cambiar la contrasena de forma voluntaria.'}

Add-Block @{Type='H2'; Text='3.6 Cierre de sesion'}
Add-Block @{Type='P'; Text='Al finalizar el uso del sistema se recomienda cerrar sesion, especialmente si el equipo es compartido. Esta accion se ejecuta desde el menu lateral, mediante el boton Cerrar sesion.'}
Add-Block @{Type='Figure'; N=8; Caption='Boton de cierre de sesion en el menu lateral.'}

Add-Block @{Type='Note'; Text='Nota de seguridad: la contrasena es personal e intransferible. No debe compartirse ni anotarse en lugares visibles. Ante cualquier sospecha de uso indebido, se recomienda cambiar la contrasena de inmediato.'}
Add-Block @{Type='PageBreak'}

# ---------- 4. INTERFAZ Y NAVEGACION ----------
Add-Block @{Type='H1'; Text='4. Interfaz principal y navegacion'}
Add-Block @{Type='H2'; Text='4.1 Estructura general de la pantalla'}
Add-Block @{Type='P'; Text='Una vez iniciada la sesion, la interfaz del sistema se organiza en tres zonas principales: el menu lateral izquierdo, el area central de trabajo y la barra superior de notificaciones e informacion del usuario.'}
Add-Block @{Type='Figure'; N=9; Caption='Estructura general de la interfaz: (1) menu lateral, (2) area de trabajo, (3) notificaciones, (4) usuario activo.'}

Add-Block @{Type='H2'; Text='4.2 Menu lateral'}
Add-Block @{Type='P'; Text='El menu lateral agrupa el acceso a los modulos del sistema en cuatro secciones logicas. Las opciones visibles para cada usuario dependen del rol que tenga asignado.'}
Add-Block @{Type='Bullet'; Text='Operaciones y Control: acceso al Dashboard y a la Disponibilidad Operativa.'}
Add-Block @{Type='Bullet'; Text='Gestion de Mantenimiento: Activos, Ordenes de Trabajo, Mantenimiento Preventivo y Kardex.'}
Add-Block @{Type='Bullet'; Text='Incidencias y Averias: Reportar Averia, Mis Reportes y gestion de Reportes de Averias.'}
Add-Block @{Type='Bullet'; Text='Administracion del Sistema: opciones administrativas (reservadas al perfil de administrador).'}
Add-Block @{Type='Figure'; N=10; Caption='Menu lateral con las cuatro secciones desplegadas.'}

Add-Block @{Type='H2'; Text='4.3 Perfiles de usuario y accesos'}
Add-Block @{Type='P'; Text='El sistema define tres perfiles de uso cotidiano, cada uno con un alcance funcional distinto. La siguiente tabla resume los accesos por modulo:'}
Add-Block @{Type='Table'; Rows=@(
    @('Modulo','Jefe','Reportador','Lector'),
    @('Dashboard','Si','No','Si'),
    @('Activos','Consulta','No','Consulta'),
    @('Ordenes de Trabajo','Crear, ver, imprimir','No','Consulta'),
    @('Mantenimiento Preventivo','Gestion completa','No','Consulta'),
    @('Disponibilidad Operativa','Si','No','No'),
    @('Kardex / Historial','Si','No','Si'),
    @('Reportar Averia','No','Si','No'),
    @('Mis Reportes','No','Si','No'),
    @('Gestion de Averias','Si','No','Consulta')
)}
Add-Block @{Type='Note'; Text='Nota: si un modulo descrito en este manual no aparece en su menu lateral, significa que su perfil no cuenta con permisos para acceder a el. En caso de requerirlo, contacte al administrador del sistema.'}
Add-Block @{Type='PageBreak'}

# ---------- 5. MODULOS ----------
Add-Block @{Type='H1'; Text='5. Modulos del sistema'}

# 5.1
Add-Block @{Type='H2'; Text='5.1 Panel de indicadores (Dashboard)'}
Add-Block @{Type='P'; Text='Descripcion: el Dashboard es la pantalla de bienvenida del sistema. Presenta un conjunto de indicadores clave sobre el estado actual del mantenimiento: cantidad de activos operativos, averias abiertas, planes preventivos vigentes y ordenes de trabajo pendientes o en progreso.'}
Add-Block @{Type='P'; Text='Perfiles con acceso: Jefe y Lector.'}
Add-Block @{Type='P'; Text='Como acceder: menu lateral > Operaciones y Control > Dashboard.'}
Add-Block @{Type='Figure'; N=11; Caption='Panel de indicadores con las metricas principales del sistema.'}
Add-Block @{Type='P'; Text='Acciones disponibles:'}
Add-Block @{Type='Bullet'; Text='Consultar los indicadores actualizados del sistema.'}
Add-Block @{Type='Bullet'; Text='Navegar directamente a los modulos relacionados desde los propios indicadores.'}
Add-Block @{Type='Bullet'; Text='Actualizar la vista para obtener los ultimos valores registrados.'}

# 5.2 Activos
Add-Block @{Type='H2'; Text='5.2 Activos'}
Add-Block @{Type='P'; Text='Descripcion: el modulo Activos permite consultar el inventario jerarquico de los equipos de la planta. Cada activo se organiza segun su nivel: equipo, subequipo, parte y subparte, y se asocia a un area o centro de costo especifico.'}
Add-Block @{Type='P'; Text='Perfiles con acceso: Jefe y Lector (consulta). Las operaciones de alta, edicion, transferencia y baja estan reservadas al perfil de administrador.'}
Add-Block @{Type='P'; Text='Como acceder: menu lateral > Gestion de Mantenimiento > Activos.'}

Add-Block @{Type='H3'; Text='5.2.1 Seleccion de area'}
Add-Block @{Type='P'; Text='Al ingresar al modulo se presenta la lista de areas o centros de costo disponibles. El usuario debe seleccionar el area cuyos activos desea consultar.'}
Add-Block @{Type='Figure'; N=12; Caption='Pantalla de seleccion de area.'}

Add-Block @{Type='H3'; Text='5.2.2 Listado de activos'}
Add-Block @{Type='P'; Text='Una vez seleccionada un area, se muestra el listado de los activos asociados. Desde este listado es posible utilizar el campo de busqueda para localizar un activo por su codigo o descripcion.'}
Add-Block @{Type='Figure'; N=13; Caption='Listado de activos de un area.'}

Add-Block @{Type='H3'; Text='5.2.3 Detalle de un activo'}
Add-Block @{Type='P'; Text='Al seleccionar un activo se accede a su ficha de detalle, donde se muestra la informacion tecnica completa, la jerarquia de sus componentes (subequipos, partes y subpartes) y el historial de eventos asociados.'}
Add-Block @{Type='Figure'; N=14; Caption='Ficha de detalle de un activo con su jerarquia de componentes.'}

Add-Block @{Type='H3'; Text='5.2.4 Generacion de reportes de inventario'}
Add-Block @{Type='P'; Text='El sistema permite generar reportes del inventario de activos en formato PDF o Excel. Para ello se utiliza el dialogo de filtros de reporte, donde se seleccionan los criterios deseados (area, nivel jerarquico, estado, entre otros).'}
Add-Block @{Type='Figure'; N=15; Caption='Dialogo de configuracion del reporte de inventario.'}
Add-Block @{Type='Figure'; N=16; Caption='Vista previa del reporte de inventario generado.'}

# 5.3 OTs
Add-Block @{Type='H2'; Text='5.3 Ordenes de Trabajo'}
Add-Block @{Type='P'; Text='Descripcion: el modulo de Ordenes de Trabajo (OT) centraliza el registro, seguimiento y cierre de las intervenciones de mantenimiento realizadas sobre los activos. Cada OT recibe un correlativo unico con el formato OT-Anio-Numero.'}
Add-Block @{Type='P'; Text='Perfiles con acceso: Jefe (crear, ver, actualizar, imprimir) y Lector (consulta).'}
Add-Block @{Type='P'; Text='Como acceder: menu lateral > Gestion de Mantenimiento > Ordenes de Trabajo.'}

Add-Block @{Type='H3'; Text='5.3.1 Consulta de ordenes de trabajo'}
Add-Block @{Type='P'; Text='El listado principal muestra todas las OT registradas, con su codigo, activo asociado, estado y fecha. Se pueden aplicar filtros por estado o por activo para acotar la busqueda.'}
Add-Block @{Type='Figure'; N=17; Caption='Listado de ordenes de trabajo.'}

Add-Block @{Type='H3'; Text='5.3.2 Creacion de una nueva orden de trabajo'}
Add-Block @{Type='P'; Text='Para registrar una nueva OT, seleccionar el boton Nueva Orden de Trabajo y completar el formulario con la informacion requerida: activo, tipo de mantenimiento, descripcion, prioridad y responsable asignado.'}
Add-Block @{Type='Number'; Text='Presionar el boton Nueva Orden de Trabajo.'}
Add-Block @{Type='Number'; Text='Seleccionar el activo sobre el que se realizara la intervencion.'}
Add-Block @{Type='Number'; Text='Indicar el tipo de mantenimiento y la prioridad.'}
Add-Block @{Type='Number'; Text='Describir el trabajo a realizar y asignar el responsable.'}
Add-Block @{Type='Number'; Text='Guardar la orden mediante el boton Registrar.'}
Add-Block @{Type='Figure'; N=18; Caption='Formulario de creacion de una nueva orden de trabajo.'}

Add-Block @{Type='H3'; Text='5.3.3 Seguimiento y cierre de una OT'}
Add-Block @{Type='P'; Text='Desde la vista de detalle de cada OT es posible registrar el avance porcentual, actualizar observaciones y, finalmente, cerrar la orden una vez completada. Tambien se dispone de la opcion de cancelar la OT cuando corresponda, indicando el motivo.'}
Add-Block @{Type='Figure'; N=19; Caption='Vista de detalle y seguimiento de una orden de trabajo.'}
Add-Block @{Type='Figure'; N=20; Caption='Dialogo de cierre o cancelacion de la orden de trabajo.'}

Add-Block @{Type='H3'; Text='5.3.4 Impresion de la orden en PDF'}
Add-Block @{Type='P'; Text='El sistema permite generar la version imprimible de la OT en formato PDF, util para su distribucion o archivo fisico. La opcion esta disponible desde la barra de acciones de la vista de detalle.'}

# 5.4 Preventivo
Add-Block @{Type='H2'; Text='5.4 Mantenimiento Preventivo'}
Add-Block @{Type='P'; Text='Descripcion: este modulo permite definir los planes de mantenimiento preventivo por componentes, establecer su frecuencia y generar las ordenes de trabajo correspondientes, ya sea de forma individual o por lote. Los planes reciben un codigo unico con el formato PM-Anio-Numero.'}
Add-Block @{Type='P'; Text='Perfiles con acceso: Jefe (gestion completa) y Lector (consulta).'}
Add-Block @{Type='P'; Text='Como acceder: menu lateral > Gestion de Mantenimiento > Mantenimiento Preventivo.'}

Add-Block @{Type='H3'; Text='5.4.1 Consulta y definicion de planes'}
Add-Block @{Type='P'; Text='El modulo muestra el listado de planes preventivos vigentes. Desde alli se puede crear un nuevo plan, especificando el activo, los componentes involucrados, las tareas a realizar y la frecuencia con la que deben ejecutarse.'}
Add-Block @{Type='Figure'; N=21; Caption='Listado de planes de mantenimiento preventivo.'}
Add-Block @{Type='Figure'; N=22; Caption='Formulario de definicion de un plan preventivo por componentes.'}

Add-Block @{Type='H3'; Text='5.4.2 Generacion de OT preventiva individual'}
Add-Block @{Type='P'; Text='Cuando un plan preventivo alcanza su fecha de ejecucion, el sistema permite generar la orden de trabajo asociada de forma manual desde el dialogo correspondiente. La OT resultante quedara vinculada al plan de origen.'}
Add-Block @{Type='Figure'; N=23; Caption='Dialogo para generar una OT preventiva individual.'}

Add-Block @{Type='H3'; Text='5.4.3 Generacion de OTs preventivas por lote'}
Add-Block @{Type='P'; Text='Para agilizar la planificacion, el sistema ofrece la generacion masiva de ordenes preventivas correspondientes a varios planes en una sola operacion. Se seleccionan los planes deseados y se confirma la generacion.'}
Add-Block @{Type='Figure'; N=24; Caption='Dialogo de generacion por lote de OTs preventivas.'}

# 5.5 Disponibilidad
Add-Block @{Type='H2'; Text='5.5 Disponibilidad Operativa'}
Add-Block @{Type='P'; Text='Descripcion: el modulo de Disponibilidad Operativa permite registrar los reportes de operacion de los equipos y consultar las metricas de disponibilidad calculadas a partir de dicha informacion. Con ello se dispone de indicadores objetivos sobre el desempeno de los activos.'}
Add-Block @{Type='P'; Text='Perfiles con acceso: Jefe.'}
Add-Block @{Type='P'; Text='Como acceder: menu lateral > Operaciones y Control > Disponibilidad Operativa.'}

Add-Block @{Type='H3'; Text='5.5.1 Listado de reportes de operacion'}
Add-Block @{Type='P'; Text='Se presenta el listado de reportes existentes, con la posibilidad de filtrar por area y periodo. Desde alli se accede a la edicion o consulta de cada reporte.'}
Add-Block @{Type='Figure'; N=25; Caption='Listado de reportes de disponibilidad operativa.'}

Add-Block @{Type='H3'; Text='5.5.2 Registro de un nuevo reporte'}
Add-Block @{Type='P'; Text='Para registrar un nuevo reporte se completa el formulario correspondiente, indicando el activo, el periodo, los tiempos de operacion y las paradas registradas.'}
Add-Block @{Type='Figure'; N=26; Caption='Formulario de registro de un reporte de operacion.'}

Add-Block @{Type='H3'; Text='5.5.3 Consulta de metricas de disponibilidad'}
Add-Block @{Type='P'; Text='A partir de los reportes registrados, el sistema calcula automaticamente las metricas de disponibilidad, permitiendo su consulta desde la vista dedicada.'}
Add-Block @{Type='Figure'; N=27; Caption='Vista de metricas de disponibilidad operativa.'}

# 5.6 Reportar averia
Add-Block @{Type='H2'; Text='5.6 Reportar Averia'}
Add-Block @{Type='P'; Text='Descripcion: este modulo permite al personal operativo comunicar la ocurrencia de una averia o falla en un equipo. El reporte queda registrado en el sistema y es notificado al personal de mantenimiento para su atencion.'}
Add-Block @{Type='P'; Text='Perfiles con acceso: Reportador.'}
Add-Block @{Type='P'; Text='Como acceder: menu lateral > Incidencias y Averias > Reportar Averia.'}

Add-Block @{Type='H3'; Text='5.6.1 Registro de una averia'}
Add-Block @{Type='Number'; Text='Seleccionar el area y el activo afectado por la averia.'}
Add-Block @{Type='Number'; Text='Describir con claridad la falla observada.'}
Add-Block @{Type='Number'; Text='Adjuntar, opcionalmente, evidencia visual (foto) del problema.'}
Add-Block @{Type='Number'; Text='Presionar el boton Enviar reporte.'}
Add-Block @{Type='Figure'; N=28; Caption='Formulario de reporte de averia.'}
Add-Block @{Type='Figure'; N=29; Caption='Confirmacion de reporte de averia enviado.'}
Add-Block @{Type='Note'; Text='Recomendacion: al describir la averia, sea especifico. Indique que estaba haciendo el equipo, que sintoma presento y si existen ruidos, olores o signos visibles asociados. Una descripcion clara acelera el diagnostico y la reparacion.'}

# 5.7 Mis Reportes
Add-Block @{Type='H2'; Text='5.7 Mis Reportes'}
Add-Block @{Type='P'; Text='Descripcion: en este modulo el usuario reportador puede consultar el estado de todos los reportes de averia que ha registrado. El sistema notifica en tiempo real cuando un reporte cambia de estado (aprobado, rechazado, convertido en orden de trabajo).'}
Add-Block @{Type='P'; Text='Perfiles con acceso: Reportador.'}
Add-Block @{Type='P'; Text='Como acceder: menu lateral > Incidencias y Averias > Mis Reportes.'}
Add-Block @{Type='Figure'; N=30; Caption='Listado de reportes de averia registrados por el usuario.'}

# 5.8 Gestion averias
Add-Block @{Type='H2'; Text='5.8 Gestion de Reportes de Averias'}
Add-Block @{Type='P'; Text='Descripcion: este modulo permite al personal de mantenimiento revisar los reportes de averia recibidos, aprobarlos, rechazarlos con justificacion o convertirlos directamente en ordenes de trabajo para su atencion.'}
Add-Block @{Type='P'; Text='Perfiles con acceso: Jefe (gestion completa) y Lector (consulta).'}
Add-Block @{Type='P'; Text='Como acceder: menu lateral > Incidencias y Averias > Reportes de Averias.'}

Add-Block @{Type='H3'; Text='5.8.1 Consulta de reportes recibidos'}
Add-Block @{Type='P'; Text='El listado presenta todos los reportes ingresados, con su estado, fecha, activo y descripcion. Se pueden aplicar filtros para localizar reportes especificos.'}
Add-Block @{Type='Figure'; N=31; Caption='Listado de reportes de averia recibidos.'}

Add-Block @{Type='H3'; Text='5.8.2 Aprobacion de un reporte'}
Add-Block @{Type='P'; Text='Al aprobar un reporte, el sistema habilita la generacion de la orden de trabajo correspondiente para atender la averia comunicada.'}
Add-Block @{Type='Figure'; N=32; Caption='Dialogo de aprobacion de un reporte de averia.'}

Add-Block @{Type='H3'; Text='5.8.3 Rechazo de un reporte'}
Add-Block @{Type='P'; Text='Cuando un reporte no procede, se debe rechazar indicando el motivo. Esta informacion queda registrada y es visible para el usuario que lo genero.'}
Add-Block @{Type='Figure'; N=33; Caption='Dialogo de rechazo de un reporte de averia con motivo.'}

# 5.9 Kardex
Add-Block @{Type='H2'; Text='5.9 Kardex e Historial'}
Add-Block @{Type='P'; Text='Descripcion: el modulo Kardex conserva el historial completo, en orden cronologico, de todos los eventos ocurridos en el sistema: alta de activos, modificaciones, traspasos, creacion y cierre de ordenes de trabajo, reportes de averia, entre otros. Es un registro de solo lectura y no admite modificacion posterior.'}
Add-Block @{Type='P'; Text='Perfiles con acceso: Jefe y Lector.'}
Add-Block @{Type='P'; Text='Como acceder: menu lateral > Gestion de Mantenimiento > Kardex / Historial.'}
Add-Block @{Type='Figure'; N=34; Caption='Consulta del historial de eventos en el Kardex.'}
Add-Block @{Type='P'; Text='Acciones disponibles:'}
Add-Block @{Type='Bullet'; Text='Consultar el historial completo de eventos del sistema.'}
Add-Block @{Type='Bullet'; Text='Filtrar los eventos por entidad, fecha o tipo de evento.'}
Add-Block @{Type='Bullet'; Text='Revisar los detalles de cada evento registrado.'}
Add-Block @{Type='PageBreak'}

# ---------- 6. FAQ ----------
Add-Block @{Type='H1'; Text='6. Preguntas frecuentes y solucion de problemas'}
Add-Block @{Type='P'; Text='A continuacion se listan las situaciones mas frecuentes que puede encontrar el usuario al utilizar el sistema, junto con la accion recomendada.'}
Add-Block @{Type='Table'; Rows=@(
    @('Situacion','Accion recomendada'),
    @('No puedo iniciar sesion.','Verifique que el usuario y la contrasena esten escritos correctamente, respetando mayusculas y minusculas. Si el sistema indica que la cuenta esta bloqueada, espere cinco minutos o solicite el restablecimiento al administrador.'),
    @('No veo un modulo en el menu lateral.','Su perfil no cuenta con permisos para acceder a ese modulo. Contacte al administrador del sistema si requiere acceso.'),
    @('El sistema muestra un aviso de nueva version disponible.','Acepte la actualizacion cuando el sistema lo solicite. Es necesaria para mantener la aplicacion al dia y garantizar el correcto funcionamiento.'),
    @('Olvide mi contrasena.','Utilice la opcion de solicitud de restablecimiento en la pantalla de inicio de sesion. Un administrador generara una contrasena temporal.'),
    @('No puedo cerrar una orden de trabajo.','Verifique que el avance porcentual sea 100 por ciento y que se hayan completado los campos requeridos antes de intentar el cierre.'),
    @('No aparece un activo que deberia estar registrado.','Verifique que se encuentre en el area correcta. Si aun no aparece, consulte con el administrador si el activo se encuentra activo o si fue dado de baja.')
)}
Add-Block @{Type='PageBreak'}

# ---------- 7. GLOSARIO ----------
Add-Block @{Type='H1'; Text='7. Glosario de terminos'}
Add-Block @{Type='Table'; Rows=@(
    @('Termino','Definicion'),
    @('CMMS','Computerized Maintenance Management System. Sistema computarizado de gestion del mantenimiento.'),
    @('Activo','Bien fisico registrado en el sistema, sobre el cual se realizan actividades de mantenimiento.'),
    @('Area','Agrupacion logica de activos, usualmente asociada a un centro de costo o zona operativa.'),
    @('Jerarquia de activos','Estructura de niveles que organiza a los activos en equipos, subequipos, partes y subpartes.'),
    @('OT','Orden de Trabajo. Documento que registra una intervencion de mantenimiento sobre un activo.'),
    @('Plan preventivo (PM)','Programacion recurrente de tareas de mantenimiento destinadas a prevenir fallas.'),
    @('Kardex','Registro cronologico e inalterable de los eventos del sistema.'),
    @('Averia','Falla o desperfecto observado en un activo, comunicado mediante un reporte.'),
    @('Baja logica','Desactivacion de un activo en el sistema sin eliminarlo fisicamente, preservando su historial.'),
    @('Traspaso','Movimiento de un activo (junto con sus componentes) desde un area de origen hacia un area destino.')
)}
Add-Block @{Type='PageBreak'}

# ---------- 8. CONTACTO ----------
Add-Block @{Type='H1'; Text='8. Contacto y soporte'}
Add-Block @{Type='P'; Text='Ante cualquier inconveniente en el uso del sistema, consulta funcional o requerimiento de soporte tecnico, el usuario debe comunicarse con el area responsable dentro de Grupo Macsa.'}
Add-Block @{Type='Table'; Rows=@(
    @('Canal','Detalle'),
    @('Area responsable',''),
    @('Correo electronico',''),
    @('Telefono / Anexo',''),
    @('Horario de atencion','')
)}
Add-Block @{Type='P'; Text='Al reportar un inconveniente se recomienda incluir la siguiente informacion, con el fin de agilizar la atencion:'}
Add-Block @{Type='Bullet'; Text='Nombre de usuario y perfil.'}
Add-Block @{Type='Bullet'; Text='Modulo en el que ocurrio el problema.'}
Add-Block @{Type='Bullet'; Text='Descripcion detallada de la accion realizada y del resultado observado.'}
Add-Block @{Type='Bullet'; Text='Captura de pantalla del mensaje de error, si corresponde.'}
Add-Block @{Type='Bullet'; Text='Fecha y hora aproximada del incidente.'}

# =========================================================================
# Constructor OOXML
# =========================================================================
function XmlEscape([string]$s) {
    if ($null -eq $s) { return '' }
    return ($s -replace '&','&amp;' -replace '<','&lt;' -replace '>','&gt;' -replace '"','&quot;')
}

$sb = New-Object System.Text.StringBuilder

function W([string]$s) { [void]$sb.Append($s) }

# Encabezado documento
W '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
W '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
W '<w:body>'

function Emit-Paragraph {
    param(
        [string]$Style = '',
        [string]$Text = '',
        [switch]$Bold,
        [switch]$Italic,
        [int]$Size = 0,       # half-points
        [string]$Align = ''   # left/center/right/both
    )
    W '<w:p>'
    if ($Style -or $Align) {
        W '<w:pPr>'
        if ($Style) { W ('<w:pStyle w:val="' + $Style + '"/>') }
        if ($Align) { W ('<w:jc w:val="' + $Align + '"/>') }
        W '</w:pPr>'
    }
    if ($Text -ne '') {
        W '<w:r>'
        if ($Bold -or $Italic -or $Size -gt 0) {
            W '<w:rPr>'
            if ($Bold)   { W '<w:b/>' }
            if ($Italic) { W '<w:i/>' }
            if ($Size -gt 0) { W ('<w:sz w:val="' + $Size + '"/>') }
            W '</w:rPr>'
        }
        W ('<w:t xml:space="preserve">' + (XmlEscape $Text) + '</w:t>')
        W '</w:r>'
    }
    W '</w:p>'
}

function Emit-PageBreak {
    W '<w:p><w:r><w:br w:type="page"/></w:r></w:p>'
}

function Emit-Figure {
    param([int]$N, [string]$Caption)
    W '<w:p><w:pPr><w:jc w:val="center"/><w:spacing w:before="120" w:after="0"/><w:pBdr><w:top w:val="single" w:sz="6" w:space="6" w:color="BFBFBF"/><w:left w:val="single" w:sz="6" w:space="6" w:color="BFBFBF"/><w:bottom w:val="single" w:sz="6" w:space="6" w:color="BFBFBF"/><w:right w:val="single" w:sz="6" w:space="6" w:color="BFBFBF"/></w:pBdr></w:pPr>'
    W '<w:r><w:rPr><w:i/><w:color w:val="7F7F7F"/></w:rPr>'
    W ('<w:t xml:space="preserve">[ INSERTAR FIGURA ' + $N + ' AQUI ]</w:t>')
    W '</w:r></w:p>'
    W '<w:p><w:pPr><w:pStyle w:val="Caption"/><w:jc w:val="center"/></w:pPr>'
    W ('<w:r><w:rPr><w:i/><w:sz w:val="18"/></w:rPr><w:t xml:space="preserve">Figura ' + $N + '. ' + (XmlEscape $Caption) + '</w:t></w:r>')
    W '</w:p>'
}

function Emit-Note {
    param([string]$Text)
    W '<w:p><w:pPr><w:pBdr><w:top w:val="single" w:sz="6" w:space="4" w:color="8DB3E2"/><w:left w:val="single" w:sz="18" w:space="6" w:color="4472C4"/><w:bottom w:val="single" w:sz="6" w:space="4" w:color="8DB3E2"/><w:right w:val="single" w:sz="6" w:space="4" w:color="8DB3E2"/></w:pBdr><w:shd w:val="clear" w:color="auto" w:fill="EAF1FB"/><w:spacing w:before="120" w:after="120"/></w:pPr>'
    W ('<w:r><w:rPr><w:i/></w:rPr><w:t xml:space="preserve">' + (XmlEscape $Text) + '</w:t></w:r>')
    W '</w:p>'
}

function Emit-Table {
    param([object[][]]$Rows)
    W '<w:tbl>'
    W '<w:tblPr><w:tblW w:w="5000" w:type="pct"/><w:tblBorders>'
    W '<w:top w:val="single" w:sz="4" w:space="0" w:color="808080"/>'
    W '<w:left w:val="single" w:sz="4" w:space="0" w:color="808080"/>'
    W '<w:bottom w:val="single" w:sz="4" w:space="0" w:color="808080"/>'
    W '<w:right w:val="single" w:sz="4" w:space="0" w:color="808080"/>'
    W '<w:insideH w:val="single" w:sz="4" w:space="0" w:color="BFBFBF"/>'
    W '<w:insideV w:val="single" w:sz="4" w:space="0" w:color="BFBFBF"/>'
    W '</w:tblBorders><w:tblLayout w:type="autofit"/></w:tblPr>'
    $isFirst = $true
    foreach ($row in $Rows) {
        W '<w:tr>'
        foreach ($cell in $row) {
            W '<w:tc>'
            W '<w:tcPr>'
            if ($isFirst) { W '<w:shd w:val="clear" w:color="auto" w:fill="E7E6E6"/>' }
            W '</w:tcPr>'
            W '<w:p>'
            W '<w:r>'
            if ($isFirst) { W '<w:rPr><w:b/></w:rPr>' }
            W ('<w:t xml:space="preserve">' + (XmlEscape ([string]$cell)) + '</w:t>')
            W '</w:r>'
            W '</w:p>'
            W '</w:tc>'
        }
        W '</w:tr>'
        $isFirst = $false
    }
    W '</w:tbl>'
    # paragrafo vacio despues de tabla (requerido por Word)
    W '<w:p/>'
}

function Emit-TOC {
    # TOC via campo de instruccion. Al abrir en Word, se puede actualizar con F9 (click derecho -> Actualizar campos).
    W '<w:p><w:pPr><w:pStyle w:val="Normal"/></w:pPr>'
    W '<w:r><w:fldChar w:fldCharType="begin"/></w:r>'
    W '<w:r><w:instrText xml:space="preserve"> TOC \o "1-3" \h \z \u </w:instrText></w:r>'
    W '<w:r><w:fldChar w:fldCharType="separate"/></w:r>'
    W '<w:r><w:rPr><w:i/><w:color w:val="7F7F7F"/></w:rPr><w:t xml:space="preserve">Actualice esta tabla con clic derecho -&gt; Actualizar campos -&gt; Actualizar toda la tabla.</w:t></w:r>'
    W '<w:r><w:fldChar w:fldCharType="end"/></w:r>'
    W '</w:p>'
}

# Emitir bloques
foreach ($b in $blocks) {
    switch ($b.Type) {
        'Title'    { Emit-Paragraph -Style 'Title' -Text $b.Text -Align 'center' }
        'H1'       { Emit-Paragraph -Style 'Heading1' -Text $b.Text }
        'H2'       { Emit-Paragraph -Style 'Heading2' -Text $b.Text }
        'H3'       { Emit-Paragraph -Style 'Heading3' -Text $b.Text }
        'P'        { Emit-Paragraph -Style 'Normal'   -Text $b.Text -Align 'both' }
        'Bullet'   { Emit-Paragraph -Style 'ListBullet' -Text $b.Text }
        'Number'   { Emit-Paragraph -Style 'ListNumber' -Text $b.Text }
        'Note'     { Emit-Note $b.Text }
        'Figure'   { Emit-Figure -N $b.N -Caption $b.Caption }
        'Table'    { Emit-Table -Rows $b.Rows }
        'PageBreak'{ Emit-PageBreak }
        'Blank'    { Emit-Paragraph }
        'TOC'      { Emit-TOC }
        'Centered' {
            $size = if ($b.Size) { [int]$b.Size } else { 0 }
            $bold = [bool]$b.Bold
            $italic = [bool]$b.Italic
            Emit-Paragraph -Text $b.Text -Align 'center' -Size $size -Bold:$bold -Italic:$italic
        }
    }
}

# Seccion / margenes (A4, 2.5cm all around)
W '<w:sectPr>'
W '<w:pgSz w:w="11906" w:h="16838"/>'
W '<w:pgMar w:top="1417" w:right="1417" w:bottom="1417" w:left="1417" w:header="708" w:footer="708" w:gutter="0"/>'
W '<w:cols w:space="708"/>'
W '<w:docGrid w:linePitch="360"/>'
W '</w:sectPr>'

W '</w:body></w:document>'

$documentXml = $sb.ToString()

# =========================================================================
# Archivos auxiliares del paquete
# =========================================================================
$contentTypesXml = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml"  ContentType="application/xml"/>
  <Override PartName="/word/document.xml"      ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/word/styles.xml"        ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
  <Override PartName="/word/numbering.xml"     ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.numbering+xml"/>
  <Override PartName="/word/settings.xml"      ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.settings+xml"/>
  <Override PartName="/word/theme/theme1.xml"  ContentType="application/vnd.openxmlformats-officedocument.theme+xml"/>
  <Override PartName="/word/fontTable.xml"     ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.fontTable+xml"/>
  <Override PartName="/docProps/core.xml"      ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
  <Override PartName="/docProps/app.xml"       ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
</Types>
'@

$rootRelsXml = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
  <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
</Relationships>
'@

$docRelsXml = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles"    Target="styles.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/numbering" Target="numbering.xml"/>
  <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings"  Target="settings.xml"/>
  <Relationship Id="rId4" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme"     Target="theme/theme1.xml"/>
  <Relationship Id="rId5" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/fontTable" Target="fontTable.xml"/>
</Relationships>
'@

$stylesXml = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:docDefaults>
    <w:rPrDefault>
      <w:rPr>
        <w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:cs="Calibri"/>
        <w:sz w:val="22"/>
        <w:szCs w:val="22"/>
        <w:lang w:val="es-ES"/>
      </w:rPr>
    </w:rPrDefault>
    <w:pPrDefault>
      <w:pPr>
        <w:spacing w:after="120" w:line="288" w:lineRule="auto"/>
      </w:pPr>
    </w:pPrDefault>
  </w:docDefaults>

  <w:style w:type="paragraph" w:default="1" w:styleId="Normal">
    <w:name w:val="Normal"/>
  </w:style>

  <w:style w:type="paragraph" w:styleId="Title">
    <w:name w:val="Title"/>
    <w:basedOn w:val="Normal"/>
    <w:pPr><w:spacing w:before="240" w:after="240"/><w:jc w:val="center"/></w:pPr>
    <w:rPr><w:b/><w:sz w:val="48"/></w:rPr>
  </w:style>

  <w:style w:type="paragraph" w:styleId="Heading1">
    <w:name w:val="heading 1"/>
    <w:basedOn w:val="Normal"/>
    <w:next w:val="Normal"/>
    <w:qFormat/>
    <w:pPr>
      <w:keepNext/>
      <w:spacing w:before="360" w:after="180"/>
      <w:outlineLvl w:val="0"/>
      <w:pBdr><w:bottom w:val="single" w:sz="8" w:space="1" w:color="2E74B5"/></w:pBdr>
    </w:pPr>
    <w:rPr><w:b/><w:sz w:val="36"/><w:color w:val="1F3864"/></w:rPr>
  </w:style>

  <w:style w:type="paragraph" w:styleId="Heading2">
    <w:name w:val="heading 2"/>
    <w:basedOn w:val="Normal"/>
    <w:next w:val="Normal"/>
    <w:qFormat/>
    <w:pPr>
      <w:keepNext/>
      <w:spacing w:before="280" w:after="120"/>
      <w:outlineLvl w:val="1"/>
    </w:pPr>
    <w:rPr><w:b/><w:sz w:val="28"/><w:color w:val="2E74B5"/></w:rPr>
  </w:style>

  <w:style w:type="paragraph" w:styleId="Heading3">
    <w:name w:val="heading 3"/>
    <w:basedOn w:val="Normal"/>
    <w:next w:val="Normal"/>
    <w:qFormat/>
    <w:pPr>
      <w:keepNext/>
      <w:spacing w:before="200" w:after="80"/>
      <w:outlineLvl w:val="2"/>
    </w:pPr>
    <w:rPr><w:b/><w:sz w:val="24"/><w:color w:val="1F4E79"/></w:rPr>
  </w:style>

  <w:style w:type="paragraph" w:styleId="ListBullet">
    <w:name w:val="List Bullet"/>
    <w:basedOn w:val="Normal"/>
    <w:pPr>
      <w:numPr><w:ilvl w:val="0"/><w:numId w:val="1"/></w:numPr>
      <w:spacing w:after="60"/>
    </w:pPr>
  </w:style>

  <w:style w:type="paragraph" w:styleId="ListNumber">
    <w:name w:val="List Number"/>
    <w:basedOn w:val="Normal"/>
    <w:pPr>
      <w:numPr><w:ilvl w:val="0"/><w:numId w:val="2"/></w:numPr>
      <w:spacing w:after="60"/>
    </w:pPr>
  </w:style>

  <w:style w:type="paragraph" w:styleId="Caption">
    <w:name w:val="caption"/>
    <w:basedOn w:val="Normal"/>
    <w:pPr><w:spacing w:before="60" w:after="180"/><w:jc w:val="center"/></w:pPr>
    <w:rPr><w:i/><w:sz w:val="18"/><w:color w:val="595959"/></w:rPr>
  </w:style>
</w:styles>
'@

$numberingXml = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:numbering xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:abstractNum w:abstractNumId="0">
    <w:lvl w:ilvl="0">
      <w:start w:val="1"/>
      <w:numFmt w:val="bullet"/>
      <w:lvlText w:val="&#x2022;"/>
      <w:lvlJc w:val="left"/>
      <w:pPr><w:ind w:left="720" w:hanging="360"/></w:pPr>
      <w:rPr><w:rFonts w:ascii="Symbol" w:hAnsi="Symbol"/></w:rPr>
    </w:lvl>
  </w:abstractNum>
  <w:abstractNum w:abstractNumId="1">
    <w:lvl w:ilvl="0">
      <w:start w:val="1"/>
      <w:numFmt w:val="decimal"/>
      <w:lvlText w:val="%1."/>
      <w:lvlJc w:val="left"/>
      <w:pPr><w:ind w:left="720" w:hanging="360"/></w:pPr>
    </w:lvl>
  </w:abstractNum>
  <w:num w:numId="1"><w:abstractNumId w:val="0"/></w:num>
  <w:num w:numId="2"><w:abstractNumId w:val="1"/></w:num>
</w:numbering>
'@

$settingsXml = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:settings xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:zoom w:percent="100"/>
  <w:defaultTabStop w:val="708"/>
  <w:updateFields w:val="true"/>
  <w:compat>
    <w:compatSetting w:name="compatibilityMode" w:uri="http://schemas.microsoft.com/office/word" w:val="15"/>
  </w:compat>
</w:settings>
'@

$themeXml = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" name="Office">
  <a:themeElements>
    <a:clrScheme name="Office">
      <a:dk1><a:sysClr val="windowText" lastClr="000000"/></a:dk1>
      <a:lt1><a:sysClr val="window" lastClr="FFFFFF"/></a:lt1>
      <a:dk2><a:srgbClr val="44546A"/></a:dk2>
      <a:lt2><a:srgbClr val="E7E6E6"/></a:lt2>
      <a:accent1><a:srgbClr val="4472C4"/></a:accent1>
      <a:accent2><a:srgbClr val="ED7D31"/></a:accent2>
      <a:accent3><a:srgbClr val="A5A5A5"/></a:accent3>
      <a:accent4><a:srgbClr val="FFC000"/></a:accent4>
      <a:accent5><a:srgbClr val="5B9BD5"/></a:accent5>
      <a:accent6><a:srgbClr val="70AD47"/></a:accent6>
      <a:hlink><a:srgbClr val="0563C1"/></a:hlink>
      <a:folHlink><a:srgbClr val="954F72"/></a:folHlink>
    </a:clrScheme>
    <a:fontScheme name="Office">
      <a:majorFont><a:latin typeface="Calibri Light"/><a:ea typeface=""/><a:cs typeface=""/></a:majorFont>
      <a:minorFont><a:latin typeface="Calibri"/><a:ea typeface=""/><a:cs typeface=""/></a:minorFont>
    </a:fontScheme>
    <a:fmtScheme name="Office">
      <a:fillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:fillStyleLst>
      <a:lnStyleLst><a:ln w="6350"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln><a:ln w="12700"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln><a:ln w="19050"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln></a:lnStyleLst>
      <a:effectStyleLst><a:effectStyle><a:effectLst/></a:effectStyle><a:effectStyle><a:effectLst/></a:effectStyle><a:effectStyle><a:effectLst/></a:effectStyle></a:effectStyleLst>
      <a:bgFillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:bgFillStyleLst>
    </a:fmtScheme>
  </a:themeElements>
</a:theme>
'@

$fontTableXml = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:fonts xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:font w:name="Calibri"><w:panose1 w:val="020F0502020204030204"/><w:charset w:val="00"/><w:family w:val="swiss"/><w:pitch w:val="variable"/></w:font>
  <w:font w:name="Calibri Light"><w:panose1 w:val="020F0302020204030204"/><w:charset w:val="00"/><w:family w:val="swiss"/><w:pitch w:val="variable"/></w:font>
  <w:font w:name="Symbol"><w:panose1 w:val="05050102010706020507"/><w:charset w:val="02"/><w:family w:val="roman"/><w:pitch w:val="variable"/></w:font>
</w:fonts>
'@

$coreXml = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <dc:title>Manual de Usuario - CMMS Macsa</dc:title>
  <dc:creator>Grupo Macsa</dc:creator>
  <cp:lastModifiedBy>Grupo Macsa</cp:lastModifiedBy>
  <dcterms:created xsi:type="dcterms:W3CDTF">$(Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")</dcterms:created>
  <dcterms:modified xsi:type="dcterms:W3CDTF">$(Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")</dcterms:modified>
</cp:coreProperties>
"@

$appXml = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">
  <Application>CMMS Macsa Manual Builder</Application>
</Properties>
'@

# =========================================================================
# Escribir archivos y comprimir
# =========================================================================
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Save-Text($path, $content) {
    [System.IO.File]::WriteAllText($path, $content, $utf8NoBom)
}

Save-Text (Join-Path $tmpDir '[Content_Types].xml') $contentTypesXml
Save-Text (Join-Path $tmpDir '_rels\.rels') $rootRelsXml
Save-Text (Join-Path $tmpDir 'word\_rels\document.xml.rels') $docRelsXml
Save-Text (Join-Path $tmpDir 'word\document.xml') $documentXml
Save-Text (Join-Path $tmpDir 'word\styles.xml') $stylesXml
Save-Text (Join-Path $tmpDir 'word\numbering.xml') $numberingXml
Save-Text (Join-Path $tmpDir 'word\settings.xml') $settingsXml
New-Item -ItemType Directory -Path (Join-Path $tmpDir 'word\theme') | Out-Null
Save-Text (Join-Path $tmpDir 'word\theme\theme1.xml') $themeXml
Save-Text (Join-Path $tmpDir 'word\fontTable.xml') $fontTableXml
Save-Text (Join-Path $tmpDir 'docProps\core.xml') $coreXml
Save-Text (Join-Path $tmpDir 'docProps\app.xml') $appXml

if (Test-Path -LiteralPath $outPath) { Remove-Item -LiteralPath $outPath -Force }

# ZIP con niveles y estructura correcta (docx no requiere que [Content_Types] este primero, pero es buena practica)
[System.IO.Compression.ZipFile]::CreateFromDirectory($tmpDir, $outPath, [System.IO.Compression.CompressionLevel]::Optimal, $false)

Remove-Item -LiteralPath $tmpDir -Recurse -Force
Write-Host "OK -> $outPath"
Write-Host ("Tamano: " + [Math]::Round((Get-Item $outPath).Length / 1KB, 1) + " KB")
