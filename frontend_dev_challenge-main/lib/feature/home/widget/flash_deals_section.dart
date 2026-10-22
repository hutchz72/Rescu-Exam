import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app_config.dart';
import '../../../model/deal_model.dart';
import '../../../routes/routes.dart';
import '../../shared_widget/the_network_image.dart';
import '../../shared_widget/live_countdown_widget.dart';

/// Horizontal flash-sale rail.
///
/// NOTE: the countdown is currently a static "Ends soon" label — turning it
/// into a live per-deal countdown is one of the feature tasks in PROBLEM.md.
class FlashDealsSection extends StatelessWidget {
  final List<DealModel> deals;

  const FlashDealsSection({super.key, required this.deals});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Icon(Icons.bolt, color: Colors.red, size: 20),
              SizedBox(width: 4),
              Text('Flash sales',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        SizedBox(
          height: 190,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: deals.length,
            itemBuilder: (context, index) {
              final deal = deals[index];
              return _FlashDealCardItem(deal: deal);
            },
          ),
        ),
      ],
    );
  }
}

class _FlashDealCardItem extends StatefulWidget {
  final DealModel deal;

  const _FlashDealCardItem({required this.deal});

  @override
  State<_FlashDealCardItem> createState() => _FlashDealCardItemState();
}

class _FlashDealCardItemState extends State<_FlashDealCardItem> {
  bool _isExpired = false;

  @override
  void initState() {
    super.initState();
    final end = widget.deal.flashSaleEndsAt;
    _isExpired = end != null && !end.isAfter(DateTime.now());
  }

  void _handleExpired() {
    if (_isExpired || !mounted) return;
    setState(() => _isExpired = true);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: Opacity(
        opacity: _isExpired ? 0.5 : 1.0,
        child: Card(
          color: _isExpired ? Colors.grey.shade100 : Colors.white,
          elevation: 0.5,
          clipBehavior: Clip.antiAlias,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          child: InkWell(
            onTap: _isExpired
                ? null
                : () => Get.toNamed(
                      Routes.dealRoute(widget.deal.id, source: 'flash_rail'),
                      arguments: widget.deal,
                    ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TheNetworkImage(
                    url: widget.deal.imageUrl,
                    height: 90,
                    width: double.infinity),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.deal.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color:
                                  _isExpired ? Colors.grey : Colors.black87)),
                      Text(widget.deal.storeName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11.5, color: Colors.grey.shade600)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            '฿${widget.deal.price.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _isExpired
                                  ? Colors.grey
                                  : AppConfig.primaryGreen,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _isExpired
                                  ? Colors.grey.shade200
                                  : Colors.red.shade50,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: LiveCountdownWidget(
                              endTime: widget.deal.flashSaleEndsAt,
                              onExpired: _handleExpired,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _isExpired
                                    ? Colors.grey.shade600
                                    : Colors.red.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
