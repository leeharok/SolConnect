import 'package:material_ui/material_ui.dart';

import '../../services/auth_service.dart';
import '../../services/point_service.dart';
import '../../theme/app_theme.dart';

class PointHistoryScreen extends StatefulWidget {
  const PointHistoryScreen({super.key});

  @override
  State<PointHistoryScreen> createState() => _PointHistoryScreenState();
}

class _PointHistoryScreenState extends State<PointHistoryScreen> {
  bool _loading = true;
  bool _loadingMore = false;

  String? _error;

  int _balance = 0;
  int _page = 1;
  int _totalPages = 1;
  int _totalCount = 0;

  List<Map<String, dynamic>> _transactions = [];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadTransactions();
    });
  }

  Future<void> _loadTransactions({
    int page = 1,
    bool append = false,
  }) async {
    if (append) {
      setState(() {
        _loadingMore = true;
        _error = null;
      });
    } else {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final token = await AuthScope.read(context).getAccessToken();

      if (token == null || token.isEmpty) {
        throw const PointException('로그인이 필요해요.');
      }

      final result = await PointService.getMyTransactions(
        token: token,
        page: page,
        limit: 20,
      );

      final data = result['data'];

      if (data is! Map) {
        throw const PointException('포인트 정보를 확인할 수 없어요.');
      }

      final rawTransactions = data['transactions'];
      final fetchedTransactions = rawTransactions is List
          ? rawTransactions
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
          : <Map<String, dynamic>>[];

      final pagination = data['pagination'];

      if (!mounted) return;

      setState(() {
        _balance = (data['balance'] as num?)?.toInt() ?? 0;

        if (append) {
          _transactions.addAll(fetchedTransactions);
        } else {
          _transactions = fetchedTransactions;
        }

        _page = (pagination is Map
                ? (pagination['page'] as num?)?.toInt()
                : null) ??
            page;

        _totalPages = (pagination is Map
                ? (pagination['totalPages'] as num?)?.toInt()
                : null) ??
            1;

        _totalCount = (pagination is Map
                ? (pagination['totalCount'] as num?)?.toInt()
                : null) ??
            _transactions.length;
      });
    } on PointException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = '포인트 내역을 불러오는 중 오류가 발생했어요.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  String _formatDate(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();

    if (date == null) return '';

    String twoDigits(int number) => number.toString().padLeft(2, '0');

    return '${date.year}.${twoDigits(date.month)}.${twoDigits(date.day)} '
        '${twoDigits(date.hour)}:${twoDigits(date.minute)}';
  }

  Widget _buildBalanceCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.account_balance_wallet_rounded,
                color: AppColors.white,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                '현재 보유 포인트',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '$_balance P',
            style: const TextStyle(
              color: AppColors.accent,
              fontSize: 30,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionTile(Map<String, dynamic> transaction) {
    final type = transaction['type'] as String? ?? '';
    final amount = (transaction['amount'] as num?)?.toInt() ?? 0;

    final isEarned = type == 'EARNED';
    final isSpent = type == 'SPENT';

    final title = switch (type) {
      'EARNED' => '포인트 적립',
      'SPENT' => '포인트 사용',
      'ADJUSTED' => '포인트 조정',
      _ => '포인트 내역',
    };

    final icon = switch (type) {
      'EARNED' => Icons.add_circle_outline_rounded,
      'SPENT' => Icons.remove_circle_outline_rounded,
      _ => Icons.sync_alt_rounded,
    };

    final color = isEarned
        ? AppColors.primary
        : isSpent
            ? AppColors.error
            : AppColors.textSub;

    final amountText = isEarned
        ? '+${amount.abs()} P'
        : isSpent
            ? '-${amount.abs()} P'
            : '${amount > 0 ? '+' : ''}$amount P';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction['description'] as String? ?? title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _formatDate(transaction['createdAt']),
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            amountText,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('포인트 내역'),
      ),
      body: _loading && _transactions.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _loadTransactions(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                children: [
                  _buildBalanceCard(),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      const Text(
                        '포인트 거래 내역',
                        style: AppTextStyles.sectionTitle,
                      ),
                      const Spacer(),
                      Text(
                        '총 $_totalCount건',
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_error != null && _transactions.isEmpty) ...[
                    const SizedBox(height: 35),
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 42,
                      color: AppColors.textSub,
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.caption,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: OutlinedButton(
                        onPressed: () => _loadTransactions(),
                        child: const Text('다시 시도'),
                      ),
                    ),
                  ] else if (_transactions.isEmpty) ...[
                    const SizedBox(height: 35),
                    const Icon(
                      Icons.receipt_long_outlined,
                      size: 44,
                      color: AppColors.textSub,
                    ),
                    const SizedBox(height: 12),
                    const Center(
                      child: Text(
                        '아직 포인트 내역이 없어요.',
                        style: AppTextStyles.caption,
                      ),
                    ),
                  ] else ...[
                    for (final transaction in _transactions)
                      _buildTransactionTile(transaction),
                  ],
                  if (_error != null && _transactions.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.caption,
                    ),
                  ],
                  if (_page < _totalPages) ...[
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _loadingMore
                          ? null
                          : () => _loadTransactions(
                                page: _page + 1,
                                append: true,
                              ),
                      child: _loadingMore
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('더 불러오기'),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
