from django.contrib import admin
from django.contrib.auth import get_user_model
from django.contrib.auth.admin import UserAdmin
from django.utils import timezone
from django.utils.html import format_html
from .models import MedicalCheck, MedicalCheckPhoto, PersonWithDisability


def is_rose_admin(request):
    return request.user.is_active and request.user.is_superuser and request.user.username == 'Rose'

@admin.register(PersonWithDisability)
class PersonAdmin(admin.ModelAdmin):
    list_display = ('full_name', 'owner', 'citizen_id', 'check_status_this_year', 'subdistrict', 'district', 'province', 'phone')
    search_fields = ('first_name', 'last_name', 'citizen_id', 'phone', 'province', 'district', 'subdistrict', 'owner__username')
    list_filter = ('province', 'district', 'subdistrict', 'disability_type')
    
    fieldsets = (
        ('ข้อมูลทั่วไป', {
            'fields': ('owner', ('prefix', 'first_name', 'last_name'), 'citizen_id', 'gender', 'disability_type', 'photo')
        }),
        ('ที่อยู่', {
            'fields': ('address', ('house_no', 'village_no', 'village_name'), 'road', ('subdistrict', 'district', 'province'), 'postal_code')
        }),
        ('พิกัดและแผนที่', {
            'fields': ('latitude', 'longitude', 'map_url', 'google_maps_link'),
            'description': 'คลิกในแผนที่เพื่อปักหมุด หรือลากหมุดเพื่อเปลี่ยนตำแหน่ง'
        }),
        ('ข้อมูลเพิ่มเติม', {
            'fields': ('phone', 'notes', 'source_row', 'raw_data')
        }),
    )
    
    readonly_fields = ('google_maps_link',)
    
    inlines = [] # Will be set below

    def google_maps_link(self, obj):
        if obj.map_url:
            return format_html('<a href="{}" target="_blank">เปิดใน Google Maps ↗️</a>', obj.map_url)
        if obj.latitude and obj.longitude:
            url = f"https://www.google.com/maps?q={obj.latitude},{obj.longitude}"
            return format_html('<a href="{}" target="_blank">เปิดใน Google Maps ↗️</a>', url)
        return "ยังไม่มีข้อมูลพิกัด"
    google_maps_link.short_description = 'ลิงก์แผนที่'

    class Media:
        js = ('disabilities/js/map_picker.js',)

    def check_status_this_year(self, obj):
        now = timezone.now()
        check = obj.medical_checks.filter(check_date__year=now.year).order_by('-check_date').first()
        if check:
            return format_html('<span style="color: green; font-weight: bold;">ตรวจแล้ว ({})</span>', check.check_date)
        return format_html('<span style="color: orange;">ยังไม่ตรวจ</span>')
    check_status_this_year.short_description = 'สถานะการตรวจปีนี้'


class MedicalCheckPhotoInline(admin.TabularInline):
    model = MedicalCheckPhoto
    extra = 0


class MedicalCheckInline(admin.TabularInline):
    model = MedicalCheck
    extra = 1
    show_change_link = True


PersonAdmin.inlines = [MedicalCheckInline]


@admin.register(MedicalCheck)
class MedicalCheckAdmin(admin.ModelAdmin):
    list_display = ('person', 'check_date', 'created_at')
    search_fields = ('person__first_name', 'person__last_name', 'detail')
    list_filter = ('check_date',)
    inlines = [MedicalCheckPhotoInline]


class RoseOnlyUserAdmin(UserAdmin):
    def has_module_permission(self, request):
        return is_rose_admin(request)

    def has_view_permission(self, request, obj=None):
        return is_rose_admin(request)

    def has_add_permission(self, request):
        return is_rose_admin(request)

    def has_change_permission(self, request, obj=None):
        return is_rose_admin(request)

    def has_delete_permission(self, request, obj=None):
        return is_rose_admin(request)


User = get_user_model()
try:
    admin.site.unregister(User)
except admin.sites.NotRegistered:
    pass
admin.site.register(User, RoseOnlyUserAdmin)
