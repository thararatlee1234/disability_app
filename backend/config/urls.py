from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static
from rest_framework_simplejwt.views import TokenRefreshView
from disabilities.views import CaseInsensitiveTokenObtainPairView

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/', include('disabilities.urls')),
    path('api/token/', CaseInsensitiveTokenObtainPairView.as_view(), name='token_obtain_pair'),
    path('api/token/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
] + static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
