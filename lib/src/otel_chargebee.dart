// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

import 'otel_chargebee_suppression.dart';

const _tracerName = 'dartastic_otel_libs_chargebee';

Tracer _tracer() => OTel.tracerProvider().getTracer(_tracerName);

/// Wraps any Chargebee API call in a CLIENT span. The verb in
/// `resource.action` form (e.g. `subscription.create`, `customer
/// .update`) feeds the span name and `chargebee.operation`.
Future<T> tracedChargebee<T>({
  required String resource,
  required String action,
  required Future<T> Function() invoke,
  String? subscriptionId,
  String? customerId,
  String? invoiceId,
  String? site,
}) async {
  if (chargebeeInstrumentationSuppressed()) {
    return invoke();
  }
  final m = <String, Object>{
    'chargebee.resource': resource,
    'chargebee.action': action,
    'chargebee.operation': '$resource.$action',
  };
  if (subscriptionId != null) {
    m['chargebee.subscription.id'] = subscriptionId;
  }
  if (customerId != null) m['chargebee.customer.id'] = customerId;
  if (invoiceId != null) m['chargebee.invoice.id'] = invoiceId;
  if (site != null) m['chargebee.site'] = site;

  final span = _tracer().startSpan(
    'chargebee $resource.$action',
    kind: SpanKind.client,
    attributes: OTel.attributesFromMap(m),
  );
  try {
    return await invoke();
  } catch (e, st) {
    span.addAttributes(OTel.attributes([
      OTel.attributeString(
        ErrorResource.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}
