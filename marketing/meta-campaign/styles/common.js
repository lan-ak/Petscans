/* Shared helpers for every creative template.
   - Reads ?r=1x1|4x5|9x16 and sets it on <html data-r>.
   - Injects the floating paw-print brand motif into any [data-paws] creative.
   - Exposes reusable brand SVGs (paw, Apple mark). */

(function () {
  var r = new URLSearchParams(location.search).get('r') || '1x1';
  document.documentElement.setAttribute('data-r', r);
  document.documentElement.style.background = '#cfd6d2';
})();

// Recognisable paw: four toe beans + metacarpal pad.
window.PAW_SVG =
  '<svg viewBox="0 0 110 110" xmlns="http://www.w3.org/2000/svg">' +
  '<ellipse cx="28" cy="42" rx="12" ry="16"/>' +
  '<ellipse cx="48" cy="28" rx="12" ry="17"/>' +
  '<ellipse cx="70" cy="28" rx="12" ry="17"/>' +
  '<ellipse cx="90" cy="42" rx="12" ry="16"/>' +
  '<path d="M59 50c-17 0-31 11-31 26 0 13 14 20 31 20s31-7 31-20c0-15-14-26-31-26z"/>' +
  '</svg>';

window.APPLE_SVG =
  '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z"/></svg>';

// App Store CTA button markup.
window.appStore = function () {
  return '<a class="appstore">' + window.APPLE_SVG +
    '<span class="t"><small>Download on the</small><b>App Store</b></span></a>';
};

// Scatter faint paw prints. Positions are deterministic (no RNG) so renders are stable.
window.injectPaws = function () {
  document.querySelectorAll('.creative[data-paws]').forEach(function (el) {
    var wrap = document.createElement('div');
    wrap.className = 'paws';
    // [leftVW, topVH, sizePx, rotateDeg, opacity]
    var spots = [
      [6, 8, 150, -18, .08], [83, 4, 120, 22, .07], [90, 30, 90, -10, .06],
      [3, 40, 100, 12, .06], [12, 82, 130, 26, .07], [78, 86, 160, -22, .08],
      [46, 92, 90, 8, .05], [66, 60, 80, 18, .05]
    ];
    spots.forEach(function (s) {
      var d = document.createElement('div');
      d.style.cssText = 'position:absolute;left:' + s[0] + '%;top:' + s[1] + '%;width:' + s[2] +
        'px;height:' + s[2] + 'px;transform:rotate(' + s[3] + 'deg);opacity:' + s[4] + ';';
      d.innerHTML = window.PAW_SVG;
      d.querySelector('svg').style.cssText = 'width:100%;height:100%;fill:var(--green);';
      wrap.appendChild(d);
    });
    el.insertBefore(wrap, el.firstChild);
  });
};
document.addEventListener('DOMContentLoaded', window.injectPaws);
