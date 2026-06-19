import 'package:flutter/material.dart';

String relationshipText(String? rel) {
  switch (rel) {
    case 'child':
      return '子女';
    case 'spouse':
      return '配偶';
    case 'relative':
      return '亲属';
    case 'friend':
      return '朋友';
    case 'caregiver':
      return '护理人';
    default:
      return '家人';
  }
}

String sessionStatusText(String? status) {
  switch (status) {
    case 'requested':
      return '等待响应';
    case 'active':
      return '进行中';
    case 'completed':
      return '已完成';
    case 'cancelled':
      return '已取消';
    default:
      return '未知';
  }
}

IconData sessionStatusIcon(String? status) {
  switch (status) {
    case 'requested':
      return Icons.hourglass_top;
    case 'active':
      return Icons.videocam;
    case 'completed':
      return Icons.check_circle;
    case 'cancelled':
      return Icons.cancel;
    default:
      return Icons.help;
  }
}

Color sessionStatusColor(String? status) {
  switch (status) {
    case 'requested':
      return Colors.orange;
    case 'active':
      return Colors.green;
    case 'completed':
      return Colors.blue;
    case 'cancelled':
      return Colors.grey;
    default:
      return Colors.grey;
  }
}
