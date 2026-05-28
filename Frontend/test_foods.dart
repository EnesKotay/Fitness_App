import 'dart:io';
import 'dart:convert';

void main() {
  final file = File('assets/foods/verified_tr_extras.json');
  final content = file.readAsStringSync();
  final data = json.decode(content);
  print('Toplam yiyecek sayisi: ${data['foods'].length}');
  for (var f in data['foods']) {
    print('${f['name']} - ${f['nutrientsPerBasis']['kcal']} kcal');
  }
}
