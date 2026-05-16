// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_chargebee/otel_chargebee.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemorySpanExporter spans;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_chargebee-test',
    );
    spans = harness.spans;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(Span s) =>
      {for (final a in s.attributes.toList()) a.key: a.value};

  test('subscription.create records CLIENT span', () async {
    await tracedChargebee<String>(
      resource: 'subscription',
      action: 'create',
      customerId: 'cus_1',
      site: 'acme',
      invoke: () async => 'sub_1',
    );
    final span = spans.findSpanByName('chargebee subscription.create');
    expect(span, isNotNull);
    expect(span!.kind, SpanKind.client);
    final a = attrsOf(span);
    expect(a['chargebee.resource'], 'subscription');
    expect(a['chargebee.action'], 'create');
    expect(a['chargebee.operation'], 'subscription.create');
    expect(a['chargebee.customer.id'], 'cus_1');
    expect(a['chargebee.site'], 'acme');
  });

  test('records exception', () async {
    await expectLater(
      tracedChargebee<String>(
        resource: 'subscription',
        action: 'create',
        invoke: () async => throw StateError('boom'),
      ),
      throwsA(isA<StateError>()),
    );
    expect(
      spans.findSpanByName('chargebee subscription.create')!.status,
      SpanStatusCode.Error,
    );
  });

  test('suppression skips spans', () async {
    await runWithoutChargebeeInstrumentationAsync(() async {
      await tracedChargebee<String>(
        resource: 'subscription',
        action: 'create',
        invoke: () async => 'sub_2',
      );
    });
    expect(spans.findSpansStartingWith('chargebee '), isEmpty);
  });
}
