from django.contrib import admin
from django.contrib.auth import get_user_model
from django.contrib.auth.admin import UserAdmin
from .models import MedicalCheck, MedicalCheckPhoto, PersonWithDisability


def is_rose_admin(request):
    return request.user.is_active and request.user.is_superuser and request.user.username == 'Rose'

@admin.register(PersonWithDisability)
class PersonAdmin(admin.ModelAdmin):
    list_display = ('full_name','owner','citizen_id','disability_type','subdistrict','district','province','phone')
    search_fields = ('first_name','last_name','citizen_id','phone','province','district','subdistrict','owner__username')
    list_filter = ('province','district','subdistrict','disability_type')


class MedicalCheckPhotoInline(admin.TabularInline):
    model = MedicalCheckPhoto
    extra = 0


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
