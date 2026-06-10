from rest_framework.routers import DefaultRouter
from django.urls import path, include
from .views import MedicalCheckViewSet, PersonViewSet, stats, import_excel_view, download_template

router = DefaultRouter()
router.register('persons', PersonViewSet, basename='persons')
router.register('checks', MedicalCheckViewSet, basename='checks')
urlpatterns = [
    path('', include(router.urls)),
    path('stats/', stats),
    path('import-excel/', import_excel_view),
    path('download-template/', download_template),
]
