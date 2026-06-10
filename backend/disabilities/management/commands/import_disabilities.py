from django.core.management.base import BaseCommand
from disabilities.importer import import_excel

class Command(BaseCommand):
    help = 'Import persons with disabilities from Excel'
    def add_arguments(self, parser):
        parser.add_argument('excel_path')
        parser.add_argument('--sheet', help='Sheet name to import')
        parser.add_argument('--exclude', nargs='+', help='Column names to exclude from raw_data')
    def handle(self, *args, **options):
        result = import_excel(
            options['excel_path'], 
            sheet_name=options.get('sheet'),
            exclude_columns=options.get('exclude')
        )
        self.stdout.write(self.style.SUCCESS(str(result)))
