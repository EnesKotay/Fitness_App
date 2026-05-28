import os

filepath = 'lib/features/nutrition/presentation/pages/nutrition_guide_page.dart'
with open(filepath, 'r') as f:
    lines = f.readlines()

# 1. Models (lines 24 to 141, 0-indexed: 23 to 141)
models_content = "part of 'nutrition_guide_page.dart';\n\n" + "".join(lines[23:142])
with open('lib/features/nutrition/presentation/pages/nutrition_guide_models.dart', 'w') as f:
    f.write(models_content)

# 2. Data (lines 142 to 940, 0-indexed: 142 to 940)
data_content = "part of 'nutrition_guide_page.dart';\n\n" + "".join(lines[142:941])
with open('lib/features/nutrition/presentation/pages/nutrition_guide_data.dart', 'w') as f:
    f.write(data_content)

# 3. Components (lines 1599 to end, 0-indexed: 1599 to end)
components_content = "part of 'nutrition_guide_page.dart';\n\n" + "".join(lines[1599:])
with open('lib/features/nutrition/presentation/pages/nutrition_guide_components.dart', 'w') as f:
    f.write(components_content)

# 4. Main Page (lines 0 to 22 + parts + 941 to 1598)
main_content = "".join(lines[:23]) + "\npart 'nutrition_guide_models.dart';\npart 'nutrition_guide_data.dart';\npart 'nutrition_guide_components.dart';\n\n" + "".join(lines[941:1599])
with open(filepath, 'w') as f:
    f.write(main_content)

print("Split completed successfully!")
