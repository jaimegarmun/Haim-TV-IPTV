Set<int> refreshedSeries = {};

/// True while the video player is on screen (it uses the mouse side buttons
/// to seek instead of going back).
bool videoPlayerOpen = false;

/// Series names by series id, remembered while browsing so downloaded
/// episodes can be grouped by series.
Map<int, String> seriesNames = {};

/// Season id -> (series id, season name), remembered while browsing.
Map<int, ({int? seriesId, String name})> seasonInfo = {};
