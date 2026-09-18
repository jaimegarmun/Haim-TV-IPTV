<p align="center">
  <img src="flutter/assets/icon.png" width="160" alt="Haim TV" />
</p>

<h1 align="center">Haim TV</h1>

<p align="center">
  Reproductor IPTV sencillo y rápido para <b>Android, Android TV, Windows y Linux</b>.<br/>
  Compatible con listas <b>M3U</b> y cuentas <b>Xtream Codes</b>: canales en directo, películas y series.
</p>

<p align="center">
  <a href="https://github.com/jaimegarmun/Haim-TV-IPTV/releases/latest"><b>⬇ Descargar la última versión</b></a>
</p>

## Funciones

- **Descargas** de películas y episodios para verlos sin conexión, en la carpeta que elijas.
- **Continuar viendo**: cada película o episodio sigue donde lo dejaste, y los capítulos vistos llevan un ✓.
- **Carpetas en Favoritos**: organiza tus canales, películas y series como quieras.
- **Modo TV** para Android TV (y para PC): carpetas automáticas por cadena (Movistar+, RTVE, Atresmedia…) y por país.
- **Directo con marcha atrás** en PC: pausa y rebobina un partido desde que abriste el canal.
- **Controles cómodos**: doble toque en los lados para saltar 10 s en el móvil; teclado, ratón e indicador de volumen en el PC.
- Menú de opciones manteniendo pulsado o con clic derecho en cualquier elemento.

## Instalación

Descarga el archivo de tu sistema desde [Releases](https://github.com/jaimegarmun/Haim-TV-IPTV/releases/latest):

| Sistema | Archivo | Cómo instalar |
|---|---|---|
| **Android / Android TV** | `HaimTV-<versión>-android.apk` | Ábrelo en el dispositivo y permite "instalar apps de origen desconocido" si te lo pide. |
| **Windows 10/11** | `HaimTV-<versión>-windows.zip` | Descomprime la carpeta donde quieras y abre `haim_tv.exe`. |
| **Linux** (Bazzite, Fedora, Ubuntu, SteamOS…) | `HaimTV-<versión>-linux.flatpak` | `flatpak install --user ./HaimTV-<versión>-linux.flatpak` |

Haim TV no incluye ningún canal ni contenido: necesitas tu propia lista M3U o cuenta Xtream.

## Compilar desde el código

La app está hecha con [Flutter](https://flutter.dev) (interfaz) y Rust (núcleo, en `src/`).

```sh
cd flutter
flutter pub get
flutter run
```

Las librerías nativas de Rust ya compiladas para Android y Windows están incluidas en el repositorio. Para recompilarlas hacen falta `cargo`, `cargo-ndk` y `cargo-cmd` (ver los comandos en `Cargo.toml`). El paquete Flatpak se describe en [`flatpak/`](flatpak/README.md).

## Créditos y licencia

Haim TV está basado en [Fred TV](https://github.com/Fredolx/fred-tv-mobile), de Frederic Lachapelle (Fredolx).

Se distribuye bajo la licencia [GNU AGPL-3.0](LICENSE), igual que el proyecto original.
