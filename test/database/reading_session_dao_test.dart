import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledor/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  ReadingSessionTableCompanion session({
    required String id,
    required String bookId,
    required DateTime startedAt,
    int durationMs = 60000,
    int wordsRead = 300,
    int startWordIndex = 0,
    int endWordIndex = 300,
    int avgWpm = 300,
  }) {
    return ReadingSessionTableCompanion.insert(
      id: id,
      bookId: bookId,
      startedAt: startedAt,
      endedAt: startedAt.add(Duration(milliseconds: durationMs)),
      durationMs: durationMs,
      wordsRead: wordsRead,
      startWordIndex: startWordIndex,
      endWordIndex: endWordIndex,
      avgWpm: avgWpm,
    );
  }

  final day1 = DateTime(2026, 7, 1, 10);
  final day2 = DateTime(2026, 7, 2, 10);
  final day3 = DateTime(2026, 7, 3, 10);

  test('getSessionsInRange is inclusive on from, exclusive on to', () async {
    final dao = db.readingSessionDao;
    await dao.insertSession(session(id: 's1', bookId: 'b', startedAt: day1));
    await dao.insertSession(session(id: 's2', bookId: 'b', startedAt: day2));
    await dao.insertSession(session(id: 's3', bookId: 'b', startedAt: day3));

    final rows = await dao.getSessionsInRange(day1, day3);
    expect(rows.map((r) => r.id), ['s1', 's2']);
  });

  test('aggregateByBookInRange groups sums per book', () async {
    final dao = db.readingSessionDao;
    await dao.insertSession(session(
        id: 's1',
        bookId: 'a',
        startedAt: day1,
        durationMs: 1000,
        wordsRead: 10,
        endWordIndex: 10));
    await dao.insertSession(session(
        id: 's2',
        bookId: 'a',
        startedAt: day2,
        durationMs: 2000,
        wordsRead: 20,
        endWordIndex: 50));
    await dao.insertSession(session(
        id: 's3',
        bookId: 'b',
        startedAt: day2,
        durationMs: 500,
        wordsRead: 5,
        endWordIndex: 5));
    // Outside the range — must not pollute the aggregate.
    await dao.insertSession(session(
        id: 's4',
        bookId: 'a',
        startedAt: day3,
        durationMs: 9999,
        wordsRead: 999,
        endWordIndex: 999));

    final aggregates = await dao.aggregateByBookInRange(day1, day3);
    final byBook = {for (final a in aggregates) a.bookId: a};

    expect(byBook, hasLength(2));
    expect(byBook['a']!.totalDurationMs, 3000);
    expect(byBook['a']!.totalWords, 30);
    expect(byBook['a']!.sessionCount, 2);
    expect(byBook['a']!.maxEndWordIndex, 50);
    expect(byBook['b']!.sessionCount, 1);
  });

  test('existingSessionIds returns the full id set', () async {
    final dao = db.readingSessionDao;
    await dao.insertSession(session(id: 's1', bookId: 'a', startedAt: day1));
    await dao.insertSession(session(id: 's2', bookId: 'b', startedAt: day2));

    expect(await dao.existingSessionIds(), {'s1', 's2'});
  });

  test('deleteSessionsForBook only touches that book', () async {
    final dao = db.readingSessionDao;
    await dao.insertSession(session(id: 's1', bookId: 'a', startedAt: day1));
    await dao.insertSession(session(id: 's2', bookId: 'b', startedAt: day2));

    await dao.deleteSessionsForBook('a');

    expect(await dao.getAllSessionsForBook('a'), isEmpty);
    expect((await dao.getAllSessions()).map((r) => r.id), ['s2']);
  });

  test('watchSessionsInRange emits ordered by startedAt', () async {
    final dao = db.readingSessionDao;
    await dao.insertSession(session(id: 's2', bookId: 'a', startedAt: day2));
    await dao.insertSession(session(id: 's1', bookId: 'a', startedAt: day1));

    final rows = await dao.watchSessionsInRange(day1, day3).first;
    expect(rows.map((r) => r.id), ['s1', 's2']);
  });
}
