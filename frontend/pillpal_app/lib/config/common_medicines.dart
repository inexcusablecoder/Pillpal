/// Curated list for the medicine picker (dropdown). Add/edit still saves the chosen name to the API.
class CommonMedicines {
  CommonMedicines._();

  /// Sentinel value for "Other — type custom name" in the dropdown.
  static const String otherValue = '__pillpal_other__';

  static const List<String> names = [
    'Aceclofenac',
    'Acyclovir',
    'Amoxicillin',
    'Artemether',
    'Aspirin',
    'Augmentin',
    'Azax',
    'Azithromycin',
    'Aztreonam',
    'Brufen',
    'Calpol',
    'Cefixime',
    'Cefotaxime',
    'Ceftriaxone',
    'Cetirizine',
    'Chloramphenicol',
    'Chloroquine',
    'Ciprofloxacin',
    'Clarithromycin',
    'Combiflam',
    'Crocin',
    'Diclofenac',
    'Dolo 650',
    'Domperidone',
    'Doxycycline',
    'Ibuprofen',
    'Indomethacin',
    'Ketorolac',
    'Levofloxacin',
    'Linezolid',
    'Loratadine',
    'Lumefantrine',
    'Mefenamic',
    'Mefloquine',
    'Metronidazole',
    'Monocef',
    'Naproxen',
    'ORS',
    'Ondansetron',
    'Oseltamivir',
    'Pantoprazole',
    'Paracetamol',
    'Piroxicam',
    'Primaquine',
    'Quinine',
    'Remdesivir',
    'Taxim-O',
    'Valacyclovir',
    'Voveran',
    'Zinc supplements',
  ];

  static bool isListed(String name) => names.contains(name);
}
