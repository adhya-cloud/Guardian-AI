(function () {
  'use strict';

  var POLL_MS = 5000;
  var token = decodeURIComponent(location.pathname.split('/').filter(Boolean).pop() || '');
  var $ = function (id) { return document.getElementById(id); };

  var map = L.map('map', { zoomControl: true }).setView([20.59, 78.96], 5); // India
  L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
    maxZoom: 19,
    attribution: '&copy; OpenStreetMap contributors',
  }).addTo(map);

  var marker = null;
  var circle = null;
  var trail = L.polyline([], { color: '#0e7c66', weight: 4, opacity: 0.7 }).addTo(map);
  var centred = false;
  var timer = null;

  var REASON_LABEL = { sos: 'SOS active', journey: 'Journey in progress', live: 'Sharing live location' };

  function ago(ms) {
    var s = Math.max(0, Math.round((Date.now() - ms) / 1000));
    if (s < 60) return s + 's ago';
    var m = Math.round(s / 60);
    if (m < 60) return m + ' min ago';
    return Math.round(m / 60) + ' h ago';
  }

  function setBanner(kind, badge, title, subtitle) {
    $('banner').className = 'banner banner--' + kind;
    $('badge').textContent = badge;
    $('title').textContent = title;
    $('subtitle').textContent = subtitle || '';
  }

  function showNotice(text) {
    $('notice').textContent = text;
    $('notice').hidden = !text;
  }

  function render(data) {
    var status = data.status;
    var reason = data.reason;
    var kind = status !== 'active' ? 'ended' : reason === 'sos' ? 'sos' : reason === 'journey' ? 'journey' : 'live';
    var badge = status === 'active' ? REASON_LABEL[reason] : status === 'ended' ? 'Sharing ended' : 'Link expired';
    var title = reason === 'sos' && status === 'active'
      ? data.name + ' needs help'
      : data.name + (status === 'active' ? ' is sharing their location' : '’s last shared location');
    var subtitle = data.note || (status === 'active'
      ? 'Updates automatically. Until ' + new Date(data.expiresAt).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
      : 'This page no longer updates.');
    setBanner(kind, badge, title, subtitle);
    document.title = (status === 'active' && reason === 'sos' ? '🚨 ' : '') + data.name + ' · Guardian';

    var points = data.points || [];
    if (!points.length) {
      showNotice(status === 'active' ? 'Waiting for the first location fix…' : 'No location was shared.');
      $('updated').textContent = '';
      return;
    }
    showNotice('');
    var last = points[points.length - 1];
    var ll = [last.lat, last.lng];
    var parts = ['Updated ' + ago(last.t)];
    if (typeof last.accuracy === 'number') parts.push('±' + Math.round(last.accuracy) + ' m');
    if (typeof last.battery === 'number') parts.push('🔋 ' + last.battery + '%');
    $('updated').textContent = parts.join(' · ');

    var icon = L.divIcon({ className: '', html: '<div class="me-dot' + (kind === 'sos' ? ' me-dot--sos' : '') + '"></div>', iconSize: [18, 18], iconAnchor: [9, 9] });
    if (!marker) marker = L.marker(ll, { icon: icon }).addTo(map);
    else marker.setLatLng(ll).setIcon(icon);
    var radius = typeof last.accuracy === 'number' ? last.accuracy : 0;
    if (!circle) circle = L.circle(ll, { radius: radius, color: '#0e7c66', weight: 1, fillOpacity: 0.12 }).addTo(map);
    else circle.setLatLng(ll).setRadius(radius);
    trail.setLatLngs(points.map(function (p) { return [p.lat, p.lng]; }));
    trail.setStyle({ color: kind === 'sos' ? '#d92d20' : '#0e7c66' });

    if (!centred) { map.setView(ll, 16); centred = true; }
    else if (!map.getBounds().pad(-0.2).contains(ll)) map.panTo(ll);

    var dir = $('directions');
    dir.href = 'https://www.google.com/maps/dir/?api=1&destination=' + last.lat + ',' + last.lng;
    dir.setAttribute('aria-disabled', 'false');
  }

  function poll() {
    fetch('/api/v1/view/' + encodeURIComponent(token), { cache: 'no-store' })
      .then(function (res) {
        if (res.status === 404) throw new Error('gone');
        if (!res.ok) throw new Error('http');
        return res.json();
      })
      .then(function (data) {
        render(data);
        if (data.status === 'active') timer = setTimeout(poll, POLL_MS);
      })
      .catch(function (err) {
        if (err.message === 'gone') {
          setBanner('error', 'Unavailable', 'This link is invalid or has expired', 'Ask the sender for a new link.');
          showNotice('');
          return;
        }
        showNotice('Connection problem — retrying…');
        timer = setTimeout(poll, POLL_MS * 2);
      });
  }

  document.addEventListener('visibilitychange', function () {
    if (document.visibilityState === 'visible') { clearTimeout(timer); poll(); }
  });
  poll();
})();
