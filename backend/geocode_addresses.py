import os, django, time
from decimal import Decimal
from geopy.geocoders import Nominatim
from geopy.extra.rate_limiter import RateLimiter

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from django.db import models
from disabilities.models import PersonWithDisability

def geocode_persons(force=False):
    # Only persons with NO coordinates OR those previously geocoded (to improve accuracy)
    if force:
        persons = PersonWithDisability.objects.filter(models.Q(latitude__isnull=True) | models.Q(raw_data__is_geocoded=True))
    else:
        persons = PersonWithDisability.objects.filter(latitude__isnull=True)
        
    print(f"Found {persons.count()} persons needing geocoding/update.")
    
    geolocator = Nominatim(user_agent="disability_app_geocoder")
    geocode = RateLimiter(geolocator.geocode, min_delay_seconds=1.5)
    
    updated = 0
    for p in persons:
        # Construct address query with more details for better precision
        # Order: House No, Village No, Village Name, Road, Subdistrict, District, Province
        parts = [p.house_no, p.village_no, p.village_name, p.road, p.subdistrict, p.district, p.province, "Thailand"]
        address_query = " ".join([str(part).strip() for part in parts if part and str(part).strip()])
        
        if not address_query or address_query == "Thailand":
            # Fallback to raw address if components are empty
            address_query = f"{p.address} Thailand"
            
        print(f"Geocoding {p.full_name}: {address_query}")
        try:
            location = geocode(address_query)
            if location:
                p.latitude = Decimal(str(location.latitude))
                p.longitude = Decimal(str(location.longitude))
                # Mark as geocoded (we can use raw_data to flag this)
                if not isinstance(p.raw_data, dict): p.raw_data = {}
                p.raw_data['is_geocoded'] = True
                p.save()
                updated += 1
                print(f"  SUCCESS: {location.latitude}, {location.longitude}")
            else:
                print(f"  FAILED: Location not found")
        except Exception as e:
            print(f"  ERROR: {e}")
            
    print(f"Finished. Geocoded {updated} records.")

if __name__ == '__main__':
    geocode_persons(force=True)
