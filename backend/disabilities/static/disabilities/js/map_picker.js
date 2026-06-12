(function() {
    'use strict';

    document.addEventListener('DOMContentLoaded', function() {
        const latInput = document.getElementById('id_latitude');
        const lngInput = document.getElementById('id_longitude');
        const mapUrlInput = document.getElementById('id_map_url');

        if (!latInput || !lngInput) return;

        // Create map container
        const mapDiv = document.createElement('div');
        mapDiv.id = 'admin-map-picker';
        mapDiv.style.height = '400px';
        mapDiv.style.width = '100%';
        mapDiv.style.marginBottom = '20px';
        mapDiv.style.borderRadius = '8px';
        mapDiv.style.border = '1px solid #ccc';

        // Insert map before the latitude field's row
        const targetRow = latInput.closest('.form-row');
        targetRow.parentNode.insertBefore(mapDiv, targetRow);

        // Load Leaflet CSS
        const link = document.createElement('link');
        link.rel = 'stylesheet';
        link.href = 'https://unpkg.com/leaflet@1.9.4/dist/leaflet.css';
        document.head.appendChild(link);

        // Load Leaflet JS
        const script = document.createElement('script');
        script.src = 'https://unpkg.com/leaflet@1.9.4/dist/leaflet.js';
        script.onload = initMap;
        document.head.appendChild(script);

        function initMap() {
            let lat = parseFloat(latInput.value) || 13.7563;
            let lng = parseFloat(lngInput.value) || 100.5018;

            const map = L.map('admin-map-picker').setView([lat, lng], (latInput.value ? 16 : 6));

            const tiles = L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
                maxZoom: 19,
                attribution: '© OpenStreetMap'
            }).addTo(map);

            // Add Satellite option
            const satellite = L.tileLayer('https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}', {
                attribution: 'Tiles &copy; Esri &mdash; Source: Esri, i-cubed, USDA, USGS, AEX, GeoEye, Getmapping, Aerogrid, IGN, IGP, UPR-EBP, and the GIS User Community'
            });

            L.control.layers({
                "แผนที่ปกติ": tiles,
                "ดาวเทียม": satellite
            }).addTo(map);

            const marker = L.marker([lat, lng], { draggable: true }).addTo(map);

            function updateInputs(latlng) {
                const newLat = latlng.lat.toFixed(10);
                const newLng = latlng.lng.toFixed(10);
                latInput.value = newLat;
                lngInput.value = newLng;
                if (mapUrlInput) {
                    mapUrlInput.value = `https://www.google.com/maps/search/?api=1&query=${newLat},${newLng}`;
                }
            }

            marker.on('dragend', function(e) {
                updateInputs(e.target.getLatLng());
            });

            map.on('click', function(e) {
                marker.setLatLng(e.latlng);
                updateInputs(e.latlng);
            });

            // Update map when inputs change manually
            [latInput, lngInput].forEach(input => {
                input.addEventListener('change', () => {
                    const newLat = parseFloat(latInput.value);
                    const newLng = parseFloat(lngInput.value);
                    if (!isNaN(newLat) && !isNaN(newLng)) {
                        const newPos = [newLat, newLng];
                        marker.setLatLng(newPos);
                        map.setView(newPos);
                    }
                });
            });
        }
    });
})();
