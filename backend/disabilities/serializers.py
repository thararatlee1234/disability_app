from rest_framework import serializers
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer
from django.contrib.auth import get_user_model
from .models import MedicalCheck, MedicalCheckPhoto, PersonWithDisability

MAX_CHECK_PHOTOS = 5
MAX_CHECK_PHOTO_SIZE = 50 * 1024 * 1024


class CaseInsensitiveTokenObtainPairSerializer(TokenObtainPairSerializer):
    def validate(self, attrs):
        username = attrs.get(self.username_field)
        if username:
            User = get_user_model()
            matched_user = User.objects.filter(**{f'{self.username_field}__iexact': username}).first()
            if matched_user:
                attrs[self.username_field] = getattr(matched_user, self.username_field)
        return super().validate(attrs)


class MedicalCheckPhotoSerializer(serializers.ModelSerializer):
    image = serializers.SerializerMethodField()

    class Meta:
        model = MedicalCheckPhoto
        fields = ['id', 'image', 'created_at']

    def get_image(self, obj):
        if not obj.image:
            return None
        request = self.context.get('request')
        url = obj.image.url
        return request.build_absolute_uri(url) if request else url


class MedicalCheckSerializer(serializers.ModelSerializer):
    photos = MedicalCheckPhotoSerializer(many=True, read_only=True)

    class Meta:
        model = MedicalCheck
        fields = ['id', 'person', 'check_date', 'detail', 'photos', 'created_at', 'updated_at']

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            self.fields['person'].queryset = PersonWithDisability.objects.filter(owner=request.user)

    def validate(self, attrs):
        request = self.context.get('request')
        files = request.FILES.getlist('photos') if request else []
        if len(files) > MAX_CHECK_PHOTOS:
            raise serializers.ValidationError({'photos': f'แนบรูปได้ไม่เกิน {MAX_CHECK_PHOTOS} รูป'})
        if any(file.size > MAX_CHECK_PHOTO_SIZE for file in files):
            raise serializers.ValidationError({'photos': 'รูปแต่ละรูปต้องมีขนาดไม่เกิน 50 MB'})
        return attrs

    def create(self, validated_data):
        request = self.context.get('request')
        print(f"DEBUG: Creating MedicalCheck. User: {request.user if request else 'Unknown'}")
        print(f"DEBUG: Validated Data: {validated_data}")
        files = request.FILES.getlist('photos') if request else []
        print(f"DEBUG: Files count: {len(files)}")
        check = MedicalCheck.objects.create(**validated_data)
        for file in files:
            MedicalCheckPhoto.objects.create(medical_check=check, image=file)
        return check

    def update(self, instance, validated_data):
        request = self.context.get('request')
        files = request.FILES.getlist('photos') if request else []
        
        # Update basic fields
        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        instance.save()
        
        # Add new photos (not replacing existing ones)
        if files:
            for file in files:
                MedicalCheckPhoto.objects.create(medical_check=instance, image=file)
        
        return instance


class PersonSerializer(serializers.ModelSerializer):
    full_name = serializers.ReadOnlyField()
    photo = serializers.ImageField(required=False, allow_null=True)
    is_geocoded = serializers.SerializerMethodField()
    is_checked_this_year = serializers.SerializerMethodField()
    latest_check_date_this_year = serializers.SerializerMethodField()
    medical_checks = MedicalCheckSerializer(many=True, read_only=True)
    
    class Meta:
        model = PersonWithDisability
        fields = '__all__'
        read_only_fields = ['owner']

    def get_is_geocoded(self, obj):
        if isinstance(obj.raw_data, dict):
            return obj.raw_data.get('is_geocoded', False)
        return False

    def get_is_checked_this_year(self, obj):
        from django.utils import timezone
        now = timezone.now()
        return obj.medical_checks.filter(check_date__year=now.year).exists()

    def get_latest_check_date_this_year(self, obj):
        from django.utils import timezone
        now = timezone.now()
        check = obj.medical_checks.filter(check_date__year=now.year).order_by('-check_date').first()
        return check.check_date if check else None

    def validate(self, attrs):
        map_url = attrs.get('map_url')
        lat = attrs.get('latitude')
        lng = attrs.get('longitude')

        if map_url and (lat is None or lng is None):
            import re
            # Extract from @lat,lng
            m = re.search(r'@([-\d.]+),([-\d.]+)', map_url)
            if not m:
                # Extract from query=lat,lng or q=lat,lng
                m = re.search(r'[?&](?:query|q)=([-\d.]+),([-\d.]+)', map_url)
            
            if m:
                if lat is None:
                    lat = m.group(1)
                    attrs['latitude'] = lat
                if lng is None:
                    lng = m.group(2)
                    attrs['longitude'] = lng
        
        # Final rounding for DecimalField (max_digits=15, decimal_places=10)
        from decimal import Decimal, ROUND_HALF_UP
        if attrs.get('latitude'):
            try:
                attrs['latitude'] = Decimal(str(attrs['latitude'])).quantize(Decimal('0.0000000000'), rounding=ROUND_HALF_UP)
            except: pass
        if attrs.get('longitude'):
            try:
                attrs['longitude'] = Decimal(str(attrs['longitude'])).quantize(Decimal('0.0000000000'), rounding=ROUND_HALF_UP)
            except: pass
        
        return attrs
