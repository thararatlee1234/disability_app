import os
import django
import requests
import re
from decimal import Decimal

# Setup Django
import sys
sys.path.append(os.getcwd())
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from disabilities.models import PersonWithDisability

def resolve_coords(url):
    if not url:
        return None, None
    
    # Pre-clean URL: remove spaces and fix common typos
    # 1. Remove all spaces
    url = url.replace(' ', '')
    
    # 2. Extract starting from the first "http" or "htt"
    match = re.search(r'ht+ps?.*', url)
    if match:
        url = match.group(0)
    
    # 3. Standardize the protocol part (handle httpss, htttps, https: ://, etc.)
    url = re.sub(r'^ht+ps?s?[:\s/]+', 'https://', url)
    
    # 4. Final safety check for double slashes (ensure exactly https://)
    if url.startswith('https:'):
        url = 'https://' + url[6:].lstrip('/')
    elif url.startswith('http:'):
        url = 'http://' + url[5:].lstrip('/')
        
    if not url.startswith('http'):
        url = 'https://' + url.lstrip('/')

    # Function to extract from a string
    def extract_from_text(text):
        # 1. Prioritize !3d (lat) and !4d (lng) - these are often the EXACT pin location
        m_pin = re.search(r'!3d([-\d.]+)!4d([-\d.]+)', text)
        if m_pin:
            return Decimal(m_pin.group(1)), Decimal(m_pin.group(2))
            
        # 2. Look for @lat,lng
        m_at = re.search(r'@([-\d.]+),([-\d.]+)', text)
        if m_at:
            return Decimal(m_at.group(1)), Decimal(m_at.group(2))

        # 3. Look for query=lat,lng or q=lat,lng or ll=lat,lng
        m_q = re.search(r'[?&](?:query|q|ll)=([-\d.]+),([-\d.]+)', text)
        if m_q:
            return Decimal(m_q.group(1)), Decimal(m_q.group(2))
            
        # 4. Look for place/lat,lng or search/lat,lng
        m_place = re.search(r'(?:place|search)/([-\d.]+),([-\d.]+)', text)
        if m_place:
            return Decimal(m_place.group(1)), Decimal(m_place.group(2))

        # 5. Look for center=lat,lng
        m_center = re.search(r'center=([-\d.]+),([-\d.]+)', text)
        if m_center:
            return Decimal(m_center.group(1)), Decimal(m_center.group(2))
            
        return None, None

    # Try direct URL first
    lat, lng = extract_from_text(url)
    if lat and lng:
        return lat, lng
    
    # If it's a short link or doesn't have coords, resolve it
    short_domains = ['maps.app.goo.gl', 'g.co', 'goo.gl/maps', 'maps.google.com']
    if any(domain in url for domain in short_domains):
        try:
            headers = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'}
            response = requests.get(url, allow_redirects=True, timeout=15, headers=headers)
            final_url = response.url
            
            # Try to extract from final redirected URL
            lat, lng = extract_from_text(final_url)
            if lat and lng:
                return lat, lng
            
            # If still not found, check the page content for meta tags or script data
            # Google often embeds the location in og:image or script tags
            m_meta = re.search(r'meta content="https://www\.google\.com/maps/preview/place/.*?/@([-\d.]+),([-\d.]+)', response.text)
            if m_meta:
                return Decimal(m_meta.group(1)), Decimal(m_meta.group(2))
            
            # Check for coordinates in the text response (e.g. DMS format or other patterns)
            # Example: [null,null,14.007436,100.624802]
            m_json = re.search(r'\[null,null,([-\d.]+),([-\d.]+)\]', response.text)
            if m_json:
                return Decimal(m_json.group(1)), Decimal(m_json.group(2))

        except Exception as e:
            print(f"Error resolving {url}: {e}")
            
    return None, None

def main():
    # Process ALL persons with a map_url to ensure accuracy, as requested by user
    persons = PersonWithDisability.objects.exclude(map_url='')
    print(f"Checking {persons.count()} persons with map_url for accuracy...")
    
    updated_count = 0
    for p in persons:
        lat, lng = resolve_coords(p.map_url)
        if lat and lng:
            # Only update if different enough (more than 0.0001 difference)
            # or if it was previously one of the defaults
            is_default = (p.latitude == Decimal('13.7563') and p.longitude == Decimal('100.5018'))
            
            if is_default or p.latitude is None or abs(p.latitude - lat) > 0.00001 or abs(p.longitude - lng) > 0.00001:
                old_lat, old_lng = p.latitude, p.longitude
                p.latitude = lat
                p.longitude = lng
                p.save()
                updated_count += 1
                print(f"Updated {p.full_name}:")
                print(f"  Old: {old_lat}, {old_lng}")
                print(f"  New: {lat}, {lng}")
        else:
            print(f"Could not resolve accurately for {p.full_name}: {p.map_url}")
            
    print(f"Finished. Updated {updated_count} records for better accuracy.")

if __name__ == '__main__':
    main()
