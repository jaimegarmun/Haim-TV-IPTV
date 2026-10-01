import 'package:flutter/material.dart';
import 'package:open_tv/l10n/l10n.dart';
import 'package:open_tv/native_bridge.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

const _whatsNewEn = '''
New in 1.0.3:

- PC: double click goes fullscreen without pausing, and clicking the seek
  bar or the back arrow no longer plays or pauses the video
- The volume of the player is remembered
- Live channels buffer better on PC; if they still stutter, turn off
  "Rewind live channels" in Settings
- Search bar inside folders
- You can rename a source you already added
- PC: the window opens where and how you left it
- Windows: proper installer (.exe)

New in 1.0.2:

- Spanish language: choose it in Settings > Language
- TV: new Search screen with a QWERTY keyboard made for the remote
- TV: the search bar of every list opens the QWERTY keyboard too
- Linux: the app icon now shows when pinned to the taskbar

New in 1.0.1:

- Haim TV checks for updates on start and can install them for you
- Channels / Movies / Series filter at the top of every list
- TV remote: holding OK opens the options menu again (folders, etc.)

Welcome to Haim TV! Here's what it can do:

- Download movies and episodes to watch offline
- Resume where you left off, with a tick on watched episodes
- Live TV folders by network and country (TV mode)
- Your own folders inside Favorites
- Rewind live channels on PC (timeshift bar)
- Double tap the sides to skip 10 s on mobile
- Keyboard shortcuts and volume indicator on PC
- Right click or long press any item for more options

Found a problem? Report it on GitHub from any error message.
''';

const _whatsNewEs = '''
Novedades de la 1.0.3:

- PC: el doble clic pasa a pantalla completa sin pausar, y pulsar la barra
  de tiempo o la flecha de volver ya no pausa ni reanuda el vídeo
- Se recuerda el volumen del reproductor
- Los directos se almacenan mejor en PC; si aun así se entrecortan,
  desactiva "Retroceder en canales en directo" en Ajustes
- Barra de búsqueda dentro de las carpetas
- Puedes cambiar el nombre de una fuente ya añadida
- PC: la ventana se abre donde y como la dejaste
- Windows: instalador propio (.exe)

Novedades de la 1.0.2:

- Idioma español: elígelo en Ajustes > Idioma
- TV: nueva pantalla de búsqueda con un teclado QWERTY pensado para el mando
- TV: la barra de búsqueda de las listas también abre el teclado QWERTY
- Linux: el icono de la app aparece al anclarla a la barra de tareas

Novedades de la 1.0.1:

- Haim TV busca actualizaciones al arrancar y puede instalarlas por ti
- Filtro Canales / Películas / Series arriba de cada lista
- Mando de la tele: mantener OK vuelve a abrir el menú de opciones (carpetas, etc.)

¡Bienvenido a Haim TV! Esto es lo que puede hacer:

- Descargar películas y episodios para verlos sin conexión
- Continuar donde lo dejaste, con una marca en los episodios vistos
- Carpetas de TV en directo por cadena y país (modo TV)
- Tus propias carpetas dentro de Favoritos
- Retroceder en los canales en directo en PC (barra de timeshift)
- Doble toque en los lados para saltar 10 s en el móvil
- Atajos de teclado e indicador de volumen en PC
- Clic derecho o pulsación larga en cualquier elemento para ver más opciones

¿Has encontrado un problema? Infórmanos en GitHub desde cualquier mensaje de error.
''';

class WhatsNewModal extends StatelessWidget {
  final String version;
  const WhatsNewModal({super.key, required this.version});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(tr("What's new: update {version}", {"version": version})),
      actions: [
        TextButton(
          onPressed: () async {
            await launchUrl(
              Uri.parse(
                "https://github.com/jaimegarmun/Haim-TV-IPTV/releases",
              ),
              mode: LaunchMode.externalApplication,
            );
            if (!context.mounted) return;
            Navigator.pop(context, false);
          },
          child: Text(tr("Releases")),
        ),
        TextButton(
          autofocus: true,
          onPressed: () async {
            await NativeBridge.instance.updateLastSeenVersion(
              (await PackageInfo.fromPlatform()).version,
            );
            if (!context.mounted) return;
            Navigator.pop(context, true);
          },
          child: Text(tr("Don't show again")),
        ),
      ],
      content: Scrollbar(
        thumbVisibility: true,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Text(
              L10n.instance.code == "es" ? _whatsNewEs : _whatsNewEn,
            ),
          ),
        ),
      ),
    );
  }
}
