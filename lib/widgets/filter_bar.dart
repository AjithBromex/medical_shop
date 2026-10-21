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
  void didUpdateWidget(FilterBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value.q != oldWidget.value.q && widget.value.q != _q.text) {
      _q.text = widget.value.q ?? '';
    }
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  void _set(Filters f) => widget.onChanged(f.normalized());

  Widget _buildSearchField(Filters f) {
    return TextField(
      controller: _q,
      decoration: InputDecoration(
        labelText: widget.searchHint,
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: _q.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () {
                  _q.clear();
                  _set(f.copyWith(q: null));
                },
              )
            : null,
      ),
      onChanged: (v) => _set(f.copyWith(q: v.trim().isEmpty ? null : v.trim())),
      onSubmitted: (v) => _set(f.copyWith(q: v.trim().isEmpty ? null : v.trim())),
    );
  }

  Widget _buildShopDropdown(BuildContext context, Filters f) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DropdownButtonFormField<int?>(
      initialValue: f.shopId,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Medical shop'),
      dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      items: [
        const DropdownMenuItem<int?>(
          value: null,
          child: Text('All shops', overflow: TextOverflow.ellipsis),
        ),
        for (final s in widget.shops)
          DropdownMenuItem<int?>(
            value: s.id,
            child: Text(
              s.name + (s.isActive ? '' : ' (inactive)'),
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (v) => _set(f.copyWith(shopId: v)),
    );
  }

  Widget _buildMethodDropdown(BuildContext context, Filters f) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentMethod = (f.method == 'gpay' || f.method == 'cheque' || f.method == 'gpay_cheque')
        ? 'gpay_cheque'
        : f.method;
    return DropdownButtonFormField<String?>(
      initialValue: currentMethod,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Payment method'),
      dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      items: const [
        DropdownMenuItem<String?>(
          value: null,
          child: Text('All methods', overflow: TextOverflow.ellipsis),
        ),
        DropdownMenuItem(
          value: 'cash',
          child: Text('Cash', overflow: TextOverflow.ellipsis),
        ),
        DropdownMenuItem(
          value: 'gpay_cheque',
          child: Text('Gpay/cheque/CN', overflow: TextOverflow.ellipsis),
        ),
      ],
      onChanged: (v) => _set(f.copyWith(method: v)),
    );
  }

  Widget _buildCategoryDropdown(BuildContext context, Filters f) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DropdownButtonFormField<String?>(
      initialValue: widget.categories.contains(f.category) ? f.category : null,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Category'),
      dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      items: [
        const DropdownMenuItem<String?>(
          value: null,
          child: Text('All categories', overflow: TextOverflow.ellipsis),
        ),
        for (final c in widget.categories)
          DropdownMenuItem<String?>(
            value: c,
            child: Text(c, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (v) => _set(f.copyWith(category: v)),
    );
  }

  Widget _buildApplyButton(Filters f, {bool fullWidth = false}) {
    final btn = FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF0284C7),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: () => _set(f.copyWith(q: _q.text.trim().isEmpty ? null : _q.text.trim())),
      icon: const Icon(Icons.filter_alt, size: 18),
      label: const Text('Apply', style: TextStyle(fontWeight: FontWeight.w700)),
    );
    return fullWidth ? SizedBox(width: double.infinity, child: btn) : btn;
  }

  Widget _buildClearButton() {
    return TextButton.icon(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.textSecondary,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      onPressed: () {
        _q.clear();
        widget.onChanged(const Filters());
      },
      icon: const Icon(Icons.clear, size: 16),
      label: const Text('Clear'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.value;
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          // Desktop / Tablet / Wide landscape screens: Wrap layout
          if (width >= 600) {
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (widget.showSearch)
                  SizedBox(width: 230, child: _buildSearchField(f)),
                SizedBox(
                  width: 170,
                  child: DateField(
                    label: 'From',
                    value: f.dateFrom,
                    clearable: true,
                    onChanged: (d) => _set(f.copyWith(dateFrom: d)),
                  ),
                ),
                SizedBox(
                  width: 170,
                  child: DateField(
                    label: 'To',
                    value: f.dateTo,
                    clearable: true,
                    onChanged: (d) => _set(f.copyWith(dateTo: d)),
                  ),
                ),
                if (widget.showShop)
                  SizedBox(width: 200, child: _buildShopDropdown(context, f)),
                if (widget.showMethod)
                  SizedBox(width: 195, child: _buildMethodDropdown(context, f)),
                if (widget.showCategory)
                  SizedBox(width: 190, child: _buildCategoryDropdown(context, f)),
                _buildApplyButton(f),
                if (!f.isEmpty) _buildClearButton(),
              ],
            );
          }

          // Mobile / Phone screens (any width, any font scale):
          final dropdownWidgets = <Widget>[
            if (widget.showShop) _buildShopDropdown(context, f),
            if (widget.showMethod) _buildMethodDropdown(context, f),
            if (widget.showCategory) _buildCategoryDropdown(context, f),
          ];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.showSearch) ...[
                _buildSearchField(f),
                const SizedBox(height: 10),
              ],
              Row(
                children: [
                  Expanded(
                    child: DateField(
                      label: 'From',
                      value: f.dateFrom,
                      clearable: true,
                      onChanged: (d) => _set(f.copyWith(dateFrom: d)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DateField(
                      label: 'To',
                      value: f.dateTo,
                      clearable: true,
                      onChanged: (d) => _set(f.copyWith(dateTo: d)),
                    ),
                  ),
                ],
              ),
              if (dropdownWidgets.isNotEmpty) ...[
                const SizedBox(height: 10),
                if (width >= 460 && dropdownWidgets.length == 2)
                  Row(
                    children: [
                      Expanded(child: dropdownWidgets[0]),
                      const SizedBox(width: 10),
                      Expanded(child: dropdownWidgets[1]),
                    ],
                  )
                else
                  for (var i = 0; i < dropdownWidgets.length; i++) ...[
                    if (i > 0) const SizedBox(height: 10),
                    dropdownWidgets[i],
                  ],
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildApplyButton(f)),
                  if (!f.isEmpty) ...[
                    const SizedBox(width: 8),
                    _buildClearButton(),
                  ],
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class Pager extends StatelessWidget {
  final int page, pages;
  final ValueChanged<int> onPage;
  const Pager({super.key, required this.page, required this.pages, required this.onPage});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? const Color(0xFFF8FAFC) : AppColors.textPrimary;
    return pages <= 1
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
                      icon: Icon(Icons.chevron_left, color: textColor),
                      tooltip: 'Previous page',
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        'Page $page of $pages',
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: page < pages ? () => onPage(page + 1) : null,
                      icon: Icon(Icons.chevron_right, color: textColor),
                      tooltip: 'Next page',
                    ),
                  ],
                ),
              ),
            ),
          );
  }
}

Future<void> showConfirmDelete(BuildContext context, String what, Future<void> Function() action) async {
  if (await confirm(context, 'Delete $what?', 'This cannot be undone. All totals will update automatically.')) {
    await action();
  }
}
