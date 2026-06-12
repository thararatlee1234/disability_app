from rest_framework.routers import DefaultRouter
from django.urls import path, include
from .views import index, MedicalCheckViewSet, PersonViewSet, stats, import_excel_view, download_template, export_excel_view, check_report, export_check_report

router = DefaultRouter()
router.register('persons', PersonViewSet, basename='persons')
router.register('checks', MedicalCheckViewSet, basename='checks')

urlpatterns = [
    path('', index, name='index'), # Serve the mobile-friendly web UI
    path('api/', include(router.urls)), # Move API to /api/ within the app
    path('api/stats/', stats),
    path('api/check-report/', check_report),
    path('api/export-check-report/', export_check_report),
    path('api/import-excel/', import_excel_view),
    path('api/download-template/', download_template),
    path('api/export-excel/', export_excel_view),
]
