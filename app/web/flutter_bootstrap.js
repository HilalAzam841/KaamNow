{{flutter_js}}
{{flutter_build_config}}

// KaamNow registers its own service worker (sw.js, from index.html) for offline support,
// so Flutter's deprecated one is not used.
_flutter.loader.load();
