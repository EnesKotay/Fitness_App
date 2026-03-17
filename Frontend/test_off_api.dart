import 'dart:convert';
import 'dart:io';

void main() async {
  print("Testing Open Food Facts Search API...");
  final searchUrl = Uri.parse('https://world.openfoodfacts.org/cgi/search.pl?search_terms=yulaf&page_size=3&page=1&json=1');
  
  try {
    final httpClient = HttpClient();
    final request = await httpClient.getUrl(searchUrl);
    final response = await request.close();
    print("Search Response Status: \${response.statusCode}");
    if (response.statusCode == 200) {
      final responseBody = await response.transform(utf8.decoder).join();
      final data = jsonDecode(responseBody);
      final products = data['products'] as List<dynamic>? ?? [];
      print("Found \${products.length} products.");
      for (var p in products) {
        print("- \${p['product_name']} (Barcode: \${p['code']})");
      }
    } else {
      print("Failed to fetch search results.");
    }
    httpClient.close();
  } catch (e) {
    print("Search API Error: \$e");
  }

  print("\nTesting Open Food Facts Barcode API...");
  final barcodeUrl = Uri.parse('https://world.openfoodfacts.net/api/v2/product/8690504015692'); // Eti Yulaf Ezmesi
  
  try {
    final httpClient = HttpClient();
    final request = await httpClient.getUrl(barcodeUrl);
    final response = await request.close();
    print("Barcode Response Status: \${response.statusCode}");
    if (response.statusCode == 200) {
      final responseBody = await response.transform(utf8.decoder).join();
      final data2 = jsonDecode(responseBody);
      final product = data2['product'];
      if(product != null) {
          print("Found Product: \${product['product_name']} (Barcode: \${product['code']})");
          final nut = product['nutriments'] ?? {};
          print("Kcal per 100g: \${nut['energy-kcal_100g'] ?? nut['energy_100g']}");
      } else {
          print("Product not found in JSON response");
      }
    } else {
      print("Failed to fetch barcode result.");
    }
    httpClient.close();
  } catch (e) {
    print("Barcode API Error: \$e");
  }
}
