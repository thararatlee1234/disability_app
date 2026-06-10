from django.http import HttpResponse
from openpyxl import Workbook
from django.db.models import Count, Q
from rest_framework import viewsets, permissions, status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response
from rest_framework_simplejwt.views import TokenObtainPairView
from .models import MedicalCheck, PersonWithDisability
from .serializers import CaseInsensitiveTokenObtainPairSerializer, MedicalCheckSerializer, PersonSerializer
from .importer import import_excel


class CaseInsensitiveTokenObtainPairView(TokenObtainPairView):
    serializer_class = CaseInsensitiveTokenObtainPairSerializer


class PersonViewSet(viewsets.ModelViewSet):
    queryset = PersonWithDisability.objects.all().order_by('first_name','last_name')
    serializer_class = PersonSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        qs = super().get_queryset().filter(owner=self.request.user)
        citizen_id = self.request.query_params.get('citizen_id', '').strip()
        if citizen_id:
            qs = qs.filter(citizen_id=citizen_id)
            
        search = self.request.query_params.get('search', '').strip()
        if search:
            qs = qs.filter(Q(first_name__icontains=search) | Q(last_name__icontains=search) | Q(citizen_id__icontains=search) | Q(phone__icontains=search))
        return qs

    def perform_create(self, serializer):
        serializer.save(owner=self.request.user)


class MedicalCheckViewSet(viewsets.ModelViewSet):
    queryset = MedicalCheck.objects.select_related('person').prefetch_related('photos')
    serializer_class = MedicalCheckSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        qs = super().get_queryset().filter(person__owner=self.request.user)
        person_id = self.request.query_params.get('person')
        if person_id:
            qs = qs.filter(person_id=person_id)
        return qs

@api_view(['GET'])
@permission_classes([permissions.IsAuthenticated])
def stats(request):
    qs = PersonWithDisability.objects.filter(owner=request.user)
    return Response({
        'total': qs.count(),
        'by_province': list(qs.values('province').annotate(total=Count('id')).order_by('-total')[:30]),
        'by_subdistrict': list(qs.values('subdistrict').annotate(total=Count('id')).order_by('-total')[:50]),
        'by_disability_type': list(qs.values('disability_type').annotate(total=Count('id')).order_by('-total')[:50]),
    })

@api_view(['POST'])
@permission_classes([permissions.IsAuthenticated])
def import_excel_view(request):
    file = request.FILES.get('file')
    if not file:
        return Response({'detail':'กรุณาแนบไฟล์ Excel ใน field ชื่อ file'}, status=status.HTTP_400_BAD_REQUEST)
    if not file.name.lower().endswith('.xlsx'):
        return Response({'detail':'รองรับเฉพาะไฟล์ Excel .xlsx เท่านั้น กรุณาดาวน์โหลดไฟล์ตัวอย่างแล้วนำเข้าซ้ำ'}, status=status.HTTP_400_BAD_REQUEST)
    try:
        result = import_excel(file, owner=request.user)
    except Exception as exc:
        return Response({'detail': f'นำเข้าไฟล์ Excel ไม่สำเร็จ: {exc}'}, status=status.HTTP_400_BAD_REQUEST)
    return Response(result)

@api_view(['GET'])
@permission_classes([permissions.IsAuthenticated])
def download_template(request):
    wb = Workbook()
    ws = wb.active
    ws.title = "Template"
    
    headers = [
        'เลขบัตรประชาชน', 'คำนำหน้า', 'ชื่อ', 'นามสกุล', 'เพศ', 
        'ประเภทความพิการ', 'โทรศัพท์', 'ที่อยู่', 'ตำบล', 'อำเภอ', 
        'จังหวัด', 'latitude', 'longitude', 'หมายเหตุ'
    ]
    ws.append(headers)
    
    # Add an example row
    ws.append([
        '1234567890123', 'นาย', 'สมชาย', 'ใจดี', 'ชาย',
        'พิการทางการเคลื่อนไหว', '0812345678', '123 ม.1', 'ในเมือง', 'เมือง',
        'กรุงเทพฯ', '13.7563', '100.5018', 'ตัวอย่างข้อมูล'
    ])

    response = HttpResponse(
        content_type='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    )
    response['Content-Disposition'] = 'attachment; filename="template_disability.xlsx"'
    wb.save(response)
    return response
