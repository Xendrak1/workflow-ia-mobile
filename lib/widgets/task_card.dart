import 'package:flutter/material.dart';

import '../core/models/task_model.dart';
import '../core/theme.dart';
import 'status_badge.dart';

class TaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback onTap;

  const TaskCard({super.key, required this.task, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      task.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  StatusBadge(task.status),
                ],
              ),
              if (task.assignedDepartment != null &&
                  task.assignedDepartment!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.business_outlined,
                        size: 13, color: AppColors.muted),
                    const SizedBox(width: 4),
                    Text(
                      task.assignedDepartment!,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.muted),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.tag, size: 13, color: AppColors.muted),
                  const SizedBox(width: 4),
                  Text(
                    task.tramiteId,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.muted,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const Spacer(),
                  if (task.evidences.isNotEmpty) ...[
                    const Icon(Icons.attach_file,
                        size: 13, color: AppColors.muted),
                    const SizedBox(width: 2),
                    Text(
                      '${task.evidences.length}',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.muted),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
