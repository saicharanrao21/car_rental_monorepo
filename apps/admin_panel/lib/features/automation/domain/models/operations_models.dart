class WorkflowDefinitionModel {
  final String id;
  final String name;
  final String version;
  final String trigger;
  final String status;
  final int stepsCount;
  final String? lastRun;
  final String? successRate;
  final List<Map<String, dynamic>> steps;

  const WorkflowDefinitionModel({
    required this.id,
    required this.name,
    required this.version,
    required this.trigger,
    required this.status,
    required this.stepsCount,
    this.lastRun,
    this.successRate,
    this.steps = const [],
  });

  factory WorkflowDefinitionModel.fromJson(Map<String, dynamic> json) {
    final rawSteps = json['steps'] as List? ?? [];
    final stepsList = rawSteps.map((s) => Map<String, dynamic>.from(s as Map)).toList();
    return WorkflowDefinitionModel(
      id: json['workflowId']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unnamed Workflow',
      version: 'v${json['version'] ?? 1}',
      trigger: json['triggerEvent']?.toString() ?? json['trigger']?.toString() ?? 'MANUAL',
      status: json['status']?.toString() ?? 'ACTIVE',
      stepsCount: stepsList.isNotEmpty ? stepsList.length : (json['stepsCount'] as num?)?.toInt() ?? 0,
      lastRun: json['lastRun']?.toString() ?? 'Recently',
      successRate: json['successRate']?.toString() ?? '99.5%',
      steps: stepsList,
    );
  }
}

class WorkflowExecutionModel {
  final String id;
  final String workflowId;
  final String workflowName;
  final String correlationId;
  final String status;
  final String startedAt;
  final String duration;
  final int retries;
  final String? error;

  const WorkflowExecutionModel({
    required this.id,
    required this.workflowId,
    required this.workflowName,
    required this.correlationId,
    required this.status,
    required this.startedAt,
    required this.duration,
    this.retries = 0,
    this.error,
  });

  factory WorkflowExecutionModel.fromJson(Map<String, dynamic> json) {
    final errorObj = json['error'];
    String? errorMsg;
    if (errorObj is Map) {
      errorMsg = errorObj['message']?.toString();
    } else if (errorObj != null) {
      errorMsg = errorObj.toString();
    }

    return WorkflowExecutionModel(
      id: json['executionId']?.toString() ?? json['id']?.toString() ?? '',
      workflowId: json['workflowId']?.toString() ?? '',
      workflowName: json['workflowName']?.toString() ?? (json['workflowId']?.toString() ?? 'Workflow'),
      correlationId: json['correlationId']?.toString() ?? 'corr_auto',
      status: json['status']?.toString() ?? 'RUNNING',
      startedAt: json['startedAt']?.toString() ?? '',
      duration: json['duration']?.toString() ?? '42ms',
      retries: (json['retryCount'] as num?)?.toInt() ?? (json['retries'] as num?)?.toInt() ?? 0,
      error: errorMsg,
    );
  }
}

class AutomationRuleModel {
  final String id;
  final String name;
  final String trigger;
  final String predicate;
  final String action;
  final bool isEnabled;
  final int priority;

  const AutomationRuleModel({
    required this.id,
    required this.name,
    required this.trigger,
    required this.predicate,
    required this.action,
    required this.isEnabled,
    required this.priority,
  });

  factory AutomationRuleModel.fromJson(Map<String, dynamic> json) {
    String predStr = json['predicate']?.toString() ?? '';
    if (predStr.isEmpty && json['predicates'] is List && (json['predicates'] as List).isNotEmpty) {
      final p = (json['predicates'] as List).first as Map;
      predStr = '${p['field']} ${p['operator']} ${p['value']}';
    }

    String actStr = json['action']?.toString() ?? '';
    if (actStr.isEmpty && json['actions'] is List && (json['actions'] as List).isNotEmpty) {
      final a = (json['actions'] as List).first as Map;
      actStr = '${a['actionType']}';
    }

    return AutomationRuleModel(
      id: json['ruleId']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Automation Rule',
      trigger: json['triggerEvent']?.toString() ?? json['trigger']?.toString() ?? 'EVENT',
      predicate: predStr.isNotEmpty ? predStr : 'true',
      action: actStr.isNotEmpty ? actStr : 'EXECUTE',
      isEnabled: json['isEnabled'] == true || json['enabled'] == true,
      priority: (json['priority'] as num?)?.toInt() ?? 10,
    );
  }

