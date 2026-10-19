import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/models.dart';
import 'common.dart';

/// Same filter names everywhere: search, date range, shop, category, payment method.
class FilterBar extends StatefulWidget {
  final Filters value;
  final ValueChanged<Filters> onChanged;
  final List<MedicalShop> shops;
  final List<String> categories;
  final bool showSearch, showShop, showMethod, showCategory;
  final String searchHint;
  const FilterBar({
    super.key,
    required this.value,
    required this.onChanged,
    this.shops = const [],
    this.categories = const [],
    this.showSearch = true,
    this.showShop = false,
    this.showMethod = false,
    this.showCategory = false,
    this.searchHint = 'Search',
  });

  @override
  State<FilterBar> createState() => _FilterBarState();
}

class _FilterBarState extends State<FilterBar> {
  late final TextEditingController _q = TextEditingController(text: widget.value.q ?? '');

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  void _set(Filters f) => widget.onChanged(f.normalized());

  @override
  Widget build(BuildContext context) {
    final f = widget.value;
    Widget box(Widget child, {double w = 190}) => SizedBox(width: w, child: child);
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (widget.showSearch)
            box(
              TextField(
                controller: _q,
                decoration: InputDecoration(
                  labelText: widget.searchHint,
                  prefixIcon: const Icon(Icons.search, size: 20),
                ),
                onSubmitted: (v) => _set(f.copyWith(q: v.trim().isEmpty ? null : v.trim())),
              ),
              w: 230,
            ),
          box(DateField(label: 'From', value: f.dateFrom, clearable: true, onChanged: (d) => _set(f.copyWith(dateFrom: d)))),
          box(DateField(label: 'To', value: f.dateTo, clearable: true, onChanged: (d) => _set(f.copyWith(dateTo: d)))),
          if (widget.showShop)
            box(DropdownButtonFormField<int?>(
              initialValue: f.shopId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Medical shop'),
              dropdownColor: Colors.white,
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('All shops')),
                for (final s in widget.shops)
                  DropdownMenuItem<int?>(
                    value: s.id,
                    child: Text(s.name + (s.isActive ? '' : ' (inactive)'), overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) => _set(f.copyWith(shopId: v)),
            )),
          if (widget.showMethod)
            box(
              DropdownButtonFormField<String?>(
                initialValue: (f.method == 'gpay' || f.method == 'cheque' || f.method == 'gpay_cheque')
                    ? 'gpay_cheque'
                    : f.method,
                decoration: const InputDecoration(labelText: 'Payment method'),
                dropdownColor: Colors.white,
                items: const [
                  DropdownMenuItem<String?>(value: null, child: Text('All methods')),
                  DropdownMenuItem(value: 'cash', child: Text('Cash')),
                  DropdownMenuItem(value: 'gpay_cheque', child: Text('Gpay/cheque/CN')),
                ],
                onChanged: (v) => _set(f.copyWith(method: v)),
              ),
              w: 195,
            ),
          if (widget.showCategory)
            box(
              DropdownButtonFormField<String?>(
                initialValue: widget.categories.contains(f.category) ? f.category : null,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Category'),
                dropdownColor: Colors.white,
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('All categories')),
                  for (final c in widget.categories) DropdownMenuItem<String?>(value: c, child: Text(c)),
                ],
                onChanged: (v) => _set(f.copyWith(category: v)),
              ),
              w: 190,
            ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => _set(f.copyWith(q: _q.text.trim().isEmpty ? null : _q.text.trim())),
            icon: const Icon(Icons.filter_alt, size: 18),
            label: const Text('Apply', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          if (!f.isEmpty)
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
              onPressed: () {
                _q.clear();
                widget.onChanged(const Filters());
              },
              icon: const Icon(Icons.clear, size: 16),
              label: const Text('Clear'),
            ),
        ],
      ),
    );
  }
}

class Pager extends StatelessWidget {
  final int page, pages;
  final ValueChanged<int> onPage;
  const Pager({super.key, required this.page, required this.pages, required this.onPage});

  @override
  Widget build(BuildContext context) => pages <= 1
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Center(
            child: GlassContainer(
              blur: 14,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              borderRadius: BorderRadius.circular(20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: page > 1 ? () => onPage(page - 1) : null,
                    icon: const Icon(Icons.chevron_left, color: AppColors.textPrimary),
                    tooltip: 'Previous page',
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      'Page $page of $pages',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: page < pages ? () => onPage(page + 1) : null,
                    icon: const Icon(Icons.chevron_right, color: AppColors.textPrimary),
                    tooltip: 'Next page',
                  ),
                ],
              ),
            ),
          ),
        );
}

Future<void> showConfirmDelete(BuildContext context, String what, Future<void> Function() action) async {
  if (await confirm(context, 'Delete $what?', 'This cannot be undone. All totals will update automatically.')) {
    await action();
  }
}