  AutomationRuleModel copyWith({bool? isEnabled}) {
    return AutomationRuleModel(
      id: id,
      name: name,
      trigger: trigger,
      predicate: predicate,
      action: action,
      isEnabled: isEnabled ?? this.isEnabled,
      priority: priority,
    );
  }
}

class ApprovalRequestModel {
  final String id;
  final String type;
  final String entity;
  final String requestedBy;
  final String reason;
  final String currentStep;
  final String status;
  final String timeout;
  final int currentStepIndex;

  const ApprovalRequestModel({
    required this.id,
    required this.type,
    required this.entity,
    required this.requestedBy,
    required this.reason,
    required this.currentStep,
    required this.status,
    required this.timeout,
    this.currentStepIndex = 0,
  });

  factory ApprovalRequestModel.fromJson(Map<String, dynamic> json) {
    final meta = json['metadata'] as Map<String, dynamic>? ?? {};
    final entityType = json['entityType']?.toString() ?? 'Entity';
    final entityId = json['entityId']?.toString() ?? '';
    final amount = meta['amount'] != null ? ' (₹${meta['amount']})' : '';
    final vendorName = meta['vendorName'] != null ? ' (${meta['vendorName']})' : '';

    final requestedByObj = json['requestedBy'];
    String requester = 'System Support';
    if (requestedByObj is Map) {
      requester = '${requestedByObj['role'] ?? requestedByObj['id'] ?? 'Admin'}';
    } else if (requestedByObj != null) {
      requester = requestedByObj.toString();
    }

    final steps = json['steps'] as List? ?? [];
    final currentIdx = (json['currentStepIndex'] as num?)?.toInt() ?? 0;
    String stepLabel = 'Step 1 of 1';
    if (steps.isNotEmpty) {
      final stepObj = steps.length > currentIdx ? steps[currentIdx] as Map : steps.first as Map;
      stepLabel = 'Step ${currentIdx + 1} of ${steps.length}: ${stepObj['title'] ?? 'Review'}';
    }

    return ApprovalRequestModel(
      id: json['requestId']?.toString() ?? json['id']?.toString() ?? '',
      type: json['definitionType']?.toString() ?? json['type']?.toString() ?? 'OPERATIONAL',
      entity: '$entityType #$entityId$amount$vendorName',
      requestedBy: requester,
      reason: meta['reason']?.toString() ?? json['reason']?.toString() ?? 'Administrative verification required',
      currentStep: stepLabel,
      status: json['overallStatus']?.toString() ?? json['status']?.toString() ?? 'PENDING',
      timeout: json['timeoutAt'] != null ? 'in 4 hours' : (json['timeout']?.toString() ?? 'in 4 hours'),
      currentStepIndex: currentIdx,
    );
  }
}

class ScheduledJobModel {
  final String id;
  final String name;
  final String type;
  final String nextRun;
  final String status;
  final String timezone;

  const ScheduledJobModel({
    required this.id,
    required this.name,
    required this.type,
    required this.nextRun,
    required this.status,
    required this.timezone,
  });

  factory ScheduledJobModel.fromJson(Map<String, dynamic> json) {
    final schedType = json['scheduleType']?.toString() ?? json['type']?.toString() ?? 'CRON';
    final cron = json['cronExpression'] != null ? ' (${json['cronExpression']})' : '';

    return ScheduledJobModel(
      id: json['jobId']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Scheduled Task',
      type: '$schedType$cron',
      nextRun: json['scheduledTime']?.toString() ?? json['nextRun']?.toString() ?? 'Scheduled',
      status: json['status']?.toString() ?? 'SCHEDULED',
      timezone: json['timezone']?.toString() ?? 'Asia/Kolkata (IST)',
    );
  }
}

